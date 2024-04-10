import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:noa/bluetooth.dart';
import 'package:noa/util/state_machine.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger("Bluetooth Model");

enum State {
  init,
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
  disconnected,
}

enum Event {
  init,
  done,
  error,
  deviceFound,
  deviceLost,
  deviceConnected,
  deviceDisconnected,
  deviceInvalid,
  buttonPressed,
  cancelPressed,
  deletePressed,
  luaResponse,
  responseData,
}

class AppLogicModel extends ChangeNotifier {
  // Public state variables
  StateMachine state = StateMachine(State.init);
  String? pairedDevice;

  // Private state variables
  bool _eventBeingProcessed = false;
  BrilliantDevice? _nearbyDevice;
  BrilliantDevice? _connectedDevice;
  String? _luaResponse;
  List<int>? _dataResponse;

  // Bluetooth stream listeners
  final _scanStreamController = StreamController<BrilliantDevice>();
  final _connectionStreamController = StreamController<BrilliantDevice>();
  final _stringRxStreamController = StreamController<String>();
  final _dataRxStreamController = StreamController<List<int>>();

  AppLogicModel() {
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
      triggerEvent(Event.luaResponse);
    });

    // Monitors received data from Bluetooth
    _dataRxStreamController.stream.listen((data) {
      _dataResponse = data;
      triggerEvent(Event.responseData);
    });
  }

  void triggerEvent(Event event) {
    if (_eventBeingProcessed) {
      _log.severe("Bluetooth Model: Too many events: $event");
    }

    _eventBeingProcessed = true;

    state.event(event);

    do {
      switch (state.current) {
        case State.init:
          state.onEntry(() async {
            SharedPreferences savedData = await SharedPreferences.getInstance();
            pairedDevice = savedData.getString('pairedDevice');
            triggerEvent(Event.done);
          });

          if (pairedDevice == null) {
            state.changeOn(Event.done, State.scanning);
          } else {
            state.changeOn(Event.done, State.disconnected,
                transitionTask: () => BrilliantBluetooth.reconnect(
                      pairedDevice!,
                      _connectionStreamController,
                    ));
          }
          break;

        case State.scanning:
          state.onEntry(() => BrilliantBluetooth.scan(_scanStreamController));
          state.changeOn(Event.deviceFound, State.found);
          state.changeOn(Event.cancelPressed, State.disconnected,
              transitionTask: () => BrilliantBluetooth.stopScan());
          break;

        case State.found:
          state.changeOn(Event.deviceLost, State.scanning);
          state.changeOn(Event.buttonPressed, State.connect,
              transitionTask: () => BrilliantBluetooth.stopScan());
          state.changeOn(Event.cancelPressed, State.disconnected,
              transitionTask: () => BrilliantBluetooth.stopScan());
          break;

        case State.connect:
          state.onEntry(
              () => _nearbyDevice!.connect(_connectionStreamController));
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
          if (_luaResponse == "v24.065.1346") {
            state.changeOn(Event.luaResponse, State.uploadMainLua);
          } else {
            // TODO go to State.updatingFirmware instead
            state.changeOn(Event.luaResponse, State.uploadMainLua);
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
          // TODO
          break;

        case State.requiresRepair:
          state.changeOn(Event.buttonPressed, State.scanning);
          state.changeOn(Event.cancelPressed, State.disconnected);
          break;

        case State.connected:
          state.changeOn(Event.deviceDisconnected, State.disconnected);
          state.changeOn(Event.deletePressed, State.init,
              transitionTask: () async {
            final savedData = await SharedPreferences.getInstance();
            await savedData.remove('pairedDevice');
          });
          break;

        case State.disconnected:
          state.changeOn(Event.deviceConnected, State.connected);
          state.changeOn(Event.deletePressed, State.init,
              transitionTask: () async {
            final savedData = await SharedPreferences.getInstance();
            await savedData.remove('pairedDevice');
          });
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
    super.dispose();
  }
}

final model = ChangeNotifierProvider<AppLogicModel>((ref) {
  return AppLogicModel();
});
