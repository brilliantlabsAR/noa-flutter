import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logging/logging.dart';
import 'package:noa/noa_api.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

final _log = Logger("Sign in");

class SignIn {
  Future<String> withApple() async {
    try {
      _log.info("Signing in using Apple");

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          clientId: 'xyz.brilliant.noaflutter',
          redirectUri: Uri.parse('https://api.brilliant.xyz/noa/login/apple'),
        ),
      );

      return await NoaApi.signIn(
        credential.authorizationCode,
        NoaApiAuthProvider.apple,
      );
    } catch (error) {
      _log.warning("Could not sign in: $error");
      return Future.error(error);
    }
  }

  Future<String> withGoogle() async {
    try {
      _log.info("Signing in using Google");

      GoogleSignInAccount? account;

      if (Platform.isAndroid) {
        account = await GoogleSignIn(
          serverClientId: kReleaseMode
              ? dotenv.env['GOOGLE_ANDROID_CLIENT_ID']
              : dotenv.env['GOOGLE_ANDROID_DEBUG_CLIENT_ID'],
          scopes: ['email'],
        ).signIn();
      }

      if (Platform.isIOS) {
        account = await GoogleSignIn(
          clientId: dotenv.env['GOOGLE_IOS_CLIENT_ID'],
          scopes: ['email'],
        ).signIn();
      }

      final GoogleSignInAuthentication auth = await account!.authentication;

      return await NoaApi.signIn(
        auth.idToken ?? "",
        NoaApiAuthProvider.google,
      );
    } catch (error) {
      _log.warning("Could not sign in: $error");
      return Future.error(error);
    }
  }

  withDiscord() async {}
}
