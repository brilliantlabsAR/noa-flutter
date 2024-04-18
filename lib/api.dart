import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:noa/models/noa_message_model.dart';
import 'package:noa/util/check_internet_connection.dart';

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
  static Future<String> signIn(String id, NoaApiAuthProvider provider) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.brilliant.xyz/noa/user/signin'),
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

  static Future<void> signOut(String userAuthToken) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.brilliant.xyz/noa/user/signout'),
        headers: {"Authorization": userAuthToken},
      );

      if (response.statusCode != 200) {
        throw NoaApiServerError(response.statusCode);
      }
    } catch (error) {
      return Future.error(error);
    }
  }

  static Future<dynamic> getUser(String userAuthToken) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.brilliant.xyz/noa/user'),
        headers: {"Authorization": userAuthToken},
      );
      if (response.statusCode != 200) {
        throw NoaApiServerError(response.statusCode);
      }
      return jsonDecode(response.body)['user'];
    } catch (error) {
      return Future.error(Exception(error));
    }
  }

  static Future<void> deleteUser(String userAuthToken) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.brilliant.xyz/noa/user/delete'),
        headers: {"Authorization": userAuthToken},
      );

      if (response.statusCode != 200) {
        throw NoaApiServerError(response.statusCode);
      }
    } catch (error) {
      return Future.error(error);
    }
  }

  static Future<void> getMessage(
      String userAuthToken,
      List<int> rawAudio,
      List<int> rawImage,
      List<NoaMessage> noaHistory,
      StreamController<NoaMessage>? responseListener) async {
    try {
      await checkInternetConnection(); // TODO do we need this?

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.brilliant.xyz/noa'),
      );

      request.headers.addAll({HttpHeaders.authorizationHeader: userAuthToken});

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

      request.fields['messages'] = ''; // TODO system message and history
      request.fields['location'] = 'Stockholm Sweden';
      request.fields['time'] = DateTime.now().toString();
      request.fields['temperature'] = '1.0';
      request.fields['experimental[vision]'] = 'claude-3-haiku-20240307';
      print(request.fields);

      var streamedResponse = await request.send();

      streamedResponse.stream.listen((value) {
        var body = jsonDecode(String.fromCharCodes(value));
        print(body);

        responseListener!.add(NoaMessage(
          message: body['user_prompt'],
          from: NoaRole.user,
          time: DateTime.now(),
          // TODO append debug image
        ));

        responseListener.add(NoaMessage(
          message: body['message'],
          from: NoaRole.noa,
          time: DateTime.now(),
          // TODO append response image
        ));

        // Update user stats
      });
    } catch (error) {
      return Future.error(Exception(error));
    }
  }
}
