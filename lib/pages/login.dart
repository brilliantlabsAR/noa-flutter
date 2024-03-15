import 'package:flutter/material.dart';
import 'package:noa/bluetooth.dart';
import 'package:noa/pages/pair.dart';
import 'package:noa/style.dart';

class LoginPage extends StatefulWidget {
  final FrameBluetooth bluetooth;
  const LoginPage({super.key, required this.bluetooth});

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
      body: Center(
        child: GestureDetector(
          child: Text("Login"),
          onTap: () => Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation1, animation2) =>
                  PairPage(bluetooth: widget.bluetooth),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          ),
        ),
      ),
    );
  }
}
