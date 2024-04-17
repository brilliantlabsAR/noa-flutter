import 'dart:async';
import 'dart:io';


import 'package:flutter/services.dart';
import 'package:noa/models/noa_message_model.dart';
import 'package:noa/util/check_internet_connection.dart';
import 'package:noa/util/location_state.dart';
import 'package:noa/util/utils.dart';
import 'package:path_provider/path_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NoaApiNoAuthTokenError implements Exception {
  NoaApiNoAuthTokenError();
}

class NoaApiServerError implements Exception {
  int serverErrorCode;
  NoaApiServerError(this.serverErrorCode);

  @override
  String toString() {
    return "$serverErrorCode";
  }
}

enum NoaApiAuthProvider {
  google('google'),
  apple('apple'),
  discord('discord');

  const NoaApiAuthProvider(this.value);
  final String value;
}

class NoaApi {
  // StreamController<NoaMessage>? serverResponseListener;

  // NoaApi({
  //   required this.serverResponseListener,
  // });

  static Future<void> obtainAuthToken(
      String idToken, NoaApiAuthProvider authProvider) async {
    try {
      await checkInternetConnection();

      final response = await http.post(
        Uri.parse('https://api.brilliant.xyz/noa/signin'),
        body: {
          'id_token': idToken,
          "name":"Subhajit Pal",
          "email":"subhajitpal@technoexponent.com",
          'social_type': "1",
          "social_id" : "112509537595770132004"
          //'app': 'flutter',
        },
      );

      if (response.statusCode != 200) {
        throw NoaApiServerError(response.statusCode);
      }

      final decoded = jsonDecode(response.body);

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('userToken', decoded['token']);
    } catch (error) {
      return Future.error(error);
    }
  }

  static Future<String> loadSavedAuthToken() async {
    final preferences = await SharedPreferences.getInstance();
    final authToken = preferences.getString('userToken');
    if (authToken == null) {
      return Future.error(NoaApiNoAuthTokenError());
    }
    return authToken;
  }

