import 'dart:convert';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SignInNoConnectionError implements Exception {
  SignInNoConnectionError();
}

class SignInCancelledError implements Exception {
  SignInCancelledError();
}

class SignInServerError implements Exception {
  int serverErrorCode;
  SignInServerError(this.serverErrorCode);

  @override
  String toString() {
    return "$serverErrorCode";
  }
}

class SignIn {
  Future<bool> _checkForInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('www.google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  withApple() async {}

  Future<String> withGoogle() async {
    try {
      final internetConnection = await _checkForInternetConnection();
      if (internetConnection == false) {
        return Future.error(SignInNoConnectionError());
      }

      final GoogleSignInAccount? account = await GoogleSignIn(
        clientId: dotenv.env['GOOGLE_CLIENT_ID'],
        scopes: ['email'],
      ).signIn();

      final GoogleSignInAuthentication auth = await account!.authentication;

      Map<String, String> form = {
        'id_token': auth.idToken ?? "",
        'social_type': '1',
        'app': 'flutter',
      };

      final response = await http.post(
        Uri.parse('https://api.brilliant.xyz/noa/signin'),
        body: form,
      );

      if (response.statusCode != 200) {
        return Future.error(SignInServerError(response.statusCode));
      }

      final decoded = jsonDecode(response.body);

      return decoded['token'];
    } catch (error) {
      print(error);
      return Future.error(SignInCancelledError());
    }
  }

  withDiscord() async {}
}
