import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:noa/bluetooth.dart';
import 'package:noa/models/bluetooth_connection_model.dart';
import 'package:noa/models/noa_message_model.dart';
import 'package:noa/pages/login.dart';

final bluetooth = ChangeNotifierProvider<BluetoothConnectionModel>((ref) {
  return BluetoothConnectionModel();
});

final messages = ChangeNotifierProvider<NoaMessageModel>((ref) {
  return NoaMessageModel();
});

void main() async {
  await dotenv.load();
  BrilliantBluetooth.init();
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}