  static Future<void> deleteSavedAuthToken() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('userToken');
  }

  static Future<dynamic> getProfile() async {
    try {
      await checkInternetConnection();
      final authToken = await loadSavedAuthToken();
      final response = await http.get(
        Uri.parse('https://api.brilliant.xyz/noa/profile_info'),
        headers: {
          "Authorization": authToken,
        },
      );
      if (response.statusCode != 200) {
        throw NoaApiServerError(response.statusCode);
      }
      return jsonDecode(response.body);
    } catch (error) {
      return Future.error(Exception(error));
    }
  }


  static Future<File> createPlayableAudioFile(List<int> rawAudio, int sampleRate, int bitDepth, int channels) async {
    try {
      // Get the application documents directory
      final Directory documentsDirectory = await getApplicationDocumentsDirectory();

      // Create a temporary WAV file
      final File wavFile = File('${documentsDirectory.path}/temp_audio.wav');

      // Write the WAV file header
      await wavFile.writeAsBytes(createWavHeader(rawAudio.length, sampleRate, bitDepth, channels));

      // Append the raw audio data to the WAV file
      await wavFile.writeAsBytes(rawAudio, mode: FileMode.append);

      return wavFile;
    } catch (e) {
      print('Error creating playable audio file: $e');
      throw e; // You can handle the error accordingly
    }
  }

  static List<int> createWavHeader(int dataSize, int sampleRate, int bitDepth, int channels) {
    final header = <int>[];

    // Chunk ID: "RIFF"
    header.addAll(utf8.encode('RIFF'));

    // Chunk size: 36 + data size
    header.addAll(_int32Bytes(36 + dataSize));

    // Format: "WAVE"
    header.addAll(utf8.encode('WAVE'));

    // Subchunk 1 ID: "fmt "
    header.addAll(utf8.encode('fmt '));

    // Subchunk 1 size: 16 for PCM
    header.addAll(_int32Bytes(16));

    // Audio format: 1 for PCM
    header.addAll(_int16Bytes(1));

    // Number of channels
    header.addAll(_int16Bytes(channels));

    // Sample rate
    header.addAll(_int32Bytes(sampleRate));

    // Byte rate
    header.addAll(_int32Bytes(sampleRate * channels * bitDepth ~/ 8));

    // Block align
    header.addAll(_int16Bytes(channels * bitDepth ~/ 8));

    // Bits per sample
    header.addAll(_int16Bytes(bitDepth));

    // Subchunk 2 ID: "data"
    header.addAll(utf8.encode('data'));

    // Subchunk 2 size: data size
    header.addAll(_int32Bytes(dataSize));

    return header;
  }

  static List<int> _int32Bytes(int value) => [value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF];
  static List<int> _int16Bytes(int value) => [value & 0xFF, (value >> 8) & 0xFF];





  Uint8List signed8ToUnsigned16(List<int> rawAudio) {
    final unsignedArray = Uint8List(rawAudio.length * 2);
    for (int i = 0; i < rawAudio.length; i++) {
      final unsigned = (rawAudio[i] & 0xFF) << 8;
      unsignedArray[i * 2] = (unsigned >> 8) & 0xFF;
      unsignedArray[i * 2 + 1] = unsigned & 0xFF;
    }
    return unsignedArray;
  }




  static Future<void> getMessage(
      List<int> rawAudio,
      List<int> rawImage,
      List<NoaMessage> noaHistory,
      StreamController<NoaMessage>? responseListener) async {
    try {
      await checkInternetConnection();
      final authToken = await loadSavedAuthToken();

      String currentAddress = globalProviderContainer.read(nameProvider);
      print('Current Name: $currentAddress');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.brilliant.xyz/noa/'),
      );

      request.headers.addAll({
        HttpHeaders.authorizationHeader: authToken,
      });

      var currentTime = DateTime.now().toString();

      request.fields['prompt'] = 'find software developer jobs';
      request.fields['messages'] = '[{"role":"user", "content":"hello"}]';
      request.fields['location'] = currentAddress;
      request.fields['time'] = currentTime;
      request.fields['temperature'] = "1.0";
      request.fields['experimental'] =
          '{"vision": "claude-3-haiku-20240307"}';



      createPlayableAudioFile(rawAudio,8000,16,1);
      final wavFileData = await Utils.rawToWave(
        Uint8List.fromList(rawAudio),
        8000, // Pass sampleRate, bitPerSample, and channel here
        16,
        1,
      );

     File? audiofile = await Utils.saveWavFileToDeviceStorage(wavFileData);

      // Create http.MultipartFile from WAV file data
      // final audioFile = http.MultipartFile.fromBytes(
      //   'audio',
      //   wavFileData,
      //   filename: 'test.wav',
      // );


      if(audiofile!=null) {
        // request.files.add(http.MultipartFile.fromBytes(
        //   'audio',
        //   wavFileData,
        //   filename: 'test.wav',
        // ));

        request.files.add(http.MultipartFile(
          'audio',
          audiofile.readAsBytes().asStream(), // Provide a stream of file bytes
          audiofile.lengthSync(), // Provide the file length
          filename: 'test.wav',
        ));
      }

      // Convert raw image data to JPEG using the new function
      final jpegImage = await Utils.processAndSaveImage(Uint8List.fromList(rawImage));

      if (jpegImage != null) {
        // Read the JPEG file as bytes
        final File imageFile = File(jpegImage);
        final imageBytes = await imageFile.readAsBytes();

        // Add the image file to the request
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'test.jpg',
        ));
      } else {
        print('Failed to process and save image.');
        return;
      }


      //
      // ByteData audio = await rootBundle.load('assets/test.wav');
      // request.files.add(http.MultipartFile.fromBytes(
      //   'audio',
      //   audio.buffer.asUint8List(),
      //   filename: 'test.wav',
      // ));

      // ByteData image = await rootBundle.load('assets/test.wav');
      // request.files.add(http.MultipartFile.fromBytes(
      //   'image',
      //   image.buffer.asUint8List(),
      //   filename: 'test.jpg',
      // ));

      var streamedResponse = await request.send();

      streamedResponse.stream.listen((value) {
        var body = jsonDecode(String.fromCharCodes(value));
        responseListener!.add(NoaMessage(
          message: body['response'],
          from: 'Noa',
          time: DateTime.now(),
        ));
      });
    } catch (error) {
      return Future.error(Exception(error));
    }
  }



}
