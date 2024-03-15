import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FrameConnectionEnum { connected, new_connection, dfu_mode }

class FrameBluetooth {
  late String _pairedDeviceUuid;
  late BluetoothService frameService;
  late BluetoothCharacteristic frameRxCharacteristic;
  late BluetoothCharacteristic frameTxCharacteristic;

  int temp_counter = 0;

  FrameBluetooth() {
    FlutterBluePlus.setLogLevel(LogLevel.verbose, color: false);
    _loadPairedDeviceUuid();
  }

  void _loadPairedDeviceUuid() async {
    final preferences = await SharedPreferences.getInstance();
    _pairedDeviceUuid = preferences.getString('pairedDeviceUuid') ?? "";
  }

  void _savePairedDeviceUuid(String uuid) async {
    final preferences = await SharedPreferences.getInstance();
    preferences.setString('pairedDeviceUuid', uuid);
  }

  void deletePairedDevice() async {
    final preferences = await SharedPreferences.getInstance();
    preferences.remove('pairedDeviceUuid');
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

                  ///////
                  String test =
                      "frame.imu.tap_callback(function() print('Oi!') end)";
                  characteristic.write(utf8.encode(test),
                      withoutResponse: true);
                  ///////
                }
                if (characteristic.characteristicUuid ==
                    Guid('7a230003-5475-a6a4-654c-8431f6ad49c4')) {
                  frameRxCharacteristic = characteristic;

                  final subscription =
                      characteristic.onValueReceived.listen((value) {
                    // TODO call callback
                    print(utf8.decode(value));

                    ///////
                    temp_counter++;
                    String test =
                        "frame.display.text($temp_counter, 50, 50); frame.display.show()";
                    frameTxCharacteristic.write(utf8.encode(test),
                        withoutResponse: true);
                    ///////
                  });
                  device.cancelWhenDisconnected(subscription);

                  await characteristic.setNotifyValue(true);
                }
              });
            }
          });

          _savePairedDeviceUuid(device.remoteId.toString());
          if (!completer.isCompleted) {
            completer.complete(device.remoteId.toString());
          }
        }
      });
    });

    // TODO handle errors

    return completer.future;
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
          completer.complete(FrameConnectionEnum.dfu_mode);
        }

        // New connection
        if (_pairedDeviceUuid == "" && results[i].rssi > -55) {
          String uuid = await _connectToFrame(results[i].device);
          _savePairedDeviceUuid(uuid);
          print("Connected to new Frame device");
          completer.complete(FrameConnectionEnum.new_connection);
        }

        // Previous connection
        else if (results[i].device.remoteId.toString() == _pairedDeviceUuid) {
          await _connectToFrame(results[i].device);
          print("Connected to existing Frame device");
          completer.complete(FrameConnectionEnum.connected);
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