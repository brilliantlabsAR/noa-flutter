import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum BrilliantDeviceName { frame, frameUpdate, monocle, monocleUpdate }

BrilliantDeviceName _deviceNameFromAdvName(String advName) {
  switch (advName) {
    case "Frame":
      return BrilliantDeviceName.frame;
    case "Frame Update":
      return BrilliantDeviceName.frameUpdate;
    case "Monocle":
      return BrilliantDeviceName.monocle;
    case "DFUTarg":
      return BrilliantDeviceName.monocleUpdate;
    default:
      throw Exception("Unknown device");
  }
}

enum BrilliantConnectionState {
  scanned,
  disconnected,
  connected,
  invalid,
}

class BrilliantDevice {
  BrilliantDeviceName name;
  BrilliantConnectionState state;
  BluetoothDevice device;
  String uuid;
  int? rssi;
  int? mtu;

  late BluetoothCharacteristic _txChannel;
  late BluetoothCharacteristic _rxChannel;

  BrilliantDevice({
    required this.name,
    required this.state,
    required this.device,
    required this.uuid,
    this.rssi,
    this.mtu,
  });

  void connect(StreamController<BrilliantDevice> listener) async {
    try {
      await device.connect(
        autoConnect: true,
        timeout: const Duration(seconds: 2),
        mtu: null,
      );
    } catch (error) {
      state = BrilliantConnectionState.invalid;
      listener.sink.add(this);
    }

    device.connectionState.listen((connectionState) async {
      switch (connectionState) {
        case BluetoothConnectionState.connected:
          try {
            await _enableServices();
            state = BrilliantConnectionState.connected;
            mtu = device.mtuNow;
          } catch (error) {
            await device.disconnect();
            state = BrilliantConnectionState.invalid;
          }
          break;
        case BluetoothConnectionState.disconnected:
          // TODO differentiate as invalid when "Device has disconnected from us" error occurs
          state = BrilliantConnectionState.disconnected;
          break;
        default:
          break;
      }

      listener.sink.add(this);
    });
  }

  void disconnect() {
    device.disconnect();
  }

  Future<String?> writeString(String string) async {
    String test = "frame.imu.tap_callback(function() print('Oi!') end)";
    _txChannel.write(utf8.encode(test), withoutResponse: true);
  }

  Future<String?> writeData(String data) async {}

  Future<void> _enableServices() async {
    try {
      List<BluetoothService> services = await device.discoverServices();

      for (var service in services) {
        // TODO If Monocle
        // If Frame
        if (service.serviceUuid ==
            Guid('7a230001-5475-a6a4-654c-8431f6ad49c4')) {
          for (var characteristic in service.characteristics) {
            if (characteristic.characteristicUuid ==
                Guid('7a230002-5475-a6a4-654c-8431f6ad49c4')) {
              _txChannel = characteristic;
            }
            if (characteristic.characteristicUuid ==
                Guid('7a230003-5475-a6a4-654c-8431f6ad49c4')) {
              _rxChannel = characteristic;

              // final subscription = characteristic.onValueReceived.listen((value) {
              //   // TODO call callback
              //   print(utf8.decode(value));
              // });
              // device.cancelWhenDisconnected(subscription);

              await characteristic.setNotifyValue(true);
            }
          }
        }
        // TODO If DFU
      }
    } catch (error) {
      return Future.error(error);
    }
  }
}

class BrilliantBluetooth {
  static void init() async {
    await FlutterBluePlus.startScan();
    await FlutterBluePlus.stopScan();
  }

  static void scan(StreamController<BrilliantDevice> listener) async {
    // TODO return an RSSI sorted list of BrilliantDevices
    late ScanResult nearestDevice;

    StreamSubscription scan = FlutterBluePlus.onScanResults.listen((results) {
      if (results.isEmpty) {
        return;
      }

      nearestDevice = results[0];

      for (int i = 0; i < results.length; i++) {
        if (results[i].rssi > nearestDevice.rssi) {
          nearestDevice = results[i];
        }
      }

      listener.sink.add(
        BrilliantDevice(
          name: _deviceNameFromAdvName(nearestDevice.device.advName),
          state: BrilliantConnectionState.scanned,
          device: nearestDevice.device,
          uuid: nearestDevice.device.remoteId.toString(),
          rssi: nearestDevice.rssi,
        ),
      );
    });

    FlutterBluePlus.cancelWhenScanComplete(scan);

    await _startScan(true);
  }

  static void stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  static void reconnect(
    String deviceUuid,
    StreamController<BrilliantDevice> listener,
  ) async {
    StreamSubscription scan = FlutterBluePlus.scanResults.listen((results) {
      for (int i = 0; i < results.length; i++) {
        if (results[i].device.remoteId.toString() == deviceUuid) {
          BrilliantDevice(
            name: _deviceNameFromAdvName(results[i].device.advName),
            state: BrilliantConnectionState.scanned,
            device: results[i].device,
            uuid: results[i].device.remoteId.toString(),
            rssi: results[i].rssi,
          ).connect(listener);
        }
      }
    });

    FlutterBluePlus.cancelWhenScanComplete(scan);

    await _startScan(false);
  }

  static Future<void> _startScan(bool continuousUpdates) async {
    await FlutterBluePlus.startScan(
      withServices: [
        Guid('7a230001-5475-a6a4-654c-8431f6ad49c4'),
        Guid('fe59'),
      ],
      continuousUpdates: continuousUpdates,
      removeIfGone: continuousUpdates ? const Duration(seconds: 2) : null,
    );
  }
}
