import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:frame_ble/brilliant_bluetooth.dart';
import 'package:frame_ble/brilliant_connection_state.dart';
import 'package:frame_ble/brilliant_device.dart';
import 'package:frame_ble/brilliant_scanned_device.dart';
import 'package:frame_msg/frame_msg.dart';
import 'package:logging/logging.dart';
import 'package:noa/bluetooth.dart';
import 'package:noa/noa_api.dart';
import 'package:noa/util/frame_msg_util.dart';
import 'package:noa/util/state_machine.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger("App logic");

// NOTE Update these when changing firmware or scripts
const _firmwareVersion = "v25.080.0838";
const _scriptVersion = "v1.0.6";

const checkFwVersionFlag = 0x16;
const checkScriptVersionFlag = 0x17;
const messageResponseFlag = 0x20;
const imageResponseFlag = 0x21;
const singleDataFlag = 0x22;
const tapFLag = 0x10;
const stopTapFlag = 0x13;
const startListeningFlag = 0x11;
const stopListeningFlag = 0x12;

enum State {
  getUserSettings,
  waitForLogin,
  scanning,
  found,
  connect,
  stopLuaApp,
  checkFirmwareVersion,
  uploadMainLua,
  uploadGraphicsLua,
  uploadStateLua,
  triggerUpdate,
  updateFirmware,
  requiresRepair,
  connected,
  disconnected,
  recheckFirmwareVersion,
  checkScriptVersion,
  sendResponseToDevice,
  logout,
  deleteAccount,
}

enum Event {
  init,
  done,
  error,
  loggedIn,
  deviceFound,
  deviceLost,
  deviceConnected,
  updatableDeviceConnected,
  deviceDisconnected,
  deviceInvalid,
  buttonPressed,
  cancelPressed,
  logoutPressed,
  deletePressed,
  deviceUpToDate,
  deviceNeedsUpdate,
  noaResponse,
  resetScriptsPressed,
}

enum FrameState {
  disconnected,
  tapMeIn,
  listening,
  onit,
  printReply,
}

enum TuneLength {
  shortest('shortest'),
  short('short'),
  standard('standard'),
  long('long'),
  longest('longest');

  const TuneLength(this.value);
  final String value;
}

class AppLogicModel extends ChangeNotifier {
  // Public state variables
  StateMachine state = StateMachine(State.getUserSettings);
  FrameState frameState = FrameState.disconnected;
  NoaUser noaUser = NoaUser();
  double bluetoothUploadProgress = 0;
  double scriptProgress = 0;
  String deviceName = "Device";
  List<NoaMessage> noaMessages = List.empty(growable: true);

  void setUserAuthToken(String token) {
    SharedPreferences.getInstance().then((value) async {
      await value.setString("userAuthToken", token);
      triggerEvent(Event.loggedIn);
    });
  }

  Future<String?> _getUserAuthToken() async {
    return await SharedPreferences.getInstance()
        .then((value) => value.getString('userAuthToken'));
  }

  void _setPairedDevice(String token) {
    SharedPreferences.getInstance().then((value) async {
      await value.setString("PairedDevice", token);
      triggerEvent(Event.loggedIn);
    });
  }

  Future<String?> _getPairedDevice() async {
    return await SharedPreferences.getInstance()
        .then((value) => value.getString('PairedDevice'));
  }

  List<String> _filterLuaFiles(List<String> files) {
    return files.where((name) => name.endsWith('.lua')).toList();
  }

  // User's tune preferences
  String _tunePrompt = "";
  String get tunePrompt => _tunePrompt;
  set tunePrompt(String value) {
    _tunePrompt = value;
    () async {
      final savedData = await SharedPreferences.getInstance();
      savedData.setString("tunePrompt", _tunePrompt);
    }();
  }

  int _tuneTemperature = 50;
  int get tuneTemperature => _tuneTemperature;
  set tuneTemperature(int value) {
    _tuneTemperature = value;
    () async {
      final savedData = await SharedPreferences.getInstance();
      savedData.setInt("tuneTemperature", _tuneTemperature);
    }();
    notifyListeners();
  }

