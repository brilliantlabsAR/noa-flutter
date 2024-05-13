import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/noa_api.dart';
import 'package:noa/pages/pairing.dart';
import 'package:noa/style.dart';
import 'package:noa/util/alert_dialog.dart';
import 'package:noa/util/check_internet_connection.dart';
import 'package:noa/util/sign_in.dart';
import 'package:noa/util/switch_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

TextSpan _clickableLink({required String text, required String url}) {
  return TextSpan(
    text: text,
    style: textStylePink,
    recognizer: TapGestureRecognizer()
      ..onTap = () async {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
        }
      },
  );
}

Widget _loginButton(
  BuildContext context,
  WidgetRef ref,
  String image,
  Function action,
) {
  return GestureDetector(
    onTap: () async {
      try {
        ref.read(app.model).loggedIn(await action());
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

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late bool showWebview;


  @override
  void initState() {

    showWebview = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.watch(app.model).state.current != app.State.waitForLogin) {
        switchPage(context, const PairingPage());
      }
    });

    return Scaffold(
      backgroundColor: colorDark,
      appBar: AppBar(
        backgroundColor: colorDark,
        title: Image.asset('assets/images/brilliant_logo.png'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: Image.asset('assets/images/noa_logo.png')),
              Column(
                children: [
                  if (Platform.isIOS)
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
                  GestureDetector(
                    onTap: () async => setState(() => showWebview = true),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Image.asset(
                          'assets/images/sign_in_with_email_button.png'),
                    ),
                  )
                ],
              )
            ],
          ),
          if (showWebview)
            WebViewWidget(
              controller: WebViewController()
                ..loadRequest(Uri.parse("https://www.google.com"))
                ..addJavaScriptChannel("userAuthToken",
                    onMessageReceived: (message) {
                  if (message.message == "cancelled") {
                    setState(() {
                      showWebview = false;
                    });
                    if (message.message != "") {
                      ref.read(app.model).loggedIn(message.message);
                    }
                  }
                }),
            )
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 48, top: 48),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: <TextSpan>[
              const TextSpan(text: ''),
              _clickableLink(
                text: 'Privacy Policy',
                url: 'https://brilliant.xyz/pages/privacy-policy',
              ),
              const TextSpan(text: ' and ', style: textStyleWhite),
              _clickableLink(
                text: 'Terms and Conditions',
                url: 'https://brilliant.xyz/pages/terms-conditions',
              ),
              const TextSpan(text: ' of Noa.', style: textStyleWhite),
            ],
          ),
        ),
      ),
    );
  }
}
