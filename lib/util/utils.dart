import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
class Utils{

  static Future<Uint8List>  rawToWave(
      Uint8List rawPCMBytes,
      int sampleRate,
      int bitPerSample,
      int channel,
      ) async {
    final output = BytesBuilder();
    try {
      // Write the WAV header
      output.add(utf8.encode('RIFF')); // chunk id
      writeIntToBytes(output, 36 + rawPCMBytes.length); // chunk size
      output.add(utf8.encode('WAVE')); // format
      output.add(utf8.encode('fmt ')); // subchunk 1 id
      writeIntToBytes(output, 16); // subchunk 1 size
      writeShortToBytes(output, 1); // audio format (1 = PCM)
      writeShortToBytes(output, channel); // number of channels
      writeIntToBytes(output, sampleRate); // sample rate
      writeIntToBytes(output, sampleRate * channel * bitPerSample ~/ 8); // byte rate
      writeShortToBytes(output, channel * bitPerSample ~/ 8); // block align
      writeShortToBytes(output, bitPerSample); // bits per sample
      output.add(utf8.encode('data')); // subchunk 2 id
      writeIntToBytes(output, rawPCMBytes.length); // subchunk 2 size

      // Write the audio data
      output.add(rawPCMBytes);

      final Directory documentsDirectory = await getApplicationDocumentsDirectory();
      final String filePath = '${documentsDirectory.path}/output.wav';

      // Write the WAV file to the documents directory
      final File file = File(filePath);
      await file.writeAsBytes(output.toBytes());


      return output.toBytes();
    } finally {
      // Close resources if needed
    }
  }

  static writeIntToBytes(BytesBuilder builder, int value) {
    builder.addByte(value & 0xFF);
    builder.addByte((value >> 8) & 0xFF);
    builder.addByte((value >> 16) & 0xFF);
    builder.addByte((value >> 24) & 0xFF);
  }

  static writeShortToBytes(BytesBuilder builder, int value) {
    builder.addByte(value & 0xFF);
    builder.addByte((value >> 8) & 0xFF);
  }

  static Future<File?> saveWavFileToDeviceStorage(Uint8List wavFileData) async {
    try {
      final Directory documentsDirectory = await getApplicationDocumentsDirectory();
      final String filePath = '${documentsDirectory.path}/output.wav';

      // Write the WAV file to the documents directory
      final File file = File(filePath);
      await file.writeAsBytes(wavFileData);

      // Optionally, you can show a message to indicate that the file has been saved
      print('WAV file saved to: $filePath');

      return file;
    } catch (e) {
      print('Error saving WAV file: $e');
      return null;
      // Handle any errors that occur during the file saving process
    }
  }

  static Future<String?> processAndSaveImage(Uint8List imageBuffer) async {
    try {
      // Decode the byte array into an Image
      final image = img.decodeImage(imageBuffer);

      if (image != null) {
        // Resize the image to a multiple of 64
        final resizedImage = resizeImageToMultipleOf64(image);

        // Convert the image to a JPEG file
        final jpegData = img.encodeJpg(resizedImage);

        // Save the JPEG data to a file
        final jpegFile = await saveImageDataAsJPEG(jpegData);

        // Return the absolute path of the saved JPEG file
        return jpegFile?.path;
      }
    } catch (e) {
      print('Error processing and saving image: $e');
    }
    return null;
  }

  static img.Image resizeImageToMultipleOf64(img.Image image) {
    final newWidth = _roundToMultipleOf64(image.width);
    final newHeight = _roundToMultipleOf64(image.height);
    return img.copyResize(image, width: newWidth, height: newHeight);
  }

  static int _roundToMultipleOf64(int number) {
    return ((number + 63) ~/ 64) * 64;
  }

  static Future<Uri?> saveImageDataAsJPEG(Uint8List jpegData) async {
    // Example: Save the JPEG data to a temporary file
    // Adjust the path and file naming logic as needed
    // Here, we're using the temporary directory
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/image.jpg');
    await tempFile.writeAsBytes(jpegData);
    return tempFile.uri;
  }
}