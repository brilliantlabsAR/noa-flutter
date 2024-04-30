import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:logging/logging.dart';

final _log = Logger("Bytes to wav");

Uint8List _uint32to8(int value) =>
    Uint8List(4)..buffer.asUint32List()[0] = value;

Uint8List _uint16to8(int value) =>
    Uint8List(2)..buffer.asUint16List()[0] = value;

Uint8List offsetPcm(Uint8List inData) {
  List<int> outData = [];
  for (var element in inData) {
    outData.add((element + 128) % 256);
  }
  var outDataUint8 = Uint8List.fromList(outData);
  return outDataUint8.buffer.asUint8List();
}

Uint8List bytesToWav(Uint8List pcmBytes, int bitDepth, int sampleRate) {
  final output = BytesBuilder();
  try {
    output.add(utf8.encode('RIFF'));
    output.add(_uint32to8(36 + pcmBytes.length));
    output.add(utf8.encode('WAVE'));
    output.add(utf8.encode('fmt '));
    output.add(_uint32to8(16));
    output.add(_uint16to8(1));
    output.add(_uint16to8(1));
    output.add(_uint32to8(sampleRate));
    output.add(_uint32to8((sampleRate * bitDepth) ~/ 8));
    output.add(_uint16to8(bitDepth ~/ 8));
    output.add(_uint16to8(bitDepth));
    output.add(utf8.encode('data'));
    output.add(_uint32to8(pcmBytes.length));
    output.add(offsetPcm(pcmBytes.buffer.asUint8List()));
  } catch (error) {
    _log.warning("Could not build audio file: $error");
  }
  return output.toBytes();
}
