import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum BrilliantDeviceName { frame, frameUpdate, monocle, monocleUpdate }

enum BrilliantConnectionState {
  disconnected,
  connected,
  invalid,
}

class BrilliantDevice {
  final BluetoothDevice device;
  final BrilliantDeviceName name;
  final String uuid;
  final BrilliantConnectionState state;
  late BluetoothCharacteristic _frameTxCharacteristic;

  BrilliantDevice({
    required this.device,
    required this.name,
    required this.uuid,
    required this.state,
  });

  write() {
    print("Write data");
    String test = "frame.imu.tap_callback(function() print('Oi!') end)";
    _frameTxCharacteristic.write(utf8.encode(test), withoutResponse: true);
  }

  dispose() {}
}

class BrilliantScannedDevice {
  final BluetoothDevice device;
  final int rssi;

  BrilliantScannedDevice({
    required this.device,
    required this.rssi,
  });
}

Future<void> _startScan(bool continuousUpdates) async {
  await FlutterBluePlus.startScan(
    withServices: [
      Guid('7a230001-5475-a6a4-654c-8431f6ad49c4'),
      Guid('8ec90001-f315-4f60-9fb8-838830daea50'),
    ],
    continuousUpdates: continuousUpdates,
    removeIfGone: continuousUpdates ? const Duration(seconds: 2) : null,
  );
}

void _connect(
  BluetoothDevice device,
  StreamController<BrilliantDevice> listener,
) async {
  try {
    await device.connect(
      autoConnect: true,
      timeout: const Duration(seconds: 2),
      mtu: null,
    );
  } catch (error) {
    if (listener.hasListener) {
      listener.sink.add(
        BrilliantDevice(
          device: device,
          name: _deviceNameFromAdvName(device.advName),
          uuid: device.remoteId.toString(),
          state: BrilliantConnectionState.invalid,
        ),
      );
    }
  }

  device.connectionState.listen((connectionState) async {
    late BrilliantConnectionState state;

    switch (connectionState) {
      case BluetoothConnectionState.connected:
        try {
          await _enableServices(device);
          state = BrilliantConnectionState.connected;
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

    if (listener.hasListener) {
      listener.sink.add(
        BrilliantDevice(
          device: device,
          name: _deviceNameFromAdvName(device.advName),
          uuid: device.remoteId.toString(),
          state: state,
        ),
      );
    }
  });
}

Future<BluetoothCharacteristic?> _enableServices(BluetoothDevice device) async {
  BluetoothCharacteristic? frameTxCharacteristic;

  try {
    List<BluetoothService> services = await device.discoverServices();

    for (var service in services) {
      if (service.serviceUuid == Guid('7a230001-5475-a6a4-654c-8431f6ad49c4')) {
        for (var characteristic in service.characteristics) {
          if (characteristic.characteristicUuid ==
              Guid('7a230002-5475-a6a4-654c-8431f6ad49c4')) {
            frameTxCharacteristic = characteristic;
          }
          if (characteristic.characteristicUuid ==
              Guid('7a230003-5475-a6a4-654c-8431f6ad49c4')) {
            final subscription = characteristic.onValueReceived.listen((value) {
              // TODO call callback
              print(utf8.decode(value));
            });
            device.cancelWhenDisconnected(subscription);

            await characteristic.setNotifyValue(true);
          }
        }
      }
    }
  } catch (error) {
    return Future.error(error);
  }

  return frameTxCharacteristic;
}

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

class BrilliantBluetooth {
  static void init() async {
    await FlutterBluePlus.startScan();
    await FlutterBluePlus.stopScan();
  }

  static void scan(StreamController<BrilliantScannedDevice> listener) async {
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

      if (listener.hasListener) {
        listener.sink.add(
          BrilliantScannedDevice(
            device: nearestDevice.device,
            rssi: nearestDevice.rssi,
          ),
        );
      }
    });

    FlutterBluePlus.cancelWhenScanComplete(scan);

    await _startScan(true);
  }

  static void stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  static void connect(
    BrilliantScannedDevice device,
    StreamController<BrilliantDevice> listener,
  ) {
    _connect(device.device, listener);
  }

  static void reconnect(
    String deviceUuid,
    StreamController<BrilliantDevice> listener,
  ) async {
    print("Will reconnect to: $deviceUuid");

    await _startScan(false);

    StreamSubscription scan = FlutterBluePlus.scanResults.listen((results) {
      for (int i = 0; i < results.length; i++) {
        if (results[i].device.remoteId.toString() == deviceUuid) {
          print("Reconnecting to: ${results[i].device.remoteId.toString()}");
          BrilliantBluetooth.stopScan();
          _connect(results[i].device, listener);
        }
      }
    });

    FlutterBluePlus.cancelWhenScanComplete(scan);
  }

  static void disconnect(BrilliantDevice device) {
    device.device.disconnect();
  }
}
