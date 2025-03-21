import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:noa/bluetooth.dart';
import 'package:noa/noa_api.dart';
import 'package:noa/util/state_machine.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger("App logic");

// NOTE Update these when changing firmware or scripts
const _firmwareVersion = "v25.080.0838";
const _scriptVersion = "v1.0.5";

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
  deleteAccount
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
  NoaUser noaUser = NoaUser();
  double bluetoothUploadProgress = 0;
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
  List<int> _audioData = List.empty(growable: true);
  List<int> _imageData = List.empty(growable: true);

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
            _scanStream = BrilliantBluetooth.scan()
                .timeout(const Duration(seconds: 2), onTimeout: (sink) {
              _nearbyDevice = null;
              triggerEvent(Event.deviceLost);
            }).listen((device) {
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
              _connectedDevice =
                  await BrilliantBluetooth.connect(_nearbyDevice!);
              switch (_connectedDevice!.state) {
                case BrilliantConnectionState.connected:
                  triggerEvent(Event.deviceConnected);
                  break;
                case BrilliantConnectionState.dfuConnected:
                  triggerEvent(Event.updatableDeviceConnected);
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
              await _connectedDevice!.uploadScript(
                'main.lua',
                'assets/lua_scripts/main.lua',
              );
              triggerEvent(Event.done);
            } catch (_) {
              triggerEvent(Event.error);
            }
          });

          state.changeOn(Event.done, State.uploadGraphicsLua);
          state.changeOn(Event.error, State.requiresRepair);
          break;

        case State.uploadGraphicsLua:
          state.onEntry(() async {
            try {
              await _connectedDevice!.uploadScript(
                'graphics.lua',
                'assets/lua_scripts/graphics.lua',
              );
              triggerEvent(Event.done);
            } catch (_) {
              triggerEvent(Event.error);
            }
          });

          state.changeOn(Event.done, State.uploadStateLua);
          state.changeOn(Event.error, State.requiresRepair);
          break;

        case State.uploadStateLua:
          state.onEntry(() async {
            try {
              await _connectedDevice!.uploadScript(
                'state.lua',
                'assets/lua_scripts/state.lua',
              );
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
            _connectedDevice!
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
                _connectedDevice!.stringResponse.listen((event) {});

            _dataResponseStream?.cancel();
            _dataResponseStream =
                _connectedDevice!.dataResponse.listen((event) async {
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

              switch (event[0]) {
                case 0x10:
                  _log.info("Received user generation request from device");
                  _audioData.clear();
                  _imageData.clear();
                  break;
                case 0x12:
                  _log.info("Received wildcard request from device");
                  try {
                    noaMessages += await NoaApi.getWildcardMessage(
                      (await _getUserAuthToken())!,
                      getTunePrompt(),
                      _tuneTemperature / 50,
                      textToSpeech,
                    );
                    noaUser =
                        await NoaApi.getUser((await _getUserAuthToken())!);
                    triggerEvent(Event.noaResponse);
                  } catch (_) {}
                  break;
                case 0x13:
                  _audioData += event.sublist(1);
                  break;
                case 0x14:
                  _imageData += event.sublist(1);
                  break;
                case 0x15:
                  _log.info(
                      "Received all data from device. ${_audioData.length} bytes of audio, ${_imageData.length} bytes of image");
                  try {
                    final newMessages = await NoaApi.getMessage(
                        (await _getUserAuthToken())!,
                        Uint8List.fromList(_audioData),
                        Uint8List.fromList(_imageData),
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
                    noaMessages += newMessages;
                    noaUser =
                        await NoaApi.getUser((await _getUserAuthToken())!);
                    triggerEvent(Event.noaResponse);
                  } catch (_) {}
                  break;
              }
            });
          });

          state.changeOn(Event.noaResponse, State.sendResponseToDevice);
          state.changeOn(Event.deviceDisconnected, State.disconnected);
          state.changeOn(Event.logoutPressed, State.logout);
          state.changeOn(Event.deletePressed, State.deleteAccount);
          break;

        case State.sendResponseToDevice:
          state.onEntry(() async {
            try {
              final splitString = utf8
                  .encode(noaMessages.last.message)
                  .slices(_connectedDevice!.maxDataLength! - 1);
              for (var slice in splitString) {
                List<int> data = slice.toList()..insert(0, 0x20);
                await _connectedDevice!
                    .sendData(data)
                    .timeout(const Duration(seconds: 1));
                await Future.delayed(const Duration(milliseconds: 50));
              }
              await Future.delayed(const Duration(milliseconds: 300));
            } catch (_) {}
            triggerEvent(Event.done);
          });

          state.changeOn(Event.done, State.connected);
          state.changeOn(Event.logoutPressed, State.logout);
          state.changeOn(Event.deletePressed, State.deleteAccount);
          break;

        case State.disconnected:
          state.onEntry(() async {
            _connectionStream?.cancel();
            _connectionStream =
                _connectedDevice?.connectionState.listen((event) {
              _connectedDevice = event;
              if (event.state == BrilliantConnectionState.connected) {
                triggerEvent(Event.deviceConnected);
              }
            });
            _connectionStream?.onError((_) {});

            try {
              _connectedDevice ??= await BrilliantBluetooth.reconnect(
                  (await _getPairedDevice())!);
              if (_connectedDevice?.state ==
                  BrilliantConnectionState.connected) {
                triggerEvent(Event.deviceConnected);
              }
            } catch (_) {}
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
              _log.info("Firmware version: ${utf8.decode(event.sublist(1))}");
              if (utf8.decode(event.sublist(1)) == _firmwareVersion) {
                triggerEvent(Event.deviceUpToDate);
              } else {
                triggerEvent(Event.deviceNeedsUpdate);
              }
            });
            try {
              await _connectedDevice!
                  .sendData(List<int>.filled(1, 0x16))
                  .timeout(const Duration(seconds: 1));
            } catch (_) {
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
              _log.info("Script version: ${utf8.decode(event.sublist(1))}");
              if (utf8.decode(event.sublist(1)) == _scriptVersion) {
                triggerEvent(Event.deviceUpToDate);
              } else {
                triggerEvent(Event.deviceNeedsUpdate);
              }
            });
            try {
              await _connectedDevice!
                  .sendData(List<int>.filled(1, 0x17))
                  .timeout(const Duration(seconds: 1));
            } catch (_) {
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
    super.dispose();
  }
}

final model = ChangeNotifierProvider<AppLogicModel>((ref) {
  return AppLogicModel();
});
