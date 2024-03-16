import 'package:flutter/material.dart';
import 'package:noa/pages/pair.dart';
import 'package:noa/services/sign_in.dart';
import 'package:noa/style.dart';
import 'package:noa/widgets/alert_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _gotoPairingScreen(BuildContext context) {
  Navigator.pushReplacement(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation1, animation2) => const PairPage(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

Widget _loginButton(BuildContext context, String image, Function action) {
  return GestureDetector(
    onTap: () async {
      try {
        final token = await action();
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString('userToken', token);
        if (context.mounted) {
          _gotoPairingScreen(context);
        }
      } on SignInNoConnectionError catch (_) {
        if (context.mounted) {
          alertDialog(
            context,
            "Couldn't Sign In",
            "Noa requires an internet connection",
          );
        }
      } on SignInServerError catch (error) {
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

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Skip this screen if already signed in
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getString('userToken') != null) {
        if (context.mounted) {
          _gotoPairingScreen(context);
        }
      }
    });
    // Otherwise show the page
    return Scaffold(
      backgroundColor: backgroundDarkColor,
      appBar: AppBar(
        backgroundColor: backgroundDarkColor,
        title: Image.asset('assets/brilliant_logo.png'),
      ),
      body: Column(
        children: [
          Expanded(child: Image.asset('assets/noa_logo.png')),
          Column(
            children: [
              _loginButton(
                context,
                'assets/sign_in_with_apple_button.png',
                SignIn().withApple,
              ),
              _loginButton(
                context,
                'assets/sign_in_with_google_button.png',
                SignIn().withGoogle,
              ),
              _loginButton(
                context,
                'assets/sign_in_with_discord_button.png',
                SignIn().withDiscord,
              ),
            ],
          )
        ],
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.only(bottom: 48, top: 48),
        child: Text(
          "Privacy Policy and Terms and Conditions of Noa",
          textAlign: TextAlign.center,
          style: TextStyle(color: textLightColor),
        ),
      ),
    );
  }
}
