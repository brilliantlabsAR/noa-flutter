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

class BrilliantBluetoothException implements Exception {
  final String msg;
  const BrilliantBluetoothException(this.msg);
  @override
  String toString() => 'BrilliantBluetoothException: $msg';
}

enum BrilliantConnectionState {
  connected,
  dfuConnected,
  disconnected,
}

class BrilliantScannedDevice {
  BluetoothDevice device;
  int? rssi;

  BrilliantScannedDevice({
    required this.device,
    required this.rssi,
  });
}

class BrilliantDevice {
  BluetoothDevice device;
  BrilliantConnectionState state;
  int? maxStringLength;
  int? maxDataLength;

  BluetoothCharacteristic? _txChannel;
  BluetoothCharacteristic? _rxChannel;
  BluetoothCharacteristic? _dfuControl;
  BluetoothCharacteristic? _dfuPacket;

  BrilliantDevice({
    required this.state,
    required this.device,
    this.maxStringLength,
    this.maxDataLength,
  });

  Stream<BrilliantDevice> get connectionState {
    return FlutterBluePlus.events.onConnectionStateChanged
        .where((event) =>
            event.connectionState == BluetoothConnectionState.connected ||
            (event.connectionState == BluetoothConnectionState.disconnected &&
                event.device.disconnectReason != null &&
                event.device.disconnectReason!.code != 23789258))
        .asyncMap((event) async {
      if (event.connectionState == BluetoothConnectionState.connected) {
        _log.info("Connection state stream: Connected");
        try {
          return await BrilliantBluetooth._enableServices(event.device);
        } catch (error) {
          _log.warning("Connection state stream: Invalid due to $error");
          return Future.error(BrilliantBluetoothException(error.toString()));
        }
      }
      _log.info(
          "Connection state stream: Disconnected due to ${event.device.disconnectReason!.description}");
      if (Platform.isAndroid) {
        event.device.connect(timeout: const Duration(days: 365));
      }
      return BrilliantDevice(
        state: BrilliantConnectionState.disconnected,
        device: event.device,
      );
    });
  }

  Stream<String> get stringResponse {
    return FlutterBluePlus.events.onCharacteristicReceived
        .where((event) => event.value[0] != 0x01)
        .map((event) {
      if (event.value[0] != 0x02) {
        _log.info("Received string: ${utf8.decode(event.value)}");
      }
      return utf8.decode(event.value);
    });
  }

  Stream<List<int>> get dataResponse {
    return FlutterBluePlus.events.onCharacteristicReceived
        .where((event) => event.value[0] == 0x01)
        .map((event) {
      _log.fine("Received data: ${event.value.sublist(1)}");
      return event.value.sublist(1);
    });
  }

  Future<void> disconnect() async {
    _log.info("Disconnecting");
    try {
      await device.disconnect();
    } catch (_) {}
  }