  bool _customServer = false;
  bool get customServer => _customServer;
  set customServer(bool value) {
    _customServer = value;
    SharedPreferences.getInstance()
        .then((sp) => sp.setBool("customServer", value));
    notifyListeners();
  }

  String _apiEndpoint = "";
  String get apiEndpoint => _apiEndpoint;
  set apiEndpoint(String value) {
    _apiEndpoint = value;
    SharedPreferences.getInstance()
        .then((sp) => sp.setString("apiEndpoint", value));
    notifyListeners();
  }

  String _apiToken = "";
  String get apiToken => _apiToken;
  set apiToken(String value) {
    _apiToken = value;
    SharedPreferences.getInstance()
        .then((sp) => sp.setString("apiToken", value));
    notifyListeners();
  }

  String _apiHeader = "";
  String get apiHeader => _apiHeader;
  set apiHeader(String value) {
    _apiHeader = value;
    SharedPreferences.getInstance()
        .then((sp) => sp.setString("apiHeader", value));
    notifyListeners();
  }

  TuneLength _tuneLength = TuneLength.standard;
  TuneLength get tuneLength => _tuneLength;
  set tuneLength(TuneLength value) {
    _tuneLength = value;
    () async {
      final savedData = await SharedPreferences.getInstance();
      savedData.setString("tuneLength", _tuneLength.name);
    }();
    notifyListeners();
  }

  late bool _textToSpeech;
  bool get textToSpeech => _textToSpeech;
  set textToSpeech(bool value) {
    _textToSpeech = value;
    SharedPreferences.getInstance()
        .then((sp) => sp.setBool("textToSpeech", value));
    notifyListeners();
  }

  late bool _promptless;
  bool get promptless => _promptless;
  set promptless(bool value) {
    _promptless = value;
    SharedPreferences.getInstance()
        .then((sp) => sp.setBool("promptless", value));
    notifyListeners();
  }

  // Private state variables
  StreamSubscription? _scanStream;
  StreamSubscription? _connectionStream;
  StreamSubscription? _luaResponseStream;
  StreamSubscription? _dataResponseStream;
  BrilliantScannedDevice? _nearbyDevice;
  BrilliantDevice? _connectedDevice;
  BrilliantDfuDevice? _updatableDevice;
  StreamSubscription<int>? _tapSubs;
  bool _cancelled = false;
  // List<int> _audioData = List.empty(growable: true);
  // List<int> _imageData = List.empty(growable: true);
// Photos: 720px VERY_HIGH quality JPEGs
  static const resolution = 720;
  static const qualityIndex = 4;
  static const qualityLevel = 'MEDIUM';
  final RxPhoto _rxPhoto =
      RxPhoto(quality: qualityLevel, resolution: resolution);
  Future<Uint8List>? _image;

  final RxAudio _rxAudio = RxAudio(streaming: false);
  Future<Uint8List>? _audio;
  String getTunePrompt() {
    String prompt = "";
    if (_tunePrompt != "") {
      prompt += "$_tunePrompt. ";
    }

    switch (_tuneLength) {
      case TuneLength.shortest:
        prompt += "Limit responses to 1 to 3 words. ";
        break;
      case TuneLength.short:
        prompt += "Limit responses to 1 sentence. ";
        break;
      case TuneLength.standard:
        prompt += "Limit responses to 1 to 2 sentences. ";
        break;
      case TuneLength.long:
        prompt += "Limit responses to 1 short paragraph. ";
        break;
      case TuneLength.longest:
        prompt += "Limit responses to 2 paragraphs. ";
        break;
    }
    return prompt;
  }

