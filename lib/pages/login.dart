import 'package:flutter/material.dart';
import 'package:noa/pages/pair.dart';
import 'package:noa/services/sign_in.dart';
import 'package:noa/style.dart';

Widget _LoginButton(BuildContext context, String image, Function action) {
  return GestureDetector(
    onTap: () async {
      final success = await action();
      if (success) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => PairPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      }
    },
    child: Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Image.asset(image),
    ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
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
              _LoginButton(
                context,
                'assets/sign_in_with_apple_button.png',
                SignIn().withApple,
              ),
              _LoginButton(
                context,
                'assets/sign_in_with_google_button.png',
                SignIn().withGoogle,
              ),
              _LoginButton(
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
