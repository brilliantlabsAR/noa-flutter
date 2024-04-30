import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logging/logging.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:noa/util/dfu.dart';
import 'package:archive/archive.dart';

final _log = Logger("Bluetooth");

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
  // for dfu
  late BluetoothCharacteristic _dfuControlChannel;
  late BluetoothCharacteristic _dfuPacketChannel;
  late bool? dfuDevice;
  late int _firmwareSize;
  StreamController<double>? firmwareUpdateListener;

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
    this.firmwareUpdateListener,
    this.dfuDevice,
  });

  Future<void> connect(StreamController<BrilliantDevice> listener) async {
    _log.info("Connecting");
    try {
      await device.connect(
        autoConnect: true,
        timeout: const Duration(seconds: 2),
        mtu: null,
      );
    } catch (error) {
      _log.warning("Failed to connect");
      state = BrilliantConnectionState.invalid;
      listener.sink.add(this);
    }

    device.connectionState.listen((connectionState) async {
      switch (connectionState) {
        case BluetoothConnectionState.connected:
          try {
            _log.info("Connected");
            if (Platform.isAndroid) {
              await device.requestMtu(512);
            }
            await _enableServices();
            _log.info("Services enabled");
            state = BrilliantConnectionState.connected;
            maxStringLength = device.mtuNow - 3;
            maxDataLength = device.mtuNow - 4;
          } catch (error) {
            await device.disconnect();
            _log.warning("Failed to enable services");
            state = BrilliantConnectionState.invalid;
          }
          break;
        case BluetoothConnectionState.disconnected:
          _log.info("Disconnected");
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
    _log.info("Disconnecting");
    await device.disconnect();
  }

  Future<void> sendBreakSignal() async {
    _log.info("Sending break signal");
    await sendString("\x03", awaitResponse: false);
    Completer completer = Completer();
    Timer(const Duration(milliseconds: 100), () => completer.complete());
    return completer.future;
  }

  Future<void> sendResetSignal() async {
    _log.info("Sending reset signal");
    await sendString("\x04", awaitResponse: false);
    Completer completer = Completer();
    Timer(const Duration(milliseconds: 100), () => completer.complete());
    return completer.future;
  }

  Future<String?> sendString(String string, {bool awaitResponse = true}) async {
    _log.info("Sending string");
    Completer<String?> completer = Completer();

    if (state != BrilliantConnectionState.connected) {
      _log.warning("Device not connected");
      return Future.error("Device not connected");
    }

    if (string.length > maxStringLength!) {
      _log.warning("Payload exceeds mtu");
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
      _log.warning("Device didn't respond");
      subscription.cancel();
      completer.completeError("Device didn't respond");
    }).listen((value) {
      _log.info("Got response");
      subscription.cancel();
      completer.complete(utf8.decode(value));
    });

    device.cancelWhenDisconnected(subscription);

    return completer.future;
  }

  Future<void> sendData(List<int> data) async {
    _log.info("Sending data");

    if (state != BrilliantConnectionState.connected) {
      _log.warning("Device not connected");
      return Future.error("Device not connected");
    }

    if (data.length > maxDataLength!) {
      _log.warning("Payload exceeds mtu");
      return Future.error("Payload exceeds allowed length of $maxDataLength");
    }

    var finalData = data.toList();
    finalData.insert(0, 0x01);

    await _txChannel.write(finalData, withoutResponse: true);
  }
Future<ByteData?> nordicSendControl(List<int> bytes) async {
    _log.info("brilliantDevice._nordicSendControl()");

    if (state != BrilliantConnectionState.connected) {
      _log.warning("brilliantDevice._nordicSendControl() device not connected");
      return Future.error("Device not connected");
    }
    var dfuCompleter = Completer<ByteData>();

    late StreamSubscription nordicSubscription;
    nordicSubscription = _dfuControlChannel.onValueReceived.listen((value) {
      nordicSubscription.cancel();
      _log.info("brilliantDevice._nordicSendControl() value: $value");
      var byteValue = ByteData.view(Uint8List.fromList(value).buffer);
      dfuCompleter.complete(byteValue);
    });
    await _dfuControlChannel.write(bytes, withoutResponse: false);
    device.cancelWhenDisconnected(nordicSubscription);
    return dfuCompleter.future;
  }

  Future<void> nordicSendData(List<int> bytes) async {
    // _log.info("brilliantDevice._nordicSendData()");

    if (state != BrilliantConnectionState.connected) {
      _log.warning("brilliantDevice._nordicSendData() device not connected");
      return Future.error("Device not connected");
    }
    await _dfuPacketChannel.write(bytes, withoutResponse: true);
    // add small delay
    await Future.delayed(const Duration(milliseconds: 10));
  }

  Future<void> updateFirmware({String filePath = ""}) async {
    _log.info("brilliantDevice.updateFirmware()");

    if (state != BrilliantConnectionState.connected) {
      _log.warning("brilliantDevice.updateFirmware() device not connected");
      return Future.error("Device not connected");
    }
    var firmware = await Firmware.getFirmware(zipPath: filePath);
    if (firmware.binData.isEmpty || firmware.datData.isEmpty) {
      return Future.error('Firmware file not found');
    }
    _firmwareSize = firmware.binData.length;
    _log.info("brilliantDevice.updateFirmware() firmwareSize: $_firmwareSize");
    // first transfer init packet
    await transferFirmwareFile(firmware.datData, 'init');
    // then transfer image packet
    await transferFirmwareFile(firmware.binData, 'image');
  }

  Future<void> transferFirmwareFile(Uint8List data, String type) async {
    ByteData? response;
    switch (type) {
      case 'init':
        _log.info(
            "brilliantDevice.transferFirmwareFile() Transferring init file");
        response = await nordicSendControl([0x06, 0x01]);
        break;
      case 'image':
        _log.info(
            "brilliantDevice.transferFirmwareFile() Transferring image file");
        response = await nordicSendControl([0x06, 0x02]);
        break;
      default:
        return Future.error('Invalid file type');
    }
    final fileSize = data.length;
    _log.info("brilliantDevice.transferFirmwareFile() fileSize: $fileSize");

    final maxSize = response!.getUint32(3, Endian.little);
    final offset = response.getUint32(7, Endian.little);
    final crc = response.getUint32(11, Endian.little);
    _log.info(
        "brilliantDevice.transferFirmwareFile() maxSize: $maxSize, offset: $offset, crc: $crc");
    final chunks = (fileSize / maxSize).ceil();
    _log.info(
        "brilliantDevice.transferFirmwareFile() Sending file as $chunks chunks");
    var fileOffset = 0;
    // in while loop, send chunks of data
    while (fileOffset < fileSize) {
      var chunkSize = min(maxSize, fileSize - fileOffset);
      final chunkCrc = getCrc32(data.sublist(0, fileOffset + chunkSize));
      _log.info(
          "brilliantDevice.transferFirmwareFile() chunk $fileOffset, fileOffset: $fileOffset, chunkSize: $chunkSize, chunkCrc: $chunkCrc");
      final chunkSizeAsBytes = [
        chunkSize & 0xFF,
        (chunkSize >> 8) & 0xFF,
        (chunkSize >> 16) & 0xff,
        (chunkSize >> 24) & 0xff
      ];
      if (type == 'init') {
        await nordicSendControl([0x01, 0x01, ...chunkSizeAsBytes]);
      }
      if (type == 'image') {
        await nordicSendControl([0x01, 0x02, ...chunkSizeAsBytes]);
      }
      var packetSize = maxDataLength ?? 150;
      final packets = (chunkSize / packetSize).ceil();
      for (var pkt = 0; pkt < packets; pkt++) {
        var packetLength = packetSize;
        if (pkt == packets - 1 && chunkSize % packetSize != 0) {
          packetLength = chunkSize % packetSize;
        }
        final fileSlice = data.sublist(fileOffset, fileOffset + packetLength);
        fileOffset += fileSlice.length;
        await nordicSendData(fileSlice);
        // _log.info(
        //     "brilliantDevice.transferFirmwareFile() packet $pkt, packetLength: $packetLength");
      }
      response = await nordicSendControl([0x03]);
      final returnedOffset = response!.getUint32(3, Endian.little);
      final returnedCrc = response.getUint32(7, Endian.little);
      _log.info(
          "brilliantDevice.transferFirmwareFile() returnedOffset: $returnedOffset, returnedCrc: $returnedCrc, expectedCrc: $chunkCrc");
      if (returnedCrc != chunkCrc) {
        // repeat the chunk
        fileOffset -= chunkSize;
        _log.info('CRC mismatch after sending this chunk. Expected: $chunkCrc');
        // return Future.error('CRC mismatch after sending this chunk');
      } else {
        if (type == 'image') {
          firmwareUpdateListener
              ?.add(((fileOffset / _firmwareSize) * 100).roundToDouble());
        }
        response = await nordicSendControl([0x04]);
        // final status = response!.getUint32(3, Endian.little);
        // _log.info("brilliantDevice.transferFirmwareFile() status: $status");
      }
    }
  }
  Future<void> uploadScript(String fileName, String filePath) async {
    _log.info("Uploading $fileName");

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
          _log.fine("Found Frame service");
          for (var characteristic in service.characteristics) {
            if (characteristic.characteristicUuid ==
                Guid('7a230002-5475-a6a4-654c-8431f6ad49c4')) {
              _log.fine("Found Frame TX characteristic");
              _txChannel = characteristic;
            }
            if (characteristic.characteristicUuid ==
                Guid('7a230003-5475-a6a4-654c-8431f6ad49c4')) {
              _log.fine("Found Frame RX characteristic");
              _rxChannel = characteristic;

              StreamSubscription subscription =
                  _rxChannel.onValueReceived.listen((data) {
                if (data[0] == 0x01) {
                  _log.finer("Received data: ${data.sublist(1)}");
                  dataRxListener?.add(data.sublist(1));
                } else {
                  _log.finer("Received string: ${utf8.decode(data)}");
                  stringRxListener?.add(utf8.decode(data));
                }
              });

              device.cancelWhenDisconnected(subscription);

              await characteristic.setNotifyValue(true);
              _log.fine("Enabled RX notification");
            }
          }
        }
         if (service.serviceUuid == Guid('fe59')) {
          dfuDevice = true;
          _log.fine("brilliantDevice.connect() found DFU service");
          for (var characteristic in service.characteristics) {
            if (characteristic.characteristicUuid ==
                Guid('8ec90001-f315-4f60-9fb8-838830daea50')) {
              _log.fine(
                  "brilliantDevice.connect() found DFU Control characteristic");
              _dfuControlChannel = characteristic;
              await characteristic.setNotifyValue(true);
              _log.fine(
                  "brilliantDevice.connect() enabled nordic notification");
            }
            if (characteristic.characteristicUuid ==
                Guid('8ec90002-f315-4f60-9fb8-838830daea50')) {
              _log.fine(
                  "brilliantDevice.connect() found DFU Packet characteristic");
              _dfuPacketChannel = characteristic;
            }
          }
        }
      }
    } catch (error) {
      _log.warning("$error");
      return Future.error(error);
    }
  }
}