  AppLogicModel() {
    // Uncomment to create AppStore images
    // noaMessages.add(NoaMessage(
    //   message: "Recommend me some pizza places I near Union Square",
    //   from: NoaRole.user,
    //   time: DateTime.now().add(const Duration(seconds: 2)),
    // ));

    // noaMessages.add(NoaMessage(
    //   message:
    //       "You might want to check out Bravo Pizza, Union Square Pizza, or Joe's Pizza for some good pizza near Union Square.",
    //   from: NoaRole.noa,
    //   time: DateTime.now().add(const Duration(seconds: 3)),
    // ));

    // noaMessages.add(NoaMessage(
    //   message: "Does Joe's have any good vegetarian options?",
    //   from: NoaRole.user,
    //   time: DateTime.now().add(const Duration(seconds: 4)),
    // ));

    // noaMessages.add(NoaMessage(
    //   message:
    //       "Joe's Pizza does offer vegetarian options, including a cheese-less veggie pie that's quite popular.",
    //   from: NoaRole.noa,
    //   time: DateTime.now().add(const Duration(seconds: 5)),
    // ));

    () async {
      noaMessages.add(NoaMessage(
        message: "Hey I'm Noa! Let's show you around",
        from: NoaRole.noa,
        time: DateTime.now(),
        exclude: true,
      ));

      noaMessages.add(NoaMessage(
          message: "Tap the side of your Frame to wake me up",
          from: NoaRole.noa,
          time: DateTime.now(),
          image: (await rootBundle.load('assets/images/tutorial/wake_up.png'))
              .buffer
              .asUint8List(),
          exclude: true));

      noaMessages.add(NoaMessage(
          message: "Tap again and ask me anything",
          from: NoaRole.noa,
          time: DateTime.now(),
          image: (await rootBundle.load('assets/images/tutorial/tap_start.png'))
              .buffer
              .asUint8List(),
          exclude: true));

      noaMessages.add(NoaMessage(
          message: "...and then a third time to finish",
          from: NoaRole.noa,
          time: DateTime.now(),
          image:
              (await rootBundle.load('assets/images/tutorial/tap_finish.png'))
                  .buffer
                  .asUint8List(),
          exclude: true));

      noaMessages.add(NoaMessage(
          message:
              "The response just takes a few seconds. Tap again to ask a follow up question",
          from: NoaRole.noa,
          time: DateTime.now(),
          image: (await rootBundle
                  .load('assets/images/tutorial/tap_follow_up.png'))
              .buffer
              .asUint8List(),
          exclude: true));

      noaMessages.add(NoaMessage(
          message: "The follow up just takes a few more seconds",
          from: NoaRole.noa,
          time: DateTime.now(),
          image: (await rootBundle.load('assets/images/tutorial/response.png'))
              .buffer
              .asUint8List(),
          exclude: true));
    }();
  }

