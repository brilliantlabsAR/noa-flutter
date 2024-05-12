import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart';
import 'package:logging/logging.dart';
import 'package:noa/util/bytes_to_wav.dart';
import 'package:noa/util/check_internet_connection.dart';
import 'package:noa/util/location.dart';

final _log = Logger("Noa API");

class NoaApiServerError implements Exception {
  int serverErrorCode;
  NoaApiServerError(this.serverErrorCode);

  @override
  String toString() {
    return "$serverErrorCode";
  }
}

// Authentication and account related classes
class NoaApiNoAuthTokenError implements Exception {
  NoaApiNoAuthTokenError();
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

// Noa messaging class
enum NoaRole {
  system('system'),
  user('user'),
  noa('noa');

  const NoaRole(this.value);
  final String value;
}

class NoaMessage {
  String message;
  NoaRole from;
  DateTime time;
  Uint8List? image;

  NoaMessage({
    required this.message,
    required this.from,
    required this.time,
    this.image,
  });

  Map<String, dynamic> toJson() {
    return {
      "role": from == NoaRole.noa ? "assistant" : "user",
      "content": message,
    };
  }
}

// All API endpoint features
class NoaApi {
  static Future<String> signIn(
    String id,
    NoaApiAuthProvider provider,
  ) async {
    _log.info("Signing in to Noa");
    _log.fine("Provider: $provider, ID token: $id");
    try {
      final response = await http.post(
        Uri.parse('https://api.brilliant.xyz/noa/user/signin'),
        body: {
          'id_token': id,
          'provider': provider.value,
          'app': 'flutter', // TODO remove this
        },
      );

      if (response.statusCode != 200) {
        _log.warning("Noa server responded with error: ${response.body}");
        throw NoaApiServerError(response.statusCode);
      }

      final decoded = jsonDecode(response.body);

      return decoded['token'];
    } catch (error) {
      _log.warning("Error signing in: $error");
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
        _log.warning("Noa server responded with error: ${response.body}");
        throw NoaApiServerError(response.statusCode);
      }
    } catch (error) {
      _log.warning("Error signing out: $error");
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
        _log.warning("Noa server responded with error: ${response.body}");
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
          "Updated user account info: Email: $email, plan: $plan, credits: $creditsUsed/$maxCredits");
    } catch (error) {
      _log.warning("Error getting user info: $error");
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
        _log.warning("Noa server responded with error: ${response.body}");
        throw NoaApiServerError(response.statusCode);
      }
    } catch (error) {
      _log.warning("Error deleting user: $error");
      return Future.error(error);
    }
  }

  static Future<void> getMessage(
    String userAuthToken,
    Uint8List audio,
    Uint8List image,
    String systemRole,
    double temperature,
    List<NoaMessage> noaHistory,
    StreamController<NoaMessage> responseListener,
    StreamController<NoaUser> userInfoListener,
  ) async {
    try {
      await checkInternetConnection(); // TODO do we need this?

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.brilliant.xyz/noa'),
      );

      request.headers.addAll({HttpHeaders.authorizationHeader: userAuthToken});

      request.files.add(http.MultipartFile.fromBytes(
        'audio',
        bytesToWav(audio, 8, 8000),
        filename: 'audio.wav',
      ));

      image = encodeJpg(copyRotate(decodeJpg(image)!, angle: -90));

      request.files.add(http.MultipartFile.fromBytes(
        'image',
        image,
        filename: 'image.jpg',
      ));

      request.fields['noa_system_prompt'] = systemRole;
      request.fields['messages'] = jsonEncode(noaHistory);
      request.fields['location'] = await Location.getAddress();
      request.fields['time'] = DateTime.now().toString();
      request.fields['temperature'] = temperature.toString();
      request.fields['experimental'] =
          '{"vision":"claude-3-haiku-20240307"}'; // TODO can we remove this?

      _log.info(
          "Sending message request: audio[${audio.length}], image[${image.length}], ${request.fields.toString()}");

      var streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        _log.warning(
            "Noa server responded with error: ${streamedResponse.reasonPhrase}");
        throw NoaApiServerError(streamedResponse.statusCode);
      }

      streamedResponse.stream.listen((value) {
        var body = jsonDecode(String.fromCharCodes(value));

        responseListener.add(NoaMessage(
          message: body['user_prompt'],
          from: NoaRole.user,
          time: DateTime.now(),
          image: image,
        ));

        responseListener.add(NoaMessage(
          message: body['message'],
          from: NoaRole.noa,
          time: DateTime.now(),
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
            "Received response. User: \"${body['user_prompt']}\". Noa: \"${body['message']}\". Debug: ${body['debug']}");
        _log.info(
            "Updated user account info. Email: $email, plan: $plan, credits: $creditsUsed/$maxCredits");
      });
    } catch (error) {
      _log.warning("Could not complete Noa request: $error");
      return Future.error(Exception(error));
    }
  }

  static Future<void> getWildcardMessage(
    String userAuthToken,
    String systemRole,
    double temperature,
    StreamController<NoaMessage> responseListener,
    StreamController<NoaUser> userInfoListener,
  ) async {
    try {
      await checkInternetConnection(); // TODO do we need this?

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.brilliant.xyz/noa/wildcard'),
      );

      request.headers.addAll({HttpHeaders.authorizationHeader: userAuthToken});

      request.fields['noa_system_prompt'] = systemRole;
      request.fields['location'] = await Location.getAddress();
      request.fields['time'] = DateTime.now().toString();
      request.fields['temperature'] = temperature.toString();

      _log.info("Sending wildcard request: ${request.fields.toString()}");

      var streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        _log.warning(
            "Noa server responded with error: ${streamedResponse.reasonPhrase}");
        throw NoaApiServerError(streamedResponse.statusCode);
      }

      streamedResponse.stream.listen((value) {
        var body = jsonDecode(String.fromCharCodes(value));

        responseListener.add(NoaMessage(
          message: body['user_prompt'],
          from: NoaRole.user,
          time: DateTime.now(),
        ));

        responseListener.add(NoaMessage(
          message: body['message'],
          from: NoaRole.noa,
          time: DateTime.now(),
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
            "Received wildcard response. User: \"${body['user_prompt']}\". Noa: \"${body['message']}\". Debug: ${body['debug']}");
        _log.info(
            "Updated user account info. Email: $email, plan: $plan, credits: $creditsUsed/$maxCredits");
      });
    } catch (error) {
      _log.warning("Could not complete Noa request: $error");
      return Future.error(Exception(error));
    }
  }

  static Future<void> getImage(
    String userAuthToken,
    Uint8List audio,
    Uint8List image,
    StreamController<NoaMessage> responseListener,
    StreamController<NoaUser> userInfoListener,
  ) async {
    try {
      await checkInternetConnection(); // TODO do we need this?

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.brilliant.xyz/noa/imagegen'),
      );

      request.headers.addAll({HttpHeaders.authorizationHeader: userAuthToken});

      request.files.add(http.MultipartFile.fromBytes(
        'audio',
        bytesToWav(audio, 8, 8000),
        filename: 'audio.wav',
      ));

      image = encodeJpg(copyRotate(decodeJpg(image)!, angle: -90));

      request.files.add(http.MultipartFile.fromBytes(
        'image',
        image,
        filename: 'image.jpg',
      ));

      _log.info(
          "Sending image request: audio[${audio.length}], image[${image.length}], ${request.fields.toString()}");

      var streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        _log.warning(
            "Noa server responded with error: ${streamedResponse.reasonPhrase}");
        throw NoaApiServerError(streamedResponse.statusCode);
      }

      streamedResponse.stream.listen((value) {
        var body = jsonDecode(String.fromCharCodes(value));

        responseListener.add(NoaMessage(
          message: body['user_prompt'],
          from: NoaRole.user,
          time: DateTime.now(),
          image: image,
        ));

        responseListener.add(NoaMessage(
          message: "Here's what I generated",
          from: NoaRole.noa,
          time: DateTime.now(),
          image: body['image'] != "" ? base64.decode(body['image']) : null,
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
            "Received response. User: \"${body['user_prompt']}\". Noa: \"${body['message']}\". Debug: ${body['debug']}");
        _log.info(
            "Updated user account info. Email: $email, plan: $plan, credits: $creditsUsed/$maxCredits");
      });
    } catch (error) {
      _log.warning("Could not complete Noa request: $error");
      return Future.error(Exception(error));
    }
  }
}
