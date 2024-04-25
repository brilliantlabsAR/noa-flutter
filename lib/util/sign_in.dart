import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:noa/noa_api.dart';
import 'package:noa/util/check_internet_connection.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SignIn {
  withApple() async {
    try {
    await checkInternetConnection();


      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebAuthenticationOptions(
          // TODO: Set the `clientId` and `redirectUri` arguments to the values you entered in the Apple Developer portal during the setup
          clientId:
          'xyz.brilliant.noaflutter',
          redirectUri:
          // For web your redirect URI needs to be the host of the "current page",
          // while for Android you will be using the API server that redirects back into your app via a deep link
          // NOTE(tp): For package local development use (as described in `Development.md`)
          // Uri.parse('https://siwa-flutter-plugin.dev/')
          Uri.parse(
            'https://brilliant.xyz',
          ),
        ),
        // TODO: Remove these if you have no need for them
        // nonce: 'example-nonce',
        // state: 'example-state',
      );

      // ignore: avoid_print
      print(credential);

    await NoaApi.signIn(
      credential.authorizationCode ?? "",
      NoaApiAuthProvider.apple,
    );
  } on NoaApiServerError catch (error) {


  return Future.error(NoaApiServerError(error.serverErrorCode));
  } catch (error) {

  return Future.error(error);
  }

  }


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
