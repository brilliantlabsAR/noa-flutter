import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:noa/noa_api.dart';
import 'package:noa/bluetooth.dart';
import 'package:noa/util/dfu.dart';
import 'package:noa/util/state_machine.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger("App logic");

enum State {
  waitForLogin,
  getPairedDevice,
  scanning,
  found,
  connect,
  sendBreak,
  checkVersion,
  uploadMainLua,
  uploadGraphicsLua,
  uploadStateLua,
  updatingFirmware,
  requiresRepair,
  connected,
  sendResponseToDevice,
  disconnected,
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
  deviceDisconnected,
  deviceInvalid,
  buttonPressed,
  cancelPressed,
  logoutPressed,
  deletePressed,
  deviceStringResponse,
  deviceDataResponse,
  noaResponse,
  updateFirmware,
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
  StateMachine state = StateMachine(State.waitForLogin);
  String? pairedDevice;
  NoaUser noaUser = NoaUser();
  final List<NoaMessage> noaMessages = List.empty(growable: true);

  // User's tune preferences
  String _tuneStyle = "";
  String get tuneStyle => _tuneStyle;
  set tuneStyle(String value) {
    _tuneStyle = value;
    () async {
      final savedData = await SharedPreferences.getInstance();
      savedData.setString("tuneStyle", _tuneStyle);
    }();
  }

  String _tuneTone = "";
  String get tuneTone => _tuneTone;
  set tuneTone(String value) {
    _tuneTone = value;
    () async {
      final savedData = await SharedPreferences.getInstance();
      savedData.setString("tuneTone", _tuneTone);
    }();
  }

