import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logging/logging.dart';

final _log = Logger("Brilliant Bluetooth");

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
  int? maxStringLength;
  int? maxDataLength;
  StreamController<String>? stringRxListener;
  StreamController<List<int>>? dataRxListener;

  late BluetoothCharacteristic _txChannel;
  late BluetoothCharacteristic _rxChannel;

  BrilliantDevice({
    required this.name,
    required this.state,
    required this.device,
    required this.uuid,
    this.rssi,
    this.maxStringLength,
    this.maxDataLength,
    this.stringRxListener,
    this.dataRxListener,
  });

  void connect(StreamController<BrilliantDevice> listener) async {
    _log.info("brilliantDevice.connect() connecting");
    try {
      await device.connect(
        autoConnect: true,
        timeout: const Duration(seconds: 2),
        mtu: null,
      );
    } catch (error) {
      _log.warning("brilliantDevice.connect() failed to connect");
      state = BrilliantConnectionState.invalid;
      listener.sink.add(this);
    }

    device.connectionState.listen((connectionState) async {
      switch (connectionState) {
        case BluetoothConnectionState.connected:
          try {
            _log.info("brilliantDevice.connect() connected");
            await _enableServices();
            _log.info("brilliantDevice.connect() services enabled");
            state = BrilliantConnectionState.connected;
            maxStringLength = device.mtuNow - 3;
            maxDataLength = device.mtuNow - 4;
          } catch (error) {
            await device.disconnect();
            _log.warning("brilliantDevice.connect() failed to enable services");
            state = BrilliantConnectionState.invalid;
          }
          break;
        case BluetoothConnectionState.disconnected:
          _log.info("brilliantDevice.connect() disconnected");
          // TODO differentiate as invalid when "Device has disconnected from us" error occurs
          state = BrilliantConnectionState.disconnected;
          break;
        default:
          break;
      }

      listener.sink.add(this);
    });
  }

  Future<void> disconnect() async {
    _log.info("brilliantDevice.disconnect() disconnecting");
    await device.disconnect();
  }

  Future<void> sendBreakSignal() async {
    _log.info("brilliantDevice.sendBreakSignal()");
    await sendString("\x03", awaitResponse: false);
    Completer completer = Completer();
    Timer(const Duration(milliseconds: 100), () => completer.complete());
    return completer.future;
  }

  Future<void> sendResetSignal() async {
    _log.info("brilliantDevice.sendResetSignal()");
    await sendString("\x04", awaitResponse: false);
    Completer completer = Completer();
    Timer(const Duration(milliseconds: 100), () => completer.complete());
    return completer.future;
  }

  Future<String?> sendString(String string, {bool awaitResponse = true}) async {
    _log.info("brilliantDevice.sendString()");
    Completer<String?> completer = Completer();

    if (state != BrilliantConnectionState.connected) {
      _log.warning("brilliantDevice.sendString() device not connected");
      return Future.error("Device not connected");
    }

    if (string.length > maxStringLength!) {
      _log.warning("brilliantDevice.sendString() payload exceeds mtu");
      return Future.error("Payload exceeds allowed length of $maxStringLength");
    }

    await _txChannel.write(utf8.encode(string), withoutResponse: true);

    if (awaitResponse == false) {
      completer.complete();
      return completer.future;
    }

    late StreamSubscription subscription;

    subscription = _rxChannel.onValueReceived
        .timeout(const Duration(seconds: 3), onTimeout: (_) {
      _log.warning("brilliantDevice.writeString() device didn't respond");
      subscription.cancel();
      completer.completeError("Device didn't respond");
    }).listen((value) {
      _log.info("brilliantDevice.writeString() got response");
      subscription.cancel();
      completer.complete(utf8.decode(value));
    });

    device.cancelWhenDisconnected(subscription);

    return completer.future;
  }

  Future<void> sendData(List<int> data) async {
    _log.info("brilliantDevice.sendData()");

    if (state != BrilliantConnectionState.connected) {
      _log.warning("brilliantDevice.sendData() device not connected");
      return Future.error("Device not connected");
    }

    if (data.length > maxDataLength!) {
      _log.warning("brilliantDevice.sendData() payload exceeds mtu");
      return Future.error("Payload exceeds allowed length of $maxDataLength");
    }

    var finalData = data.toList();
    finalData.insert(0, 0x01);

    await _txChannel.write(finalData, withoutResponse: true);
  }

  Future<void> uploadScript(String fileName, String filePath) async {
    _log.info("brilliantDevice.uploadScript('$fileName')");

    String file = await rootBundle.loadString(filePath);

    file = file.replaceAll('\\', '\\\\');
    file = file.replaceAll("\n", "\\n");
    file = file.replaceAll("'", "\\'");
    file = file.replaceAll('"', '\\"');

    var resp =
        await sendString("f=frame.file.open('$fileName', 'w');print(nil)")
            .onError((error, _) => Future.error("$error"));

    if (resp != "nil") {
      return Future.error("$resp");
    }

    int index = 0;
    int chunkSize = maxStringLength! - 22;

    while (index < file.length) {
      // Don't go over the end of the string
      if (index + chunkSize > file.length) {
        chunkSize = file.length - index;
      }

      // Don't split on an escape character
      if (file[index + chunkSize - 1] == '\\') {
        chunkSize -= 1;
      }

      String chunk = file.substring(index, index + chunkSize);

      resp = await sendString("f:write('$chunk');print(nil)")
          .onError((error, _) => Future.error("$error"));

      if (resp != "nil") {
        return Future.error("$resp");
      }

      index += chunkSize;
    }

    resp = await sendString("f:close();print('nil')")
        .onError((error, _) => Future.error("$error"));

    if (resp != "nil") {
      return Future.error("$resp");
    }
  }

  Future<void> _enableServices() async {
    try {
      List<BluetoothService> services = await device.discoverServices();

      for (var service in services) {
        // TODO If Monocle
        // If Frame
        if (service.serviceUuid ==
            Guid('7a230001-5475-a6a4-654c-8431f6ad49c4')) {
          _log.fine("brilliantDevice.connect() found Frame service");
          for (var characteristic in service.characteristics) {
            if (characteristic.characteristicUuid ==
                Guid('7a230002-5475-a6a4-654c-8431f6ad49c4')) {
              _log.fine(
                  "brilliantDevice.connect() found Frame TX characteristic");
              _txChannel = characteristic;
            }
            if (characteristic.characteristicUuid ==
                Guid('7a230003-5475-a6a4-654c-8431f6ad49c4')) {
              _log.fine(
                  "brilliantDevice.connect() found Frame RX characteristic");
              _rxChannel = characteristic;

              StreamSubscription subscription =
                  _rxChannel.onValueReceived.listen((data) {
                if (data[0] == 0x01) {
                  _log.finer(
                      "brilliantDevice received data: ${data.sublist(1)}");
                  dataRxListener?.add(data.sublist(1));
                } else {
                  _log.finer(
                      "brilliantDevice received string: ${utf8.decode(data)}");
                  stringRxListener?.add(utf8.decode(data));
                }
              });

              device.cancelWhenDisconnected(subscription);

              await characteristic.setNotifyValue(true);
              _log.fine("brilliantDevice.connect() enabled RX notification");
            }
          }
        }
        // TODO If DFU
      }
    } catch (error) {
      _log.warning("brilliantDevice.connect() $error");
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
    if (FlutterBluePlus.isScanningNow) {
      _log.info("BrilliantDevice.scan() already scanning");
      return;
    }

    _log.info("BrilliantDevice.scan() scanning");
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

      _log.fine(
          "BrilliantDevice.scan() found ${nearestDevice.device.advName} - uuid: ${nearestDevice.device.remoteId.toString()} rssi: ${nearestDevice.rssi}");

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
    _log.info("BrilliantDevice.stopScan() stopping scan");
    await FlutterBluePlus.stopScan();
  }

  static void reconnect(
    String deviceUuid,
    StreamController<BrilliantDevice> listener,
  ) async {
    _log.info("BrilliantDevice.reconnect() will reconnect to $deviceUuid");

    StreamSubscription scan = FlutterBluePlus.scanResults.listen((results) {
      for (int i = 0; i < results.length; i++) {
        if (results[i].device.remoteId.toString() == deviceUuid) {
          _log.info("BrilliantDevice.reconnect() found $deviceUuid");
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
    if(Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
    }
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
