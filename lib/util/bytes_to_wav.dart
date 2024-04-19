import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart'; // Uncomment to listen to audio

Uint8List _uint32to8(int value) =>
    Uint8List(4)..buffer.asUint32List()[0] = value;

Uint8List _uint16to8(int value) =>
    Uint8List(2)..buffer.asUint16List()[0] = value;

Uint8List bytesToWav(Uint8List pcmBytes, int bitDepth, int sampleRate) {
  print("converting ${pcmBytes.length} bytes to wav");
  final output = BytesBuilder();

  // Write the WAV header
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
  output.add(pcmBytes);

  print(output.toBytes());

  // Uncomment to listen to audio
  final player = AudioPlayer();
  player.play(BytesSource(output.toBytes()));

  return output.toBytes();
}
