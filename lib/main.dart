import 'package:flutter/material.dart';
import 'package:noa/bluetooth.dart';
import 'package:noa/pages/login.dart';
import 'package:noa/pages/noa.dart';

void main() {
  runApp(MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  FrameBluetooth bluetooth = FrameBluetooth();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: NoaPage(bluetooth: bluetooth),
    );
  }
}
