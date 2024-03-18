import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FrameConnectionEnum { connected, new_connection, dfu_mode }

FrameBluetooth frameBluetooth = FrameBluetooth();

class FrameBluetooth {
  late BluetoothService frameService;
  late BluetoothCharacteristic frameRxCharacteristic;
  late BluetoothCharacteristic frameTxCharacteristic;

  FrameBluetooth() {
    FlutterBluePlus.setLogLevel(LogLevel.verbose, color: false);
  }

  Future<String?> _loadPairedDevice() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString('pairedDeviceUuid');
  }

  Future<void> _savePairedDevice(String uuid) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('pairedDeviceUuid', uuid);
  }

  Future<void> deletePairedDevice() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('pairedDeviceUuid');
  }

  Future<String> _connectToFrame(BluetoothDevice device) async {
    final Completer<String> completer = Completer<String>();

    FlutterBluePlus.stopScan();

    device
        .connect(
      autoConnect: true,
      timeout: const Duration(seconds: 3),
      mtu: null,
    )
        .then((_) {
      device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.connected) {
          List<BluetoothService> services = await device.discoverServices();
          services.forEach((service) {
            if (service.serviceUuid ==
                Guid('7a230001-5475-a6a4-654c-8431f6ad49c4')) {
              frameService = service;
              service.characteristics.forEach((characteristic) async {
                if (characteristic.characteristicUuid ==
                    Guid('7a230002-5475-a6a4-654c-8431f6ad49c4')) {
                  frameTxCharacteristic = characteristic;
                }
                if (characteristic.characteristicUuid ==
                    Guid('7a230003-5475-a6a4-654c-8431f6ad49c4')) {
                  frameRxCharacteristic = characteristic;

                  final subscription =
                      characteristic.onValueReceived.listen((value) {
                    // TODO call callback
                    print(utf8.decode(value));
                  });
                  device.cancelWhenDisconnected(subscription);

                  await characteristic.setNotifyValue(true);
                }
              });
            }
          });

          _savePairedDevice(device.remoteId.toString());
          if (!completer.isCompleted) {
            completer.complete(device.remoteId.toString());
          }
        }
      });
    });

    // TODO handle errors

    return completer.future;
  }

  Future<bool> isPaired() async {
    if (await _loadPairedDevice() != null) {
      return true;
    }
    return false;
  }

  Future<FrameConnectionEnum> connect(bool firstPairing) async {
    final Completer<FrameConnectionEnum> completer =
        Completer<FrameConnectionEnum>();

    await FlutterBluePlus.startScan(
      withServices: [
        Guid('7a230001-5475-a6a4-654c-8431f6ad49c4'),
        Guid('8ec90001-f315-4f60-9fb8-838830daea50'),
      ],
      continuousUpdates: firstPairing ? true : false,
    );

    FlutterBluePlus.scanResults.listen((results) async {
      for (int i = 0; i < results.length; i++) {
        // If DFU device within close range
        if (results[i].device.advName == "Frame DFU" && results[i].rssi > -55) {
          // TODO
          if (!completer.isCompleted) {
            completer.complete(FrameConnectionEnum.dfu_mode);
          }
        }

        // New connection
        if (await _loadPairedDevice() == null && results[i].rssi > -55) {
          String uuid = await _connectToFrame(results[i].device);
          _savePairedDevice(uuid);
          print("Connected to new Frame device");
          if (!completer.isCompleted) {
            completer.complete(FrameConnectionEnum.new_connection);
          }
        }

        // Previous connection
        else if (results[i].device.remoteId.toString() ==
            await _loadPairedDevice()) {
          await _connectToFrame(results[i].device);
          print("Connected to existing Frame device");
          if (!completer.isCompleted) {
            completer.complete(FrameConnectionEnum.connected);
          }
        }
      }
    });

    return completer.future;
  }
}


/*
String test = "frame.imu.tap_callback(function() print('Oi!') end)";
characteristic.write(utf8.encode(test), withoutResponse: true);
*/  