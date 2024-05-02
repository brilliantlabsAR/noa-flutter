import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

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
  dfuConnected,
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
  StreamController<double>? fileUploadProgressListener;

  BluetoothCharacteristic? _txChannel;
  BluetoothCharacteristic? _rxChannel;
  BluetoothCharacteristic? _dfuControl;
  BluetoothCharacteristic? _dfuPacket;

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
    this.fileUploadProgressListener,
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

    StreamSubscription stream =
        device.connectionState.listen((connectionState) async {
      switch (connectionState) {
        case BluetoothConnectionState.connected:
          try {
            _log.info("Connected");
            if (Platform.isAndroid) {
              await device.requestMtu(512);
            }
            await _enableServices();
            if (_dfuControl != null && _dfuPacket != null) {
              state = BrilliantConnectionState.dfuConnected;
            } else if (_txChannel != null && _rxChannel != null) {
              state = BrilliantConnectionState.connected;
              maxStringLength = device.mtuNow - 3;
              maxDataLength = device.mtuNow - 4;
            } else {
              throw "Found an incomplete set of characteristics";
            }
          } catch (error) {
            await device.disconnect();
            _log.warning("Failed to enable services. $error");
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

    device.cancelWhenDisconnected(stream, next: true, delayed: true);
  }

  Future<void> _enableServices() async {
    List<BluetoothService> services = await device.discoverServices();

    for (var service in services) {
      // If Frame
      if (service.serviceUuid == Guid('7a230001-5475-a6a4-654c-8431f6ad49c4')) {
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

            StreamSubscription stream =
                _rxChannel!.onValueReceived.listen((data) {
              if (data[0] == 0x01) {
                _log.finer("Received data: ${data.sublist(1)}");
                dataRxListener?.add(data.sublist(1));
              } else {
                _log.finer("Received string: ${utf8.decode(data)}");
                stringRxListener?.add(utf8.decode(data));
              }
            });

            device.cancelWhenDisconnected(stream);

            await characteristic.setNotifyValue(true);
            _log.fine("Enabled RX notifications");
          }
        }
      }

      // If DFU
      if (service.serviceUuid == Guid('fe59')) {
        _log.fine("Found DFU service");
        for (var characteristic in service.characteristics) {
          if (characteristic.characteristicUuid ==
              Guid('8ec90001-f315-4f60-9fb8-838830daea50')) {
            _log.fine("Found DFU control characteristic");
            _dfuControl = characteristic;
            await characteristic.setNotifyValue(true);
            _log.fine("Enabled DFU control notifications");
          }
          if (characteristic.characteristicUuid ==
              Guid('8ec90002-f315-4f60-9fb8-838830daea50')) {
            _log.fine("Found DFU packet characteristic");
            _dfuPacket = characteristic;
          }
        }
      }
    }

    _log.info("Services enabled");
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
    _log.info("Sending ${string.length} bytes of string data");
    Completer<String?> completer = Completer();

    if (state != BrilliantConnectionState.connected) {
      _log.warning("Device is not connected");
      return Future.error("Device is not connected");
    }

    if (string.length > maxStringLength!) {
      _log.warning("Payload exceeds allowed length of $maxStringLength");
      return Future.error("Payload exceeds allowed length of $maxStringLength");
    }

    await _txChannel!.write(utf8.encode(string), withoutResponse: true);

    if (awaitResponse == false) {
      completer.complete();
      return completer.future;
    }

    late StreamSubscription stream;

    stream = _rxChannel!.onValueReceived.timeout(const Duration(seconds: 3),
        onTimeout: (_) {
      _log.warning("Device didn't respond");
      stream.cancel();
      completer.completeError("Device didn't respond");
    }).listen((value) {
      _log.info("Got response");
      stream.cancel();
      completer.complete(utf8.decode(value));
    });

    device.cancelWhenDisconnected(stream);

    return completer.future;
  }

  Future<void> sendData(List<int> data) async {
    _log.info("Sending ${data.length} bytes of plain data");

    if (state != BrilliantConnectionState.connected) {
      _log.warning("Device is not connected");
      return Future.error("Device is not connected");
    }

    if (data.length > maxDataLength!) {
      _log.warning("Payload exceeds allowed length of $maxDataLength");
      return Future.error("Payload exceeds allowed length of $maxDataLength");
    }

    var finalData = data.toList();
    finalData.insert(0, 0x01);

    await _txChannel!.write(finalData, withoutResponse: true);
  }

  Future<void> uploadScript(String fileName, String filePath) async {
    _log.info("Uploading script: $fileName");

    String file = await rootBundle.loadString(filePath);

    file = file.replaceAll('\\', '\\\\');
    file = file.replaceAll("\n", "\\n");
    file = file.replaceAll("'", "\\'");
    file = file.replaceAll('"', '\\"');

    var resp =
        await sendString("f=frame.file.open('$fileName', 'w');print(nil)");

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

      resp = await sendString("f:write('$chunk');print(nil)");

      if (resp != "nil") {
        return Future.error("$resp");
      }

      index += chunkSize;
    }

    resp = await sendString("f:close();print('nil')");

    if (resp != "nil") {
      return Future.error("$resp");
    }

    // TODO report back to fileUploadProgressListener?.add(percentDone);
  }

  // Stream<double> updateFirmware(String filePath) async* {
  //   _log.info("Starting firmware update");

  //   yield 0.0;

  //   if (state != BrilliantConnectionState.dfuConnected) {
  //     _log.warning("DFU device is not connected");
  //     yield* Stream.error("DFU device is not connected");
  //   }

  //   if (_dfuControl == null || _dfuPacket == null) {
  //     _log.warning("Device is not in DFU mode");
  //     yield* Stream.error("Device is not in DFU mode");
  //   }

  //   final updateZipFile = await rootBundle.load(filePath);
  //   final zip = ZipDecoder().decodeBytes(updateZipFile.buffer.asUint8List());

  //   final initFile = zip.firstWhere((file) => file.name.endsWith(".dat"));
  //   final imageFile = zip.firstWhere((file) => file.name.endsWith(".bin"));

  //   await _transferDfuFile(initFile.content, true);
  //   await _transferDfuFile(imageFile.content, false);
  // }

  Future<void> updateFirmware(String filePath) async {
    _log.info("Starting firmware update");

    if (state != BrilliantConnectionState.dfuConnected) {
      _log.warning("DFU device is not connected");
      Future.error("DFU device is not connected");
    }

    if (_dfuControl == null || _dfuPacket == null) {
      _log.warning("Device is not in DFU mode");
      Future.error("Device is not in DFU mode");
    }

    final updateZipFile = await rootBundle.load(filePath);
    final zip = ZipDecoder().decodeBytes(updateZipFile.buffer.asUint8List());

    final initFile = zip.firstWhere((file) => file.name.endsWith(".dat"));
    final imageFile = zip.firstWhere((file) => file.name.endsWith(".bin"));

    await _transferDfuFile(initFile.content, true);
    await _transferDfuFile(imageFile.content, false);
  }

  Future<void> _transferDfuFile(Uint8List file, bool isInitFile) async {
    Uint8List response;
    if (isInitFile) {
      _log.info("Uploading DFU init file. Size: ${file.length}");
      response = await _dfuSendControlData(Uint8List.fromList([0x06, 0x01]));
    } else {
      _log.info("Uploading DFU image file. Size: ${file.length}");
      response = await _dfuSendControlData(Uint8List.fromList([0x06, 0x02]));
    }

    final maxSize = ByteData.view(response.buffer).getUint32(3, Endian.little);
    final offset = ByteData.view(response.buffer).getUint32(7, Endian.little);
    final crc = ByteData.view(response.buffer).getUint32(11, Endian.little);
    final chunks = (file.length / maxSize).ceil();

    _log.fine("Received allowed size: $maxSize, offset: $offset, CRC: $crc");

    int fileOffset = 0;
    for (var i = 0; i < chunks; i++) {
      var chunkSize = min(file.length, maxSize);

      // The last chunk could be smaller
      if (i == chunks - 1 && (file.length % maxSize != 0)) {
        chunkSize = file.length % maxSize;
      }

      final chunkCrc = getCrc32(file.sublist(0, fileOffset + chunkSize));

      // Create command with size
      final chunkSizeAsBytes = [
        chunkSize & 0xFF,
        chunkSize >> 8 & 0xFF,
        chunkSize >> 16 & 0xff,
        chunkSize >> 24 & 0xff
      ];

      if (isInitFile) {
        await _dfuSendControlData(
            Uint8List.fromList([0x01, 0x01, ...chunkSizeAsBytes]));
      } else {
        await _dfuSendControlData(
            Uint8List.fromList([0x01, 0x02, ...chunkSizeAsBytes]));
      }

      // Send packets in chunks of MTU size
      final packets = (chunkSize / (device.mtuNow - 3)).ceil();
      for (var i = 0; i < packets; i++) {
        // The last packet could be smaller
        var packetLength = device.mtuNow - 3;
        if (i == packets - 1 && chunkSize % (device.mtuNow - 3) != 0) {
          packetLength = chunkSize % (device.mtuNow - 3);
        }

        final fileSlice = file.sublist(fileOffset, fileOffset + packetLength);
        fileOffset += fileSlice.length;
        final percentDone = (100 / file.length) * fileOffset;
        fileUploadProgressListener?.add(percentDone);

        _log.fine(
            "Sending ${fileSlice.length} bytes of packet data. ${percentDone.toInt()}% Complete");

        await _dfuSendPacketData(fileSlice);
      }

      // Calculate CRC
      response = await _dfuSendControlData(Uint8List.fromList([0x03]));
      final returnedCrc =
          ByteData.view(response.buffer).getUint32(7, Endian.little);

      if (returnedCrc != chunkCrc) {
        _log.warning("CRC mismatch after sending this chunk");
        return Future.error("CRC mismatch after sending this chunk");
      }

      // Execute command (The last command may disconnect which is normal)
      try {
        await _dfuSendControlData(Uint8List.fromList([0x04]));
      } catch (_) {}
    }

    _log.info("DFU file sent");
  }

  Future<Uint8List> _dfuSendControlData(Uint8List data) async {
    _log.fine("Sending ${data.length} bytes of DFU control data: $data");
    Completer<Uint8List> completer = Completer();

    try {
      await _dfuControl!.write(data, timeout: 3);
    } catch (error) {
      _log.warning("Error writing DFU control data: $error");
      completer.completeError("Error writing DFU control data: $error");
    }

    late StreamSubscription stream;

    stream = _dfuControl!.onValueReceived.timeout(const Duration(seconds: 3),
        onTimeout: (_) {
      _log.warning("Device didn't respond");
      stream.cancel();
      completer.completeError("Device didn't respond");
    }).listen((value) {
      stream.cancel();
      completer.complete(Uint8List.fromList(value));
    });

    device.cancelWhenDisconnected(stream);

    return completer.future;
  }

  Future<void> _dfuSendPacketData(Uint8List data) async {
    await _dfuPacket!.write(data, withoutResponse: true);
  }
}