  String _tuneFormat = "";
  String get tuneFormat => _tuneFormat;
  set tuneFormat(String value) {
    _tuneFormat = value;
    () async {
      final savedData = await SharedPreferences.getInstance();
      savedData.setString("tuneFormat", _tuneFormat);
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

  TuneLength _tuneLength = TuneLength.standard;
  TuneLength get tuneLength => _tuneLength;
  set length(TuneLength value) {
    _tuneLength = value;
    () async {
      final savedData = await SharedPreferences.getInstance();
      savedData.setString("tuneLength", _tuneLength.name);
    }();
    notifyListeners();
  }

  // Private state variables
  bool _eventBeingProcessed = false;
  BrilliantDevice? _nearbyDevice;
  BrilliantDevice? _connectedDevice;
  String? _luaResponse;
  List<int>? _dataResponse;
  String? _appFirmwareVersion;
  List<int> _audioData = List.empty(growable: true);
  List<int> _imageData = List.empty(growable: true);
  String? _userAuthToken;

  // Bluetooth stream listeners
  final _scanStreamController = StreamController<BrilliantDevice>();
  final _connectionStreamController = StreamController<BrilliantDevice>();
  final _stringRxStreamController = StreamController<String>();
  final _dataRxStreamController = StreamController<List<int>>();

  // Noa steam listeners
  final _noaResponseStreamController = StreamController<NoaMessage>();
  final _noaUserInfoStreamController = StreamController<NoaUser>();


  // firmware update progress stream
  StreamController<double> firmwareUpdateStreamController = StreamController<double>();
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

    // Monitors Bluetooth scan events
    _scanStreamController.stream
        .where((device) => device.rssi! > -55)
        .timeout(const Duration(seconds: 2), onTimeout: (_) {
      triggerEvent(Event.deviceLost);
    }).listen((device) {
      _nearbyDevice = device;
      triggerEvent(Event.deviceFound);
    });

    // Monitors Bluetooth connection events
    _connectionStreamController.stream.listen((device) async {
      _connectedDevice = device;
      switch (device.state) {
        case BrilliantConnectionState.connected:
        if (_connectedDevice!.dfuDevice == true) {
            _connectedDevice!.firmwareUpdateListener = firmwareUpdateStreamController;
            triggerEvent(Event.updateFirmware);
            break;
          }
          _connectedDevice!.stringRxListener = _stringRxStreamController;
          _connectedDevice!.dataRxListener = _dataRxStreamController;
          triggerEvent(Event.deviceConnected);
          break;
        case BrilliantConnectionState.disconnected:
          triggerEvent(Event.deviceDisconnected);
          break;
        case BrilliantConnectionState.invalid:
          triggerEvent(Event.deviceInvalid);
          break;
        default:
      }
    });

    // Monitors received strings from Bluetooth
    _stringRxStreamController.stream.listen((string) {
      _luaResponse = string;
      triggerEvent(Event.deviceStringResponse);
    });

    // Monitors received data from Bluetooth
    _dataRxStreamController.stream.listen((data) {
      _dataResponse = data;
      triggerEvent(Event.deviceDataResponse);
    });

    // Monitor noa responses
    _noaResponseStreamController.stream.listen((message) {
      noaMessages.add(NoaMessage(
        message: message.message,
        from: message.from,
        time: message.time,
        image: message.image,
      ));
      if (message.from == NoaRole.noa) {
        triggerEvent(Event.noaResponse);
      }
    });

    // Monitor user stats
    _noaUserInfoStreamController.stream.listen((user) {
      noaUser = user;
    });
  }

  void loggedIn(String userAuthToken) async {
    _userAuthToken = userAuthToken;
    final savedData = await SharedPreferences.getInstance();
    await savedData.setString('userAuthToken', userAuthToken);
    triggerEvent(Event.loggedIn);
  }

  void triggerEvent(Event event) {
    if (_eventBeingProcessed) {
      _log.severe("Too many events: $event");
    }

    _eventBeingProcessed = true;

    state.event(event);

    do {
      switch (state.current) {
        case State.waitForLogin:
          state.onEntry(() async {
            final savedData = await SharedPreferences.getInstance();
            _tuneStyle = savedData.getString('tuneStyle') ?? "";
            _tuneTone = savedData.getString('tuneTone') ?? "";
            _tuneFormat = savedData.getString('tuneFormat') ?? "";
            _tuneTemperature = savedData.getInt('tuneTemperature') ?? 50;
            var len = savedData.getString('tuneLength') ?? 'standard';
            _tuneLength = TuneLength.values
                .firstWhere((e) => e.toString() == 'TuneLength.$len');
            _userAuthToken = savedData.getString('userAuthToken');
            if (_userAuthToken != null) {
              triggerEvent(Event.loggedIn);
            }
          });
          state.changeOn(Event.loggedIn, State.getPairedDevice,
              transitionTask: () => NoaApi.getUser(
                  _userAuthToken!, _noaUserInfoStreamController));
          break;

        case State.getPairedDevice:
          state.onEntry(() async {
            final savedData = await SharedPreferences.getInstance();
            pairedDevice = savedData.getString('pairedDevice');
            triggerEvent(Event.done);
          });

          if (pairedDevice == null) {
            state.changeOn(Event.done, State.scanning);
          } else {
            state.changeOn(Event.done, State.disconnected,
                transitionTask: () async => await BrilliantBluetooth.reconnect(
                      pairedDevice!,
                      _connectionStreamController,
                    ));
          }
          break;

        case State.scanning:
          state.onEntry(
              () async => await BrilliantBluetooth.scan(_scanStreamController));
          state.changeOn(Event.deviceFound, State.found);
          state.changeOn(Event.cancelPressed, State.disconnected,
              transitionTask: () async => await BrilliantBluetooth.stopScan());
          break;

        case State.found:
          state.changeOn(Event.deviceLost, State.scanning);
          state.changeOn(Event.buttonPressed, State.connect,
              transitionTask: () async => await BrilliantBluetooth.stopScan());
          state.changeOn(Event.cancelPressed, State.disconnected,
              transitionTask: () async => await BrilliantBluetooth.stopScan());
          break;

        case State.connect:
          state.onEntry(() async =>
              await _nearbyDevice!.connect(_connectionStreamController));
          state.changeOn(Event.updateFirmware, State.updatingFirmware);
          state.changeOn(Event.deviceInvalid, State.requiresRepair);
          state.changeOn(Event.deviceConnected, State.sendBreak);
          break;

        case State.sendBreak:
          state.onEntry(() async {
            try {
              await _connectedDevice!.sendBreakSignal();
              triggerEvent(Event.done);
            } catch (_) {
              triggerEvent(Event.error);
            }
          });
          state.changeOn(Event.done, State.checkVersion);
          state.changeOn(Event.error, State.requiresRepair);
          break;

        case State.checkVersion:
          state.onEntry(() async {
            _appFirmwareVersion = await Firmware.currentVersion();
            _connectedDevice!.stringRxListener = _stringRxStreamController;
            _connectedDevice!.dataRxListener = _dataRxStreamController;
            try {
              await _connectedDevice!
                  .sendString("print(frame.FIRMWARE_VERSION)")
                  .timeout(const Duration(seconds: 1));
            } catch (_) {
              triggerEvent(Event.error);
            }
          });
          _log.info("App logic: App Firmware version: $_appFirmwareVersion");
          _log.info("App logic: Device version: $_luaResponse");
          if (_luaResponse == _appFirmwareVersion) {
            state.changeOn(Event.deviceStringResponse, State.uploadMainLua);
          } else {
            try {
              _connectedDevice!.sendString("print(frame.update());", awaitResponse: false);
            } catch (_) {
              triggerEvent(Event.error);
            }
            state.changeOn(Event.deviceDisconnected, State.updatingFirmware);
          }
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
              triggerEvent(Event.done);
            } catch (_) {
              triggerEvent(Event.error);
            }
          });

          state.changeOn(Event.done, State.connected, transitionTask: () async {
            SharedPreferences savedData = await SharedPreferences.getInstance();
            await savedData.setString('pairedDevice', _connectedDevice!.uuid);
          });
          state.changeOn(Event.error, State.requiresRepair);
          break;

        case State.updatingFirmware:
          state.onEntry(() async {
            try {
              _connectedDevice!.firmwareUpdateListener = firmwareUpdateStreamController;
              await _connectedDevice!.updateFirmware();
              triggerEvent(Event.done);
            } catch (_) {
              triggerEvent(Event.error);
            }
          });
          break;

        case State.requiresRepair:
          state.changeOn(Event.buttonPressed, State.scanning);
          state.changeOn(Event.cancelPressed, State.disconnected);
          break;

        case State.connected:
          if (event == Event.deviceDataResponse) {
            switch (_dataResponse?[0]) {
              // Start flag
              case 0x10:
                _log.info("Received start flag from device");
                _audioData.clear();
                _imageData.clear();
                break;
              case 0x12:
                _audioData += _dataResponse!.sublist(1);
                break;
              case 0x13:
                _imageData += _dataResponse!.sublist(1);
                break;
              case 0x16:
                _log.info(
                    "Received all data from device. ${_audioData.length} bytes of audio, ${_imageData.length} bytes of image");
                String tunePrompt = "";

                if (_tuneStyle != "") {
                  tunePrompt += " in the style of $_tuneStyle";
                }

                if (_tuneTone != "") {
                  tunePrompt += " with a $_tuneTone tone";
                }

                if (_tuneFormat != "") {
                  tunePrompt += " formatted as $_tuneFormat";
                }

                switch (_tuneLength) {
                  case TuneLength.shortest:
                    tunePrompt += ". Limit responses to 1 to 3 words";
                    break;
                  case TuneLength.short:
                    tunePrompt += ". Limit responses to 1 sentence";
                    break;
                  case TuneLength.standard:
                    tunePrompt += ". Limit responses to 1 to 2 sentences";
                    break;
                  case TuneLength.long:
                    tunePrompt += ". Limit responses to 1 short paragraph";
                    break;
                  case TuneLength.longest:
                    tunePrompt += ". Limit responses to 2 paragraphs";
                    break;
                }

                NoaApi.getMessage(
                  _userAuthToken!,
                  Uint8List.fromList(_audioData),
                  Uint8List.fromList(_imageData),
                  tunePrompt,
                  _tuneTemperature / 50,
                  noaMessages,
                  _noaResponseStreamController,
                  _noaUserInfoStreamController,
                );
                break;
            }
          }

          state.changeOn(Event.noaResponse, State.sendResponseToDevice);
          state.changeOn(Event.deviceDisconnected, State.disconnected);
          state.changeOn(Event.logoutPressed, State.logout);
          state.changeOn(Event.deletePressed, State.deleteAccount);
          break;

        case State.sendResponseToDevice:
          state.onEntry(() async {
            try {
              // TODO split string before sending
              List<int> data = utf8.encode(noaMessages.last.message).toList();
              data.insert(0, 0x11);
              await _connectedDevice!
                  .sendData(data)
                  .timeout(const Duration(seconds: 1));
              await Future.delayed(const Duration(milliseconds: 300));
            } catch (error) {
              _log.warning("Could not respond to device: $error");
            }
            triggerEvent(Event.done);
          });

          state.changeOn(Event.done, State.connected);
          state.changeOn(Event.deviceDisconnected, State.disconnected);
          state.changeOn(Event.logoutPressed, State.logout);
          state.changeOn(Event.deletePressed, State.deleteAccount);
          break;

        case State.disconnected:
          state.changeOn(Event.deviceConnected, State.connected);
          state.changeOn(Event.logoutPressed, State.logout);
          state.changeOn(Event.deletePressed, State.deleteAccount);
          break;

        case State.logout:
          state.onEntry(() async {
            await _connectedDevice?.disconnect();
            await NoaApi.signOut(_userAuthToken!);
            final savedData = await SharedPreferences.getInstance();
            await savedData.clear();
            pairedDevice = null;
            triggerEvent(Event.done);
          });
          state.changeOn(Event.done, State.waitForLogin);
          break;

        case State.deleteAccount:
          state.onEntry(() async {
            await _connectedDevice?.disconnect();
            await NoaApi.deleteUser(_userAuthToken!);
            final savedData = await SharedPreferences.getInstance();
            await savedData.clear();
            pairedDevice = null;
            triggerEvent(Event.done);
          });
          state.changeOn(Event.done, State.waitForLogin);
          break;
      }
    } while (state.changePending());

    notifyListeners();

    _eventBeingProcessed = false;
  }

  @override
  void dispose() {
    BrilliantBluetooth.stopScan();
    _scanStreamController.close();
    _connectionStreamController.close();
    _stringRxStreamController.close();
    _dataRxStreamController.close();
    _noaResponseStreamController.close();
    super.dispose();
  }
}

final model = ChangeNotifierProvider<AppLogicModel>((ref) {
  return AppLogicModel();
});
