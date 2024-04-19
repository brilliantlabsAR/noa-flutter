import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:noa/models/noa_message_model.dart';
import 'package:noa/util/check_internet_connection.dart';

final _log = Logger("Noa API");

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

class NoaUser {
  late String email;
  late String plan;
  late int creditsUsed;
  late int maxCredits;

  NoaUser({
    String? email,
    String? plan,
    int? creditsUsed,
    int? maxCredits,
  }) {
    this.email = email ?? "Not logged in";
    this.plan = plan ?? "";
    this.creditsUsed = creditsUsed ?? 0;
    this.maxCredits = maxCredits ?? 0;
  }
}

class NoaApi {
  static Future<String> signIn(
    String id,
    NoaApiAuthProvider provider,
  ) async {
    _log.info("Signing in with ${provider.value}");
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

  static Future<void> signOut(
    String userAuthToken,
  ) async {
    _log.info("Signing out");
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

  static Future<void> getUser(
    String userAuthToken,
    StreamController<NoaUser> userInfoListener,
  ) async {
    _log.info("Getting user info");
    try {
      final response = await http.get(
        Uri.parse('https://api.brilliant.xyz/noa/user'),
        headers: {"Authorization": userAuthToken},
      );
      if (response.statusCode != 200) {
        throw NoaApiServerError(response.statusCode);
      }

      final body = jsonDecode(response.body);
      final email = body['user']['email'];
      final plan = body['user']['plan'];
      final creditsUsed = body['user']['credit_used'];
      final maxCredits = body['user']['credit_total'];

      userInfoListener.add(NoaUser(
        email: email,
        plan: plan,
        creditsUsed: creditsUsed,
        maxCredits: maxCredits,
      ));

      _log.info(
          "email: $email, plan: $plan, credits: $creditsUsed/$maxCredits");
    } catch (error) {
      return Future.error(Exception(error));
    }
  }

  static Future<void> deleteUser(
    String userAuthToken,
  ) async {
    _log.info("Deleting user");
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
    StreamController<NoaMessage> responseListener,
    StreamController<NoaUser> userInfoListener,
  ) async {
    _log.info(
        "Sending request: audio[${rawAudio.length}], image[${rawImage.length}]");
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

      var streamedResponse = await request.send();

      streamedResponse.stream.listen((value) {
        var body = jsonDecode(String.fromCharCodes(value));

        responseListener.add(NoaMessage(
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

        final email = body['user']['email'];
        final plan = body['user']['plan'];
        final creditsUsed = body['user']['credit_used'];
        final maxCredits = body['user']['credit_total'];

        userInfoListener.add(NoaUser(
          email: email,
          plan: plan,
          creditsUsed: creditsUsed,
          maxCredits: maxCredits,
        ));

        _log.info(
            "email: $email, plan: $plan, credits: $creditsUsed/$maxCredits");
      });
    } catch (error) {
      return Future.error(Exception(error));
    }
  }
}