class BrilliantBluetooth {
  static Future<void> requestPermission() async {
    await FlutterBluePlus.startScan();
    await FlutterBluePlus.stopScan();
  }

  static Future<void> scan(StreamController<BrilliantDevice> listener) async {
    if (FlutterBluePlus.isScanningNow) {
      _log.info("Already scanning for devices");
      return;
    }

    late ScanResult nearestDevice;

    StreamSubscription stream = FlutterBluePlus.onScanResults.listen((results) {
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

    FlutterBluePlus.cancelWhenScanComplete(stream);

    await _startScan();
  }

  static Future<void> stopScan() async {
    _log.info("Stopping scan for devices");
    await FlutterBluePlus.stopScan();
  }

  static Future<void> reconnect(
    String deviceUuid,
    StreamController<BrilliantDevice> listener,
  ) async {
    _log.info("Will automatically connect to device $deviceUuid once found");

    StreamSubscription stream = FlutterBluePlus.scanResults.listen((results) {
      for (int i = 0; i < results.length; i++) {
        if (results[i].device.remoteId.toString() == deviceUuid) {
          _log.info("Found expected device. Connecting to: $deviceUuid");
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

    FlutterBluePlus.cancelWhenScanComplete(stream);

    await _startScan();
  }

  static Future<void> _startScan() async {
    _log.info("Starting to scan for devices");
    await FlutterBluePlus.startScan(
      withServices: [
        Guid('7a230001-5475-a6a4-654c-8431f6ad49c4'),
        Guid('fe59'),
      ],
      withNames: ["Frame", "Frame Update"],
      continuousUpdates: true,
      removeIfGone: const Duration(seconds: 2),
    );
  }
}
