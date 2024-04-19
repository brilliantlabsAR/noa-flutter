import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:noa/noa_api.dart';
import 'package:noa/util/check_internet_connection.dart';

class SignIn {
  withApple() async {}

  Future<String> withGoogle() async {
    try {
      await checkInternetConnection();

      final GoogleSignInAccount? account = await GoogleSignIn(
        clientId: dotenv.env['GOOGLE_IOS_CLIENT_ID'],
        scopes: ['email'],
      ).signIn();

      final GoogleSignInAuthentication auth = await account!.authentication;

      return await NoaApi.signIn(
        auth.idToken ?? "",
        NoaApiAuthProvider.google,
      );
    } on NoaApiServerError catch (error) {
      return Future.error(NoaApiServerError(error.serverErrorCode));
    } catch (error) {
      return Future.error(error);
    }
  }

  withDiscord() async {}
}
