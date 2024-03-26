import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:noa/bluetooth.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger("Bluetooth Model");

enum _State {
  init,
  scanning,
  found,
  connecting,
  checkingVersion,
  updatingFirmware,
  uploadingApp,
  requiresRepair,
  connected,
  disconnected,
}

enum _Event {
  startPairing,
  deviceFound,
  deviceLost,
  deviceConnected,
  deviceDisconnected,
  deviceInvalid,
  pairingButtonPressed,
  pairingCancelPressed,
  deletePairing,
  responseString,
  responseData,
}

class BluetoothConnectionModel extends ChangeNotifier {
  // Public interface
  String pairingBoxText = "";
  String pairingBoxButtonText = "";
  bool pairingBoxButtonEnabled = false;
  bool pairingComplete = false;
  void startPairing() => _updateState(_Event.startPairing);
  void pairingButtonPressed() => _updateState(_Event.pairingButtonPressed);
  void pairingCancelPressed() => _updateState(_Event.pairingCancelPressed);
  void deletePairing() => _updateState(_Event.deletePairing);

  // Private constructor and bluetooth stream listeners
  final _scanStreamController = StreamController<BrilliantDevice>();
  final _connectionStreamController = StreamController<BrilliantDevice>();
  final _stringRxStreamController = StreamController<String>();
  final _dataRxStreamController = StreamController<List<int>>();

  BluetoothConnectionModel() {
    _scanStreamController.stream
        .where((device) => device.rssi! > -55)
        .timeout(const Duration(seconds: 2), onTimeout: (_) {
      _updateState(_Event.deviceLost);
    }).listen((device) {
      _updateState(_Event.deviceFound, nearbyDevice: device);
    });

    _connectionStreamController.stream.listen((device) async {
      switch (device.state) {
        case BrilliantConnectionState.connected:
          _updateState(_Event.deviceConnected, connectedDevice: device);
          break;
        case BrilliantConnectionState.disconnected:
          _updateState(_Event.deviceDisconnected, connectedDevice: device);
          break;
        case BrilliantConnectionState.invalid:
          _updateState(_Event.deviceInvalid, connectedDevice: device);
          break;
        default:
      }
    });

    _stringRxStreamController.stream.listen((string) {
      _updateState(_Event.responseString, responseString: string);
    });

    _dataRxStreamController.stream.listen((data) {
      _updateState(_Event.responseData, responseData: data);
    });
  }

  // Private state variables
  _State _currentState = _State.init;
  BrilliantDevice? _nearbyDevice;
  BrilliantDevice? _connectedDevice;

  // Logging variable
  _State? _lastState;

