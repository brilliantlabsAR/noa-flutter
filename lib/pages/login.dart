import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noa/api.dart';
import 'package:noa/pages/pairing.dart';
import 'package:noa/style.dart';
import 'package:noa/util/alert_dialog.dart';
import 'package:noa/util/check_internet_connection.dart';
import 'package:noa/util/sign_in.dart';
import 'package:noa/util/switch_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

import '../locationService.dart';
import '../util/location_state.dart';

Widget _loginButton(
  BuildContext context,
  WidgetRef ref,
  String image,
  Function action,
) {
  return GestureDetector(
    onTap: () async {
      try {


        await action();

        if (context.mounted) {
          switchPage(context, const PairingPage());
        }
      } on CheckInternetConnectionError catch (_) {
        if (context.mounted) {
          alertDialog(
            context,
            "Couldn't Sign In",
            "Noa requires an internet connection",
          );
        }
      } on NoaApiServerError catch (error) {
        if (context.mounted) {
          alertDialog(
            context,
            "Couldn't Sign In",
            "Server responded with an error: $error",
          );
        }
      } catch (_) {}
    },
    child: Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Image.asset(image),
    ),
  );
}

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  Future<void> _getLocation() async {
    try {
      Position position = await LocationService().getCurrentLocation();
      String? address =
      await LocationService().getAddressFromCoordinates(position);

      updateName(address?? "not Specified");

      print(address);
    } catch (e) {
      print("Error fetching location: $e");
    }
  }
  Future<void> _requestPermissions() async {

    try {
      // Permissions to request
      List<Permission> permissions = [
        Permission.location,
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.storage,
        Permission.mediaLibrary,
      ];

      // Request permissions
      await permissions.request();
    }
    catch(ex){
      print(ex.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    _requestPermissions();
    _getLocation();
    // Skip this screen if already signed in
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await NoaApi.loadSavedAuthToken();
        if (context.mounted) {
          switchPage(context, const PairingPage());
        }
      } catch (_) {}
    });
    // Otherwise show the page
    return Scaffold(
      backgroundColor: colorDark,
      appBar: AppBar(
        backgroundColor: colorDark,
        title: Image.asset('assets/images/brilliant_logo.png'),
      ),
      body: Column(
        children: [
          Expanded(child: Image.asset('assets/images/noa_logo.png')),
          Column(
            children: [
              _loginButton(
                context,
                ref,
                'assets/images/sign_in_with_apple_button.png',
                SignIn().withApple,
              ),
              _loginButton(
                context,
                ref,
                'assets/images/sign_in_with_google_button.png',
                SignIn().withGoogle,
              ),
              _loginButton(
                context,
                ref,
                'assets/images/sign_in_with_discord_button.png',
                SignIn().withDiscord,
              ),
              SignInWithAppleButton(
                onPressed: () async {
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
                        'https://flutter-sign-in-with-apple-example.glitch.me/callbacks/sign_in_with_apple',
                      ),
                    ),
                    // TODO: Remove these if you have no need for them
                    // nonce: 'example-nonce',
                    // state: 'example-state',
                  );

                  // ignore: avoid_print
                  print(credential);

                  // This is the endpoint that will convert an authorization code obtained
                  // via Sign in with Apple into a session in your system
                  // final signInWithAppleEndpoint = Uri(
                  //   scheme: 'https',
                  //   host: 'flutter-sign-in-with-apple-example.glitch.me',
                  //   path: '/sign_in_with_apple',
                  //   queryParameters: <String, String>{
                  //     'code': credential.authorizationCode,
                  //     if (credential.givenName != null)
                  //       'firstName': credential.givenName!,
                  //     if (credential.familyName != null)
                  //       'lastName': credential.familyName!,
                  //     'useBundleId':
                  //     !kIsWeb && (Platform.isIOS || Platform.isMacOS)
                  //         ? 'true'
                  //         : 'false',
                  //     if (credential.state != null) 'state': credential.state!,
                  //   },
                  // );
                  //
                  // final session = await http.Client().post(
                  //   signInWithAppleEndpoint,
                  // );

                  // If we got this far, a session based on the Apple ID credential has been created in your system,
                  // and you can now set this as the app's session
                  // ignore: avoid_print
                  //print(session);
                },
              )
            ],
          )
        ],
      ),
      bottomNavigationBar:  Padding(
        padding: const EdgeInsets.only(bottom: 48, top: 48),
        child: PrivacyPolicyAndTerms(),
      ),
    );
  }



}
class PrivacyPolicyAndTerms extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(color: Colors.black),
        children: <TextSpan>[
          TextSpan(text: ''),
          _buildClickableTextSpan(
            text: 'Privacy Policy',
            url: 'https://brilliant.xyz/pages/privacy-policy',
          ),
          TextSpan(text: ' and ',style: TextStyle(color: Colors.white)),
          _buildClickableTextSpan(
            text: 'Terms and Conditions',
            url: 'https://brilliant.xyz/pages/terms-conditions',
          ),
          TextSpan(text: ' of Noa.',style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  TextSpan _buildClickableTextSpan({required String text, required String url}) {
    return TextSpan(
      text: text,
      style: TextStyle(color: Colors.pink),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          launchURL(url);
        },
    );
  }

  void launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}