  void triggerEvent(Event event) {
    state.event(event);

    do {
      switch (state.current) {
        case State.getUserSettings:
          state.onEntry(() async {
            try {
              // Load the user's Tune settings or defaults if none are set
              final savedData = await SharedPreferences.getInstance();
              _tunePrompt = savedData.getString('tunePrompt') ??
                  "You are Noa, a smart and witty personal AI assistant inside the user's AR smart glasses that answers all user queries and questions";
              _tuneTemperature = savedData.getInt('tuneTemperature') ?? 50;
              var len = savedData.getString('tuneLength') ?? 'standard';
              _tuneLength = TuneLength.values
                  .firstWhere((e) => e.toString() == 'TuneLength.$len');
              _textToSpeech = savedData.getBool('textToSpeech') ?? true;
              _apiEndpoint = savedData.getString('apiEndpoint') ?? "";
              _apiToken = savedData.getString('apiToken') ?? "";
              _apiHeader = savedData.getString('apiHeader') ?? "";
              _customServer = savedData.getBool('customServer') ?? false;
              _promptless = savedData.getBool('promptless') ?? false;

              // Check if the auto token is loaded and if Frame is paired
              if (await _getUserAuthToken() != null &&
                  await _getPairedDevice() != null) {
                noaUser = await NoaApi.getUser((await _getUserAuthToken())!);
                triggerEvent(Event.done);
                return;
              }
              throw ("Not logged in or paired");
            } catch (error) {
              _log.info(error);
              triggerEvent(Event.error);
            }
          });
          state.changeOn(Event.done, State.disconnected);
          state.changeOn(Event.error, State.waitForLogin);
          break;

        case State.waitForLogin:
          state.changeOn(Event.loggedIn, State.scanning,
              transitionTask: () async =>
                  noaUser = await NoaApi.getUser((await _getUserAuthToken())!));
          break;

        case State.scanning:
          state.onEntry(() async {
            await _scanStream?.cancel();
            _scanStream = BrilliantBluetooth.scan().listen((device) {
              _nearbyDevice = device;
              deviceName = device.device.advName;
              triggerEvent(Event.deviceFound);
            });
          });
          state.changeOn(Event.deviceFound, State.found);
          state.changeOn(Event.cancelPressed, State.disconnected,
              transitionTask: () async => await BrilliantBluetooth.stopScan());
          break;

        case State.found:
          state.changeOn(Event.deviceLost, State.scanning);
          state.changeOn(Event.buttonPressed, State.connect);
          state.changeOn(Event.cancelPressed, State.disconnected,
              transitionTask: () async => await BrilliantBluetooth.stopScan());
          break;

        case State.connect:
          state.onEntry(() async {
            try {
              if (_nearbyDevice!.device.advName == "Frame Update") {
                _updatableDevice = BrilliantDfuDevice(
                  state: BrilliantConnectionState.disconnected,
                  device: _nearbyDevice!.device,
                );
                await _updatableDevice!.connect();
                triggerEvent(Event.updatableDeviceConnected);

                return;
              }
              _connectedDevice =
                  await BrilliantBluetooth.connect(_nearbyDevice!);

              switch (_connectedDevice!.state) {
                case BrilliantConnectionState.connected:
                  triggerEvent(Event.deviceConnected);
                  break;
                default:
                  throw ();
              }
            } catch (_) {
              triggerEvent(Event.deviceInvalid);
            }
          });
          state.changeOn(Event.deviceConnected, State.stopLuaApp);
          state.changeOn(Event.updatableDeviceConnected, State.updateFirmware);
          state.changeOn(Event.deviceInvalid, State.requiresRepair);
          break;

        case State.stopLuaApp:
          state.onEntry(() async {
            try {
              await _connectedDevice!.sendBreakSignal();
              triggerEvent(Event.done);
            } catch (_) {
              triggerEvent(Event.error);
            }
          });
          state.changeOn(Event.done, State.checkFirmwareVersion);
          state.changeOn(Event.error, State.requiresRepair);
          break;

        case State.checkFirmwareVersion:
          state.onEntry(() async {
            try {
              final response = await _connectedDevice!
                  .sendString("print(frame.FIRMWARE_VERSION)")
                  .timeout(const Duration(seconds: 1));
              if (response == _firmwareVersion) {
                triggerEvent(Event.deviceUpToDate);
              } else {
                triggerEvent(Event.deviceNeedsUpdate);
              }
            } catch (_) {
              triggerEvent(Event.error);
            }
          });
          state.changeOn(Event.deviceUpToDate, State.uploadMainLua);
          state.changeOn(Event.deviceNeedsUpdate, State.triggerUpdate);
          state.changeOn(Event.error, State.requiresRepair);
          break;

        case State.uploadMainLua:
          state.onEntry(() async {
            try {
              List<String> luaFiles = _filterLuaFiles(
                  (await AssetManifest.loadFromAssetBundle(rootBundle))
                      .listAssets());

              if (luaFiles.isNotEmpty) {
                scriptProgress = 0;
                for (var pathFile in luaFiles) {
                  String fileName = pathFile.split('/').last;
                  _log.info("Uploading $fileName");
                  // send the lua script to the Frame
                  await _connectedDevice!.uploadScript(
                      fileName, await rootBundle.loadString(pathFile));
                  // set the progress
                  scriptProgress += (100 / luaFiles.length);
                  notifyListeners();
                }
              }
              await _connectedDevice!.sendResetSignal();
              _setPairedDevice(_connectedDevice!.device.remoteId.toString());

              triggerEvent(Event.done);
            } catch (_) {
              triggerEvent(Event.error);
            }
          });

          state.changeOn(Event.done, State.connected);
          state.changeOn(Event.error, State.requiresRepair);
          break;

        case State.triggerUpdate:
          state.onEntry(() async {
            try {
              await _connectedDevice!.sendString(
                "frame.update()",
                awaitResponse: false,
              );
            } catch (_) {
              triggerEvent(Event.error);
            }
            await _scanStream?.cancel();
            _scanStream = BrilliantBluetooth.scan().listen((device) {
              _nearbyDevice = device;
              triggerEvent(Event.deviceFound);
            });
          });
          state.changeOn(Event.deviceFound, State.connect,
              transitionTask: () async => await BrilliantBluetooth.stopScan());
          state.changeOn(Event.error, State.requiresRepair);
          break;

        case State.updateFirmware:
          state.onEntry(() async {
            _updatableDevice!
                .updateFirmware("assets/frame-firmware-$_firmwareVersion.zip")
                .listen(
              (value) {
                bluetoothUploadProgress = value;
                notifyListeners();
              },
              onDone: () async {
                try {
                  await _scanStream?.cancel();
                  _scanStream = BrilliantBluetooth.scan().listen((device) {
                    _nearbyDevice = device;
                    triggerEvent(Event.deviceFound);
                  });
                } catch (error) {
                  triggerEvent(Event.error);
                }
              },
              onError: (_) async {
                await _connectedDevice?.disconnect();
                triggerEvent(Event.error);
              },
              cancelOnError: true,
            );
          });
          state.changeOn(Event.deviceFound, State.connect);
          state.changeOn(Event.error, State.requiresRepair);
          break;

        case State.requiresRepair:
          state.changeOn(Event.buttonPressed, State.scanning);
          state.changeOn(Event.cancelPressed, State.disconnected);
          break;

        case State.connected:
          state.onEntry(() async {
            _connectionStream?.cancel();
            _connectionStream =
                _connectedDevice!.connectionState.listen((event) {
              _connectedDevice = event;
              if (event.state == BrilliantConnectionState.disconnected) {
                triggerEvent(Event.deviceDisconnected);
              }
            });
            _connectionStream?.onError((_) {});
            _luaResponseStream?.cancel();
            _luaResponseStream =
                _connectedDevice!.stringResponse.listen((event) async {});
            // wait for the device to be ready
            await Future.delayed(const Duration(seconds: 1));
            _connectedDevice!
                .sendMessage(singleDataFlag, TxCode(value: stopTapFlag).pack());
            _tapSubs?.cancel();
            _tapSubs = RxTap(tapFlag: tapFLag)
                .attach(_connectedDevice!.dataResponse)
                .listen((taps) async {
              if (taps == 1) {
                if (frameState == FrameState.tapMeIn) {
                  // STEP 2: LISTENING
                  frameState = FrameState.listening;
                  _log.info("Listening");
                  await _connectedDevice!.sendMessage(
                      messageResponseFlag,
                      TxRichText(text: "tap to finish", emoji: "\u{F0010}")
                          .pack());
                  _cancelled = false;
                  _image = _rxPhoto.attach(_connectedDevice!.dataResponse).first;
                  _audio = _rxAudio.attach(_connectedDevice!.dataResponse).first;
                  await _connectedDevice!.sendMessage(
                      startListeningFlag,
                      TxCaptureSettings(
                              resolution: resolution,
                              qualityIndex: qualityIndex)
                          .pack());
                } else if (frameState == FrameState.listening && !_cancelled) {
                  // STEP 3: ON IT
                  frameState = FrameState.onit;
                  _log.info("On it");
                  _connectedDevice!.sendMessage(
                      singleDataFlag, TxCode(value: stopListeningFlag).pack());
                  await _connectedDevice!.sendMessage(
                      messageResponseFlag,
                      TxRichText(
                              text:
                                  "..................... ..................... .....................")
                          .pack());
                  if (_cancelled) return;
                  var image = await _image;
                  var audio = await _audio;
                  _log.info(
                      "Image: ${image?.length} bytes,  Audio: ${audio?.length} bytes");

                  if (_cancelled) return;
                  final newMessages = await NoaApi.getMessage(
                      (await _getUserAuthToken())!,
                      audio!,
                      image!,
                      getTunePrompt(),
                      _tuneTemperature / 50,
                      noaMessages,
                      textToSpeech,
                      apiEndpoint,
                      apiHeader,
                      apiToken,
                      customServer,
                      promptless);
                  final topicChanged =
                      newMessages.where((msg) => msg.topicChanged).isNotEmpty;
                  if (topicChanged) {
                    for (var msg in noaMessages) {
                      msg.exclude = true;
                    }
                  }
                  if (_cancelled) return;
                  noaMessages += newMessages;
                  noaUser = await NoaApi.getUser((await _getUserAuthToken())!);

                  if (_cancelled) return;
                  triggerEvent(Event.noaResponse);
                  image = null;
                  _image = null;
                  _audio = null;
                }
              } else if (taps == 2) {
                _log.info("Cancelled");
                await _connectedDevice!.sendMessage(messageResponseFlag,
                    TxRichText(text: "Tap me in", emoji: "\u{F0000}").pack());
                _connectedDevice!.sendMessage(
                    singleDataFlag, TxCode(value: stopListeningFlag).pack());
                _cancelled = true;
                frameState = FrameState.tapMeIn;
              }
            });
            _connectedDevice!
                .sendMessage(singleDataFlag, TxCode(value: tapFLag).pack());
            // STEP 1: TAP ME IN
            // if its coming from disconnected state immediately show tap me in, if its coming from print reply wait for 5 seconds
            if (frameState == FrameState.printReply) {
              Future.delayed(const Duration(seconds: 5), () async {
                await _connectedDevice!.sendMessage(
                    messageResponseFlag,
                    TxRichText(text: "Tap me in", emoji: "\u{F0000}").pack());
                frameState = FrameState.tapMeIn;
              });
            }else{

            await _connectedDevice!.sendMessage(messageResponseFlag,
                TxRichText(text: "Tap me in", emoji: "\u{F0000}").pack());
                frameState = FrameState.tapMeIn;
            }

          });
          state.changeOn(Event.noaResponse, State.sendResponseToDevice);
          state.changeOn(Event.deviceDisconnected, State.disconnected);
          state.changeOn(Event.logoutPressed, State.logout);
          state.changeOn(Event.deletePressed, State.deleteAccount);
          state.changeOn(Event.resetScriptsPressed, State.stopLuaApp);
          break;

        case State.sendResponseToDevice:
          state.onEntry(() async {
            try {
              await _connectedDevice!.sendMessage(
                  messageResponseFlag,
                  TxRichText(text: noaMessages.last.message, emoji: "\u{F0003}")
                      .pack());
              // hold reply for 5 seconds
              frameState = FrameState.printReply;
              await Future.delayed(const Duration(milliseconds: 1000));
            } catch (_) {}
            triggerEvent(Event.done);
          });

          state.changeOn(Event.done, State.connected);
          state.changeOn(Event.logoutPressed, State.logout);
          state.changeOn(Event.deletePressed, State.deleteAccount);
          state.changeOn(Event.resetScriptsPressed, State.stopLuaApp);
          break;

        case State.disconnected:
          frameState = FrameState.disconnected;
          state.onEntry(() async {
            _connectionStream?.cancel();
            _connectionStream =
                _connectedDevice?.connectionState.listen((event) async {
              _connectedDevice = event;
              if (event.state == BrilliantConnectionState.connected) {
                triggerEvent(Event.deviceConnected);
              }
            });

            _connectionStream?.onError((_) {});

            try {
              _connectedDevice ??= await BrilliantBluetooth.reconnect(
                  (await _getPairedDevice())!);
            } catch (error) {
              _log.warning("Error reconnecting to device. $error");
            }
            if (_connectedDevice?.state == BrilliantConnectionState.connected) {
              triggerEvent(Event.deviceConnected);
            }
          });
          state.changeOn(Event.deviceConnected, State.recheckFirmwareVersion);
          state.changeOn(Event.logoutPressed, State.logout);
          state.changeOn(Event.deletePressed, State.deleteAccount);
          break;

        case State.recheckFirmwareVersion:
          state.onEntry(() async {
            _dataResponseStream?.cancel();
            _dataResponseStream =
                _connectedDevice!.dataResponse.listen((event) async {
              final flag = event[0];
              if (flag == checkFwVersionFlag) {
                _log.info("Firmware version: ${utf8.decode(event.sublist(1))}");
                if (utf8.decode(event.sublist(1)) == _firmwareVersion) {
                  triggerEvent(Event.deviceUpToDate);
                } else {
                  triggerEvent(Event.deviceNeedsUpdate);
                }
              }
            });
            try {
              await _connectedDevice!
                  .sendMessage(
                      singleDataFlag, TxCode(value: checkFwVersionFlag).pack())
                  .timeout(const Duration(seconds: 1));
            } catch (ex) {
              _log.warning("Error checking firmware version. $ex");
              triggerEvent(Event.error);
            }
          });
          state.changeOn(Event.deviceUpToDate, State.checkScriptVersion);
          state.changeOn(Event.deviceNeedsUpdate, State.stopLuaApp);
          state.changeOn(Event.error, State.stopLuaApp);
          state.changeOn(Event.logoutPressed, State.logout);
          break;

        case State.checkScriptVersion:
          state.onEntry(() async {
            _dataResponseStream?.cancel();
            _dataResponseStream =
                _connectedDevice!.dataResponse.listen((event) async {
              final flag = event[0];
              if (flag == checkScriptVersionFlag) {
                _log.info("Script version: ${utf8.decode(event.sublist(1))}");
                if (utf8.decode(event.sublist(1)) == _scriptVersion && false) { // TODO remove when not debugging: always upload scripts
                  triggerEvent(Event.deviceUpToDate);
                } else {
                  triggerEvent(Event.deviceNeedsUpdate);
                }
              }
            });
            try {
              await _connectedDevice!
                  .sendMessage(singleDataFlag,
                      TxCode(value: checkScriptVersionFlag).pack())
                  .timeout(const Duration(seconds: 1));
            } catch (_) {
              _log.warning("Error checking script version.");
              triggerEvent(Event.error);
            }
          });
          state.changeOn(Event.deviceUpToDate, State.connected);
          state.changeOn(Event.deviceNeedsUpdate, State.stopLuaApp);
          state.changeOn(Event.error, State.stopLuaApp);
          state.changeOn(Event.logoutPressed, State.logout);
          break;

        case State.logout:
          state.onEntry(() async {
            try {
              await SharedPreferences.getInstance().then((sp) => sp.clear());
              await _connectedDevice?.disconnect();
              await NoaApi.signOut((await _getUserAuthToken())!);
              noaMessages.clear();
              triggerEvent(Event.done);
            } catch (error) {
              _log.warning("Error logging out. $error");
              triggerEvent(Event.done);
            }
          });
          state.changeOn(Event.done, State.getUserSettings);
          break;

        case State.deleteAccount:
          state.onEntry(() async {
            try {
              await _connectedDevice?.disconnect();
              await NoaApi.deleteUser((await _getUserAuthToken())!);
              await SharedPreferences.getInstance().then((sp) => sp.clear());
              noaMessages.clear();
              triggerEvent(Event.done);
            } catch (error) {
              _log.warning("Error deleting account. $error");
              triggerEvent(Event.done);
            }
          });
          state.changeOn(Event.done, State.getUserSettings);
          break;
      }
    } while (state.changePending());

    notifyListeners();
  }

  @override
  void dispose() {
    BrilliantBluetooth.stopScan();
    _scanStream?.cancel();
    _connectionStream?.cancel();
    _luaResponseStream?.cancel();
    _dataResponseStream?.cancel();
    _tapSubs?.cancel();

    super.dispose();
  }
}

final model = ChangeNotifierProvider<AppLogicModel>((ref) {
  return AppLogicModel();
});