class BrilliantBluetooth {
  static Future<void> requestPermission() async {
    await FlutterBluePlus.startScan();
    await FlutterBluePlus.stopScan();
  }

  static Future<void> scan(StreamController<BrilliantDevice> listener) async {
    if (FlutterBluePlus.isScanningNow) {
      _log.info("Already scanning");
      return;
    }

    _log.info("Scanning");
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
          "Found ${nearestDevice.device.advName} - uuid: ${nearestDevice.device.remoteId.toString()} rssi: ${nearestDevice.rssi}");

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

    await _startScan();
  }

  static Future<void> stopScan() async {
    _log.info("Stopping scan");
    await FlutterBluePlus.stopScan();
  }

  static Future<void> reconnect(
    String deviceUuid,
    StreamController<BrilliantDevice> listener,
  ) async {
    _log.info("Will reconnect to: $deviceUuid");

    StreamSubscription scan = FlutterBluePlus.scanResults.listen((results) {
      for (int i = 0; i < results.length; i++) {
        if (results[i].device.remoteId.toString() == deviceUuid) {
          _log.info("Found re-connectable device: $deviceUuid");
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

    await _startScan();
  }

  static Future<void> _startScan() async {
    await FlutterBluePlus.startScan(
      withServices: [
        Guid('7a230001-5475-a6a4-654c-8431f6ad49c4'),
        Guid('fe59'),
      ],
      continuousUpdates: true,
      removeIfGone: const Duration(seconds: 2),
    );
  }
}
