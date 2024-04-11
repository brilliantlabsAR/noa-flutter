import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:noa/models/noa_message_model.dart';
import 'package:noa/util/check_internet_connection.dart';
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
  static Future<String> obtainAuthToken(
    String id,
    NoaApiAuthProvider provider,
  ) async {
    try {
      // await checkInternetConnection(); // TODO needed?

      final response = await http.post(
        Uri.parse('https://api.brilliant.xyz/noa/signin'),
        body: {
          'id_token': id,
          'social_type': provider.value,
          'app': 'flutter',
        },
      );

      if (response.statusCode != 200) {
        throw NoaApiServerError(response.statusCode);
      }

      final decoded = jsonDecode(response.body);

      return decoded['token'];
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

  static Future<dynamic> getUser(String userAuthToken) async {
    try {
      // await checkInternetConnection();

      final response = await http.get(
        Uri.parse('https://api.brilliant.xyz/noa/profile_info'),
        headers: {
          "Authorization": userAuthToken,
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

  static Future<void> getMessage(
      List<int> rawAudio,
      List<int> rawImage,
      List<NoaMessage> noaHistory,
      StreamController<NoaMessage>? responseListener) async {
    try {
      await checkInternetConnection();
      final authToken = await loadSavedAuthToken();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.brilliant.xyz/noa/mm'),
      );

      request.headers.addAll({
        HttpHeaders.authorizationHeader: authToken,
      });

      var currentTime = DateTime.now().toString();

      request.fields['prompt'] = 'find software developer jobs';
      request.fields['messages'] = '[{"role":"user", "content":"hello"}]';
      request.fields['experiment'] = '1';
      request.fields['config'] =
          '{"vision": "claude-3-haiku-20240307", address: "Stockholm, Sweden", local_time: $currentTime}';

      ByteData audio = await rootBundle.load('assets/test.wav');
      request.files.add(http.MultipartFile.fromBytes(
        'audio',
        audio.buffer.asUint8List(),
        filename: 'test.wav',
      ));

      ByteData image = await rootBundle.load('assets/test.wav');
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        image.buffer.asUint8List(),
        filename: 'test.jpg',
      ));

      var streamedResponse = await request.send();

      streamedResponse.stream.listen((value) {
        var body = jsonDecode(String.fromCharCodes(value));
        print(body);
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
