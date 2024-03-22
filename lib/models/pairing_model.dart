import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:noa/bluetooth.dart';

enum _State {
  init,
  scanning,
  found,
  connecting,
  checkingVersion,
  updatingFirmware,
  complete,
  requiresRepair,
}

enum _Event {
  start,
  deviceFound,
  deviceLost,
  deviceConnected,
  deviceDisconnected,
  deviceInvalid,
  buttonPressed,
  cancelPressed,
}

class PairingModel extends ChangeNotifier {
  // Public interface
  String connectionBoxText = "";
  String connectionBoxButtonText = "";
  bool connectionBoxButtonEnabled = false;
  bool gotoNoaPage = false;
  void connectionBoxClicked() => _updateState(_Event.buttonPressed);
  void cancelButtonClicked() => _updateState(_Event.cancelPressed);

  // Private constructor and bluetooth stream listeners
  final _scanStreamController = StreamController<BrilliantScannedDevice>();
  final _connectionStreamController = StreamController<BrilliantDevice>();

  PairingModel() {
    _scanStreamController.stream
        .where((event) => event.rssi > -55)
        .timeout(const Duration(seconds: 2), onTimeout: (_) {
      _updateState(_Event.deviceLost);
    }).listen((device) {
      _updateState(_Event.deviceFound, scannedDevice: device);
    });

    _connectionStreamController.stream.listen((device) async {
      switch (device.state) {
        case BrilliantConnectionState.connected:
          _updateState(_Event.deviceConnected, connectedDevice: device);
          break;
        case BrilliantConnectionState.disconnected:
          _updateState(_Event.deviceDisconnected);
          break;
        case BrilliantConnectionState.invalid:
          _updateState(_Event.deviceInvalid);
          break;
      }
    });

    _updateState(_Event.start);
  }

  // Private state variables
  // BrilliantDevice? connectedDevice; // TODO move this out
  _State _currentState = _State.init;
  BrilliantScannedDevice? _nearbyDevice;

  void _updateState(
    _Event event, {
    BrilliantScannedDevice? scannedDevice,
    BrilliantDevice? connectedDevice,
  }) {
    print("Event: $event");

    // Change state based on events
    switch (_currentState) {
      case _State.init:
        switch (event) {
          case _Event.start:
            BrilliantBluetooth.scan(_scanStreamController);
            _currentState = _State.scanning;
            break;
          default:
        }
        break;
      case _State.scanning:
        switch (event) {
          case _Event.deviceFound:
            _nearbyDevice = scannedDevice;
            _currentState = _State.found;
            break;
          case _Event.cancelPressed:
            _currentState = _State.complete;
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
          case _Event.buttonPressed:
            BrilliantBluetooth.connect(
              _nearbyDevice!,
              _connectionStreamController,
            );
            BrilliantBluetooth.stopScan();
            _currentState = _State.connecting;
            break;
          case _Event.cancelPressed:
            _currentState = _State.complete;
            break;
          default:
        }
        break;
      case _State.connecting:
        switch (event) {
          case _Event.deviceConnected:
            // TODO set device
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
          // TODO
          default:
            _currentState = _State.complete;
        }
        break;
      case _State.updatingFirmware:
        switch (event) {
          default:
        }
        break;
      case _State.requiresRepair:
        switch (event) {
          case _Event.buttonPressed:
            BrilliantBluetooth.scan(_scanStreamController);
            _currentState = _State.scanning;
            break;
          case _Event.cancelPressed:
            _currentState = _State.complete;
            break;
          default:
        }
        break;
      case _State.complete:
        _currentState = _State.init;
        break;
    }

    // Set the outputs based on the new state
    switch (_currentState) {
      case _State.init:
      case _State.scanning:
        gotoNoaPage = false;
        connectionBoxText = "Bring your device close";
        connectionBoxButtonText = "Searching";
        connectionBoxButtonEnabled = false;
        break;
      case _State.found:
        gotoNoaPage = false;
        connectionBoxText = "Frame found";
        connectionBoxButtonText = "Pair";
        connectionBoxButtonEnabled = true;
        break;
      case _State.connecting:
        gotoNoaPage = false;
        connectionBoxText = "Frame found";
        connectionBoxButtonText = "Connecting";
        connectionBoxButtonEnabled = false;
        break;
      case _State.checkingVersion:
        gotoNoaPage = false;
        connectionBoxText = "Checking firmware";
        connectionBoxButtonText = "Connecting";
        connectionBoxButtonEnabled = false;
        break;
      case _State.updatingFirmware:
        gotoNoaPage = false;
        connectionBoxText = "Updating";
        connectionBoxButtonText = "Keep your device close";
        connectionBoxButtonEnabled = false;
        break;
      case _State.requiresRepair:
        gotoNoaPage = false;
        connectionBoxText = "Un-pair Frame first";
        connectionBoxButtonText = "Try again";
        connectionBoxButtonEnabled = true;
        break;
      case _State.complete:
        gotoNoaPage = true;
        break;
    }

    print("New state: $_currentState");

    notifyListeners();
  }

  @override
  void dispose() {
    print("disposing");
    BrilliantBluetooth.stopScan();
    _scanStreamController.close();
    _connectionStreamController.close();
    super.dispose();
  }
}
