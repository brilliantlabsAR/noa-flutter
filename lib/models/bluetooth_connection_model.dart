import 'dart:async';
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
  checkVersion,
  uploadMainLua,
  uploadGraphicsLua,
  uploadStateLua,
  updatingFirmware,
  requiresRepair,
  connected,
  disconnected,
  deletePairing,
}

enum Event {
  startScanning,
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

class BluetoothConnectionModel extends ChangeNotifier {
  // Private state variables
  StateMachine state = StateMachine(State.init);
  BrilliantDevice? _nearbyDevice;
  BrilliantDevice? _connectedDevice;
  String? _luaResponse;
  List<int>? _dataResponse;

  // Bluetooth stream listeners
  final _scanStreamController = StreamController<BrilliantDevice>();
  final _connectionStreamController = StreamController<BrilliantDevice>();
  final _stringRxStreamController = StreamController<String>();
  final _dataRxStreamController = StreamController<List<int>>();

  BluetoothConnectionModel() {
    _scanStreamController.stream
        .where((device) => device.rssi! > -55)
        .timeout(const Duration(seconds: 2), onTimeout: (_) {
      triggerEvent(Event.deviceLost);
    }).listen((device) {
      _nearbyDevice = device;
      triggerEvent(Event.deviceFound);
    });

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

    _stringRxStreamController.stream.listen((string) {
      _luaResponse = string;
      triggerEvent(Event.luaResponse);
    });

    _dataRxStreamController.stream.listen((data) {
      _dataResponse = data;
      triggerEvent(Event.responseData);
    });
  }

  void triggerEvent(Event event) async {
    _log.info("Bluetooth Model: New event: $event");

    switch (state.currentState) {
      case State.init:
        SharedPreferences savedData = await SharedPreferences.getInstance();
        String? deviceUuid = savedData.getString('pairedDevice');

        if (deviceUuid == null) {
          state.changeIf(event == Event.startScanning, State.scanning);
        } else {
          state.changeIf(event == Event.startScanning, State.disconnected,
              transitionTask: () => BrilliantBluetooth.reconnect(
                    deviceUuid,
                    _connectionStreamController,
                  ));
        }
        break;

      case State.scanning:
        state.onEntry(() => BrilliantBluetooth.scan(_scanStreamController));
        state.changeIf(event == Event.deviceFound, State.found);
        state.changeIf(event == Event.cancelPressed, State.disconnected,
            transitionTask: () => BrilliantBluetooth.stopScan());
        break;

      case State.found:
        state.changeIf(event == Event.deviceLost, State.scanning);
        state.changeIf(event == Event.buttonPressed, State.connect,
            transitionTask: () => BrilliantBluetooth.stopScan());
        state.changeIf(event == Event.cancelPressed, State.disconnected,
            transitionTask: () => BrilliantBluetooth.stopScan());
        break;

      case State.connect:
        state
            .onEntry(() => _nearbyDevice!.connect(_connectionStreamController));
        state.changeIf(event == Event.deviceConnected, State.checkVersion);
        state.changeIf(event == Event.deviceInvalid, State.requiresRepair);
        break;

      case State.checkVersion:
        state.onEntry(() async {
          SharedPreferences savedData = await SharedPreferences.getInstance();
          await savedData.setString('pairedDevice', _connectedDevice!.uuid);
          _connectedDevice!.stringRxListener = _stringRxStreamController;
          _connectedDevice!.dataRxListener = _dataRxStreamController;
          _connectedDevice!.writeString("print(frame.FIRMWARE_VERSION)");
        });

        if (_luaResponse == "v24.065.1346") {
          state.changeIf(event == Event.luaResponse, State.uploadMainLua);
        } else {
          state.changeIf(event == Event.luaResponse, State.updatingFirmware);
        }
        break;

      case State.uploadMainLua:
        state.onEntry(() =>
            _connectedDevice!.uploadScript('assets/lua_scripts/main.lua'));

        if (_luaResponse == "") {
          state.changeIf(event == Event.luaResponse, State.uploadGraphicsLua);
        } else {
          state.changeIf(event == Event.luaResponse, State.requiresRepair);
        }
        break;

      case State.uploadGraphicsLua:
        state.onEntry(() =>
            _connectedDevice!.uploadScript('assets/lua_scripts/graphics.lua'));

        if (_luaResponse == "") {
          state.changeIf(event == Event.luaResponse, State.uploadStateLua);
        } else {
          state.changeIf(event == Event.luaResponse, State.requiresRepair);
        }
        break;

      case State.uploadStateLua:
        state.onEntry(() =>
            _connectedDevice!.uploadScript('assets/lua_scripts/state.lua'));

        if (_luaResponse == "") {
          state.changeIf(event == Event.luaResponse, State.connected);
        } else {
          state.changeIf(event == Event.luaResponse, State.requiresRepair);
        }
        break;

      case State.updatingFirmware:
        // TODO
        break;

      case State.requiresRepair:
        state.changeIf(event == Event.buttonPressed, State.scanning);
        state.changeIf(event == Event.cancelPressed, State.disconnected);
        break;

      case State.connected:
        state.changeIf(event == Event.deviceDisconnected, State.disconnected);
        state.changeIf(event == Event.deletePressed, State.deletePairing);
        break;

      case State.disconnected:
        state.changeIf(event == Event.deviceConnected, State.connected);
        state.changeIf(event == Event.deletePressed, State.deletePairing);

      case State.deletePairing:
        state.onEntry(() async {
          final savedData = await SharedPreferences.getInstance();
          await savedData.remove('pairedDevice');
        });

        state.changeIf(true, State.init);
        break;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    BrilliantBluetooth.stopScan();
    _scanStreamController.close();
    _connectionStreamController.close();
    super.dispose();
  }
}