  Future<void> sendBreakSignal() async {
    _log.info("Sending break signal");
    await sendString("\x03", awaitResponse: false, log: false);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> sendResetSignal() async {
    _log.info("Sending reset signal");
    await sendString("\x04", awaitResponse: false, log: false);
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<String?> sendString(
    String string, {
    bool awaitResponse = true,
    bool log = true,
  }) async {
    try {
      if (log) {
        _log.info("Sending string: $string");
      }

      if (state != BrilliantConnectionState.connected) {
        throw ("Device is not connected");
      }

      if (string.length > maxStringLength!) {
        throw ("Payload exceeds allowed length of $maxStringLength");
      }

      await _txChannel!.write(utf8.encode(string), withoutResponse: true);

      if (awaitResponse == false) {
        return null;
      }

      final response = await _rxChannel!.onValueReceived
          .timeout(const Duration(seconds: 1))
          .first;

      return utf8.decode(response);
    } catch (error) {
      _log.warning("Couldn't send string. $error");
      return Future.error(BrilliantBluetoothException(error.toString()));
    }
  }

  Future<void> sendData(List<int> data) async {
    try {
      _log.info("Sending ${data.length} bytes of plain data");
      _log.fine(data);

      if (state != BrilliantConnectionState.connected) {
        throw ("Device is not connected");
      }

      if (data.length > maxDataLength!) {
        throw ("Payload exceeds allowed length of $maxDataLength");
      }

      var finalData = data.toList()..insert(0, 0x01);

      await _txChannel!.write(finalData, withoutResponse: true);
    } catch (error) {
      _log.warning("Couldn't send data. $error");
      return Future.error(BrilliantBluetoothException(error.toString()));
    }
  }

  Future<void> uploadScript(String fileName, String filePath) async {
    try {
      _log.info("Uploading script: $fileName");

      String file = await rootBundle.loadString(filePath);

      file = file.replaceAll('\\', '\\\\');
      file = file.replaceAll("\r\n", "\\n");
      file = file.replaceAll("\n", "\\n");
      file = file.replaceAll("'", "\\'");
      file = file.replaceAll('"', '\\"');

      var resp = await sendString(
          "f=frame.file.open('$fileName', 'w');print('\x02')",
          log: false);

      if (resp != "\x02") {
        throw ("Error opening file: $resp");
      }

      int index = 0;
      int chunkSize = maxStringLength! - 22;

      while (index < file.length) {
        // Don't go over the end of the string
        if (index + chunkSize > file.length) {
          chunkSize = file.length - index;
        }

        // Don't split on an escape character
        while (file[index + chunkSize - 1] == '\\') {
          chunkSize -= 1;
        }

        String chunk = file.substring(index, index + chunkSize);

        resp = await sendString("f:write('$chunk');print('\x02')", log: false);

        if (resp != "\x02") {
          throw ("Error writing file: $resp");
        }

        index += chunkSize;
      }

      resp = await sendString("f:close();print('\x02')", log: false);

      if (resp != "\x02") {
        throw ("Error closing file: $resp");
      }
    } catch (error) {
      _log.warning("Couldn't upload script. $error");
      return Future.error(BrilliantBluetoothException(error.toString()));
    }
  }

  Stream<double> updateFirmware(String filePath) async* {
    try {
      yield 0;

      _log.info("Starting firmware update");

      if (state != BrilliantConnectionState.dfuConnected) {
        throw ("DFU device is not connected");
      }

      if (_dfuControl == null || _dfuPacket == null) {
        throw ("Device is not in DFU mode");
      }

      final updateZipFile = await rootBundle.load(filePath);
      final zip = ZipDecoder().decodeBytes(updateZipFile.buffer.asUint8List());

      final initFile = zip.firstWhere((file) => file.name.endsWith(".dat"));
      final imageFile = zip.firstWhere((file) => file.name.endsWith(".bin"));

      await for (var _ in _transferDfuFile(initFile.content, true)) {}
      await Future.delayed(const Duration(milliseconds: 500));
      await for (var value in _transferDfuFile(imageFile.content, false)) {
        yield value;
      }

      _log.info("Firmware update completed");
    } catch (error) {
      _log.warning("Couldn't complete firmware update. $error");
      yield* Stream.error(BrilliantBluetoothException(error.toString()));
    }
  }

  Stream<double> _transferDfuFile(Uint8List file, bool isInitFile) async* {
    Uint8List response;

    try {
      if (isInitFile) {
        _log.fine("Uploading DFU init file. Size: ${file.length}");
        response = await _dfuSendControlData(Uint8List.fromList([0x06, 0x01]));
      } else {
        _log.fine("Uploading DFU image file. Size: ${file.length}");
        response = await _dfuSendControlData(Uint8List.fromList([0x06, 0x02]));
      }
    } catch (_) {
      throw ("Couldn't create DFU file on device");
    }

    final maxSize = ByteData.view(response.buffer).getUint32(3, Endian.little);
    var offset = ByteData.view(response.buffer).getUint32(7, Endian.little);
    final crc = ByteData.view(response.buffer).getUint32(11, Endian.little);

    _log.fine("Received allowed size: $maxSize, offset: $offset, CRC: $crc");

    while (offset < file.length) {
      final chunkSize = min(maxSize, file.length - offset);
      final chunkCrc = getCrc32(file.sublist(0, offset + chunkSize));

      // Create command with size
      final chunkSizeAsBytes = [
        chunkSize & 0xFF,
        chunkSize >> 8 & 0xFF,
        chunkSize >> 16 & 0xff,
        chunkSize >> 24 & 0xff
      ];

      try {
        if (isInitFile) {
          await _dfuSendControlData(
              Uint8List.fromList([0x01, 0x01, ...chunkSizeAsBytes]));
        } else {
          await _dfuSendControlData(
              Uint8List.fromList([0x01, 0x02, ...chunkSizeAsBytes]));
        }
      } catch (_) {
        throw ("Couldn't issue DFU create command");
      }

      // Split chunk into packets of MTU size
      final packetSize = device.mtuNow - 3;
      final packets = (chunkSize / packetSize).ceil();

      for (var p = 0; p < packets; p++) {
        final fileStart = offset + p * packetSize;
        var fileEnd = fileStart + packetSize;

        // The last packet could be smaller
        if (fileEnd - offset > maxSize) {
          fileEnd -= fileEnd - offset - maxSize;
        }

        // The last part of the file could also be smaller
        if (fileEnd > file.length) {
          fileEnd = file.length;
        }

        final fileSlice = file.sublist(fileStart, fileEnd);

        final percentDone = (100 / file.length) * offset;
        yield percentDone;

        _log.fine(
            "Sending ${fileSlice.length} bytes of packet data. ${percentDone.toInt()}% Complete");

        await _dfuSendPacketData(fileSlice)
            .onError((_, __) => throw ("Couldn't send DFU data"));
      }

      // Calculate CRC
      try {
        response = await _dfuSendControlData(Uint8List.fromList([0x03]));
      } catch (_) {
        throw ("Couldn't get CRC from device");
      }
      offset = ByteData.view(response.buffer).getUint32(3, Endian.little);
      final returnedCrc =
          ByteData.view(response.buffer).getUint32(7, Endian.little);

      if (returnedCrc != chunkCrc) {
        throw ("CRC mismatch after sending this chunk");
      }

      // Execute command (The last command may disconnect which is normal)
      try {
        response = await _dfuSendControlData(Uint8List.fromList([0x04]));
      } catch (_) {}
    }

    _log.fine("DFU file sent");
  }

  Future<Uint8List> _dfuSendControlData(Uint8List data) async {
    try {
      _log.fine("Sending ${data.length} bytes of DFU control data: $data");

      _dfuControl!.write(data, timeout: 1);

      final response = await _dfuControl!.onValueReceived
          .timeout(const Duration(seconds: 1))
          .first;

      return Uint8List.fromList(response);
    } catch (error) {
      return Future.error(BrilliantBluetoothException(error.toString()));
    }
  }

  Future<void> _dfuSendPacketData(Uint8List data) async {
    await _dfuPacket!.write(data, withoutResponse: true);
  }
}

class BrilliantBluetooth {
  static Future<void> requestPermission() async {
    try {
      await FlutterBluePlus.startScan();
      await FlutterBluePlus.stopScan();
    } catch (error) {
      _log.warning("Couldn't obtain Bluetooth permission. $error");
      return Future.error(BrilliantBluetoothException(error.toString()));
    }
  }

  static Stream<BrilliantScannedDevice> scan() async* {
    try {
      _log.info("Starting to scan for devices");

      await FlutterBluePlus.startScan(
        withServices: [
          Guid('7a230001-5475-a6a4-654c-8431f6ad49c4'),
          Guid('fe59'),
        ],
        continuousUpdates: true,
        removeIfGone: const Duration(seconds: 2),
      );
    } catch (error) {
      _log.warning("Scanning failed. $error");
      throw BrilliantBluetoothException(error.toString());
    }

    yield* FlutterBluePlus.scanResults
        .where((results) => results.isNotEmpty)
        // TODO filter by name: "Frame", "Frame Update", "Monocle" & "DFUTarg"
        .map((results) {
      ScanResult nearestDevice = results[0];
      for (int i = 0; i < results.length; i++) {
        if (results[i].rssi > nearestDevice.rssi) {
          nearestDevice = results[i];
        }
      }

      _log.fine(
          "Found ${nearestDevice.device.advName} rssi: ${nearestDevice.rssi}");

      return BrilliantScannedDevice(
        device: nearestDevice.device,
        rssi: nearestDevice.rssi,
      );
    });
  }

  static Future<void> stopScan() async {
    try {
      _log.info("Stopping scan for devices");
      await FlutterBluePlus.stopScan();
    } catch (error) {
      _log.warning("Couldn't stop scanning. $error");
      return Future.error(BrilliantBluetoothException(error.toString()));
    }
  }

  static Future<BrilliantDevice> connect(BrilliantScannedDevice scanned) async {
    try {
      _log.info("Connecting");

      await FlutterBluePlus.stopScan();

      await scanned.device.connect(
        autoConnect: Platform.isIOS ? true : false,
        mtu: null,
      );

      final connectionState = await scanned.device.connectionState
          .firstWhere((event) => event == BluetoothConnectionState.connected)
          .timeout(const Duration(seconds: 3));

      if (connectionState == BluetoothConnectionState.connected) {
        return await _enableServices(scanned.device);
      }

      throw ("${scanned.device.disconnectReason?.description}");
    } catch (error) {
      await scanned.device.disconnect();
      _log.warning("Couldn't connect. $error");
      return Future.error(BrilliantBluetoothException(error.toString()));
    }
  }

  static Future<BrilliantDevice> reconnect(String uuid) async {
    try {
      _log.info("Will re-connect to device: $uuid once found");

      BluetoothDevice device = BluetoothDevice.fromId(uuid);

      await device.connect(
        timeout: const Duration(days: 365),
        autoConnect: Platform.isIOS ? true : false,
        mtu: null,
      ); // TODO Should wait but it throws an error on Android after some time

      final connectionState = await device.connectionState.firstWhere((state) =>
          state == BluetoothConnectionState.connected ||
          (state == BluetoothConnectionState.disconnected &&
              device.disconnectReason != null));

      _log.info("Found reconnectable device: $uuid");

      if (connectionState == BluetoothConnectionState.connected) {
        return await _enableServices(device);
      }

      throw ("${device.disconnectReason?.description}");
    } catch (error) {
      _log.warning("Couldn't reconnect. $error");
      return Future.error(BrilliantBluetoothException(error.toString()));
    }
  }

  static Future<BrilliantDevice> _enableServices(BluetoothDevice device) async {
    if (Platform.isAndroid) {
      await device.requestMtu(512);
    }

    BrilliantDevice finalDevice = BrilliantDevice(
      device: device,
      state: BrilliantConnectionState.disconnected,
    );

    List<BluetoothService> services = await device.discoverServices();

    for (var service in services) {
      // If Frame
      if (service.serviceUuid == Guid('7a230001-5475-a6a4-654c-8431f6ad49c4')) {
        _log.fine("Found Frame service");
        for (var characteristic in service.characteristics) {
          if (characteristic.characteristicUuid ==
              Guid('7a230002-5475-a6a4-654c-8431f6ad49c4')) {
            _log.fine("Found Frame TX characteristic");
            finalDevice._txChannel = characteristic;
          }
          if (characteristic.characteristicUuid ==
              Guid('7a230003-5475-a6a4-654c-8431f6ad49c4')) {
            _log.fine("Found Frame RX characteristic");
            finalDevice._rxChannel = characteristic;

            await characteristic.setNotifyValue(true);
            _log.fine("Enabled RX notifications");

            finalDevice.maxStringLength = device.mtuNow - 3;
            finalDevice.maxDataLength = device.mtuNow - 4;
            _log.fine("Max string length: ${finalDevice.maxStringLength}");
            _log.fine("Max data length: ${finalDevice.maxDataLength}");
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
            finalDevice._dfuControl = characteristic;
            await characteristic.setNotifyValue(true);
            _log.fine("Enabled DFU control notifications");
          }
          if (characteristic.characteristicUuid ==
              Guid('8ec90002-f315-4f60-9fb8-838830daea50')) {
            _log.fine("Found DFU packet characteristic");
            finalDevice._dfuPacket = characteristic;
          }
        }
      }
    }

    if (finalDevice._txChannel != null && finalDevice._rxChannel != null) {
      finalDevice.state = BrilliantConnectionState.connected;
      return finalDevice;
    }

    if (finalDevice._dfuControl != null && finalDevice._dfuPacket != null) {
      finalDevice.state = BrilliantConnectionState.dfuConnected;
      return finalDevice;
    }

    throw ("Incomplete set of services found");
  }
}
