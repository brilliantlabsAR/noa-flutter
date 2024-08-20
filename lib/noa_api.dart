import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'package:noa/util/bytes_to_wav.dart';
import 'package:noa/util/location.dart';
import 'package:path_provider/path_provider.dart';
import 'package:noa/models/app_logic_model.dart'; // Add this import

final _log = Logger("Noa API");

class NoaApiServerException implements Exception {
  String reason;
  int statusCode;

  NoaApiServerException({
    required this.reason,
    required this.statusCode,
  });

  @override
  String toString() {
    return "NoaApiServerException: $statusCode: $reason";
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
        },
      );

      if (response.statusCode != 200) {
        throw NoaApiServerException(
          reason: response.body,
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(response.body);

      return decoded['token'];
    } catch (error) {
      _log.warning(error);
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
        throw NoaApiServerException(
          reason: response.body,
          statusCode: response.statusCode,
        );
      }
    } catch (error) {
      _log.warning(error);
      return Future.error(error);
    }
  }

  static Future<NoaUser> getUser(String userAuthToken) async {
    _log.info("Getting user info");
    try {
      final response = await http.get(
        Uri.parse('https://api.brilliant.xyz/noa/user'),
        headers: {"Authorization": userAuthToken},
      );

      if (response.statusCode != 200) {
        throw NoaApiServerException(
          reason: response.body,
          statusCode: response.statusCode,
        );
      }

      final body = jsonDecode(response.body);
      final email = body['user']['email'];
      final plan = body['user']['plan'];
      final creditsUsed = body['user']['credit_used'];
      final maxCredits = body['user']['credit_total'];

      _log.info(
          "Got user account info: Email: $email, plan: $plan, credits: $creditsUsed/$maxCredits");

      return NoaUser(
        email: email,
        plan: plan,
        creditsUsed: creditsUsed,
        maxCredits: maxCredits,
      );
    } catch (error) {
      _log.warning(error);
      return Future.error(error);
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
        throw NoaApiServerException(
          reason: response.body,
          statusCode: response.statusCode,
        );
      }
    } catch (error) {
      _log.warning(error);
      return Future.error(error);
    }
  }

  static Future<List<NoaMessage>> getMessage(
    String userAuthToken,
    Uint8List audio,
    Uint8List image,
    String systemRole,
    double temperature,
    List<NoaMessage> noaHistory,
    bool textToSpeech,
    AppLogicModel appLogicModel, // Add this parameter
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.brilliant.xyz/noa'),
      );

      request.headers.addAll({HttpHeaders.authorizationHeader: userAuthToken});

      // Create mm JSON object
      var mmData = {
        'local_time': DateTime.now().toLocal().toString(),
        'address': await Location.getAddress(),
      };

      request.fields['mm'] = jsonEncode(mmData);

      // Add image file
      if (image.isNotEmpty) {
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          image,
          filename: 'image.jpg',
        ));
      }

      // Add audio file
      if (audio.isNotEmpty) {
        request.files.add(http.MultipartFile.fromBytes(
          'audio',
          bytesToWav(audio, 8, 8000),
          filename: 'audio.wav',
        ));
      }

      _log.info("Sending message request: ${request.fields}");

      var streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        throw NoaApiServerException(
          reason: streamedResponse.reasonPhrase ?? "",
          statusCode: streamedResponse.statusCode,
        );
      }

      List<int> serverResponse = List.empty(growable: true);
      await streamedResponse.stream
          .forEach((element) => serverResponse += element);
      var body = jsonDecode(utf8.decode(serverResponse));

      List<NoaMessage> response = List.empty(growable: true);

      response.add(NoaMessage(
        message: body['user_prompt'].toString().replaceAll(RegExp(r'—'), '-'),
        from: NoaRole.user,
        time: DateTime.now(),
        image: kReleaseMode ? null : image,
      ));

      response.add(NoaMessage(
        message: body['message'].toString().replaceAll(RegExp(r'—'), '-'),
        from: NoaRole.noa,
        time: DateTime.now(),
        image: body['image'] != null ? base64.decode(body['image']) : null,
      ));

      // Check for note in the response and save it if present
      List<dynamic> notes = body['note'] ?? [];
      for (var note in notes) {
        String title = note['title'] ?? "";
        String content = note['note_content'] ?? "";
        if (title.isNotEmpty) {
          appLogicModel.addNote(
            title: title,
            content: content,
          );
        }
      }
      _log.info(body);
      if (textToSpeech && body['audio'] != null) {
        _playAudio(base64.decode(body['audio']));
      }
      return response;
    } catch (error) {
      _log.warning(error);
      return Future.error(error);
    }
  }

  static Future<List<NoaMessage>> getWildcardMessage(
    String userAuthToken,
    String systemRole,
    double temperature,
    bool textToSpeech,
    AppLogicModel appLogicModel,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.brilliant.xyz/noa/wildcard'),
      );

      request.headers.addAll({HttpHeaders.authorizationHeader: userAuthToken});

      request.fields['noa_system_prompt'] = systemRole;
      request.fields['location'] = await Location.getAddress();
      request.fields['time'] = DateTime.now().toString();
      request.fields['temperature'] = temperature.toString();
      request.fields['tts'] = textToSpeech ? "1" : "0";

      _log.info("Sending wildcard request: ${request.fields.toString()}");

      var streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        throw NoaApiServerException(
          reason: streamedResponse.reasonPhrase ?? "",
          statusCode: streamedResponse.statusCode,
        );
      }

      List<int> serverResponse = List.empty(growable: true);
      await streamedResponse.stream
          .forEach((element) => serverResponse += element);
      var body = jsonDecode(utf8.decode(serverResponse));

      List<NoaMessage> response = List.empty(growable: true);

      response.add(NoaMessage(
        message: "Wildcard 👻",
        from: NoaRole.user,
        time: DateTime.now(),
      ));

      response.add(NoaMessage(
        message: body['message'].toString().replaceAll(RegExp(r'—'), '-'),
        from: NoaRole.noa,
        time: DateTime.now(),
      ));

      _log.info(
          "Received wildcard response. User: \"${body['user_prompt']}\". Noa: \"${body['message']}\". Debug: ${body['debug']}");

      if (textToSpeech && body['audio'] != null) {
        _playAudio(base64.decode(body['audio']));
      }

      return response;
    } catch (error) {
      _log.warning(error);
      return Future.error(error);
    }
  }

  static void _playAudio(Uint8List audio) async {
    _log.info("Playing ${audio.length} bytes of audio");

    final tempDir = await getTemporaryDirectory();
    File file = await File('${tempDir.path}/audio.mp3').create();
    file.writeAsBytesSync(audio);

    try {
      AudioPlayer player = AudioPlayer(handleAudioSessionActivation: false);
      await player.setAudioSource(AudioSource.file(file.path));
      await player.play();
      await player.dispose();
    } catch (error) {
      _log.warning("Error playing audio. $error");
    }
  }
}