  void _updateState(
    _Event event, {
    BrilliantDevice? nearbyDevice,
    BrilliantDevice? connectedDevice,
    String? responseString,
    List<int>? responseData,
  }) async {
    // Change state based on events
    switch (_currentState) {
      case _State.init:
        switch (event) {
          case _Event.startPairing:
            SharedPreferences savedData = await SharedPreferences.getInstance();
            String? deviceUuid = savedData.getString('pairedDevice');

            // If already paired
            if (deviceUuid != null) {
              BrilliantBluetooth.reconnect(
                deviceUuid,
                _connectionStreamController,
              );
              _currentState = _State.disconnected;
              break;
            }

            // Otherwise start scanning and go to scanning
            BrilliantBluetooth.scan(_scanStreamController);
            _currentState = _State.scanning;
            break;
          default:
        }
        break;
      case _State.scanning:
        switch (event) {
          case _Event.deviceFound:
            _nearbyDevice = nearbyDevice;
            _currentState = _State.found;
            break;
          case _Event.pairingCancelPressed:
            BrilliantBluetooth.stopScan();
            _currentState = _State.disconnected;
            break;
          default:
        }
        break;
      case _State.found:
        switch (event) {
          case _Event.deviceLost:
            _nearbyDevice = null;
            _currentState = _State.scanning;
            break;
          case _Event.pairingButtonPressed:
            _nearbyDevice!.connect(_connectionStreamController);
            BrilliantBluetooth.stopScan();
            _currentState = _State.connecting;
            break;
          case _Event.pairingCancelPressed:
            BrilliantBluetooth.stopScan();
            _currentState = _State.disconnected;
            break;
          default:
        }
        break;
      case _State.connecting:
        switch (event) {
          case _Event.deviceConnected:
            _connectedDevice = connectedDevice;
            _connectedDevice!.stringRxListener = _stringRxStreamController;
            _connectedDevice!.dataRxListener = _dataRxStreamController;
            _connectedDevice!.writeString("print(frame.FIRMWARE_VERSION)");
            _currentState = _State.checkingVersion;
            break;
          case _Event.deviceInvalid:
            _currentState = _State.requiresRepair;
            break;
          default:
        }
        break;
      case _State.checkingVersion:
        switch (event) {
          case _Event.responseString:
            if (responseString == "v24.065.1346") {
              _connectedDevice!.uploadScript('assets/lua_scripts/main.lua');
              _currentState = _State.uploadingApp;
            } else {
              _currentState = _State.updatingFirmware;
            }
            break;
          default:
        }
        break;
      case _State.updatingFirmware:
        // TODO
        switch (event) {
          default:
        }
        break;
      case _State.uploadingApp:
        switch (event) {
          default:
            SharedPreferences savedData = await SharedPreferences.getInstance();
            await savedData.setString('pairedDevice', _connectedDevice!.uuid);
        }
        break;
      case _State.requiresRepair:
        switch (event) {
          case _Event.pairingButtonPressed:
            BrilliantBluetooth.scan(_scanStreamController);
            _currentState = _State.scanning;
            break;
          case _Event.pairingCancelPressed:
            _currentState = _State.disconnected;
            break;
          default:
        }
        break;
      case _State.connected:
        switch (event) {
          case _Event.deviceDisconnected:
            _connectedDevice = connectedDevice!;
            _currentState = _State.disconnected;
            break;
          case _Event.deletePairing:
            _connectedDevice!.disconnect();
            _connectedDevice = null;
            final savedData = await SharedPreferences.getInstance();
            await savedData.remove('pairedDevice');
            _currentState = _State.init;
            break;
          default:
        }
        break;
      case _State.disconnected:
        switch (event) {
          case _Event.deviceConnected:
            _connectedDevice = connectedDevice!;
            _connectedDevice!.stringRxListener = _stringRxStreamController;
            _connectedDevice!.dataRxListener = _dataRxStreamController;
            _currentState = _State.connected;
            break;
          case _Event.deletePairing:
            _connectedDevice?.disconnect();
            _connectedDevice = null;
            final savedData = await SharedPreferences.getInstance();
            await savedData.remove('pairedDevice');
            _currentState = _State.init;
            break;
          default:
        }
        break;
    }

    // Set the outputs based on the new state
    switch (_currentState) {
      case _State.init:
      case _State.scanning:
        pairingComplete = false;
        pairingBoxText = "Bring your device close";
        pairingBoxButtonText = "Searching";
        pairingBoxButtonEnabled = false;
        break;
      case _State.found:
        pairingComplete = false;
        pairingBoxText = "Frame found";
        pairingBoxButtonText = "Pair";
        pairingBoxButtonEnabled = true;
        break;
      case _State.connecting:
        pairingComplete = false;
        pairingBoxText = "Frame found";
        pairingBoxButtonText = "Connecting";
        pairingBoxButtonEnabled = false;
        break;
      case _State.checkingVersion:
        pairingComplete = false;
        pairingBoxText = "Checking firmware";
        pairingBoxButtonText = "Connecting";
        pairingBoxButtonEnabled = false;
        break;
      case _State.updatingFirmware:
        pairingComplete = false;
        pairingBoxText = "Updating";
        pairingBoxButtonText = "Keep your device close";
        pairingBoxButtonEnabled = false;
        break;
      case _State.uploadingApp:
        pairingComplete = false;
        pairingBoxText = "Uploading Noa";
        pairingBoxButtonText = "Keep your device close";
        pairingBoxButtonEnabled = false;
        break;
      case _State.requiresRepair:
        pairingComplete = false;
        pairingBoxText = "Un-pair Frame first";
        pairingBoxButtonText = "Try again";
        pairingBoxButtonEnabled = true;
        break;
      case _State.connected:
        pairingComplete = true;
        break;
      case _State.disconnected:
        pairingComplete = true;
        break;
    }

    // Logging
    if (_currentState != _lastState) {
      _log.info("Bluetooth Model: $_lastState → ($event) → $_currentState");
      _lastState = _currentState;
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
