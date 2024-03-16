import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SignIn {
  withApple() async {}

  Future<bool> withGoogle() async {
    try {
      final GoogleSignInAccount? account = await GoogleSignIn(
        clientId: dotenv.env['GOOGLE_CLIENT_ID'],
        scopes: ['email'],
      ).signIn();

      final GoogleSignInAuthentication auth = await account!.authentication;

      print(auth.accessToken);
      print(auth.idToken);
    } catch (e) {
      print(e);
      return false;
    }

    return true;
  }

  withDiscord() async {}
}
