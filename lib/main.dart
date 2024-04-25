import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:noa/bluetooth.dart';
import 'package:noa/pages/splash.dart';
import 'package:noa/util/location.dart';

final globalPageStorageBucket = PageStorageBucket();
String globalAppLog = "";
String globalBluetoothLog = "";

void main() async {
  await dotenv.load(); // Load environment variables

  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    if (kDebugMode) {
      print('${record.level.name} - ${record.message}');
    }

    if (record.loggerName == "Bluetooth") {
      globalBluetoothLog +=
          "${record.level.name} - ${record.loggerName}: ${record.message}\n";
    } else {
      globalAppLog +=
          "${record.level.name} - ${record.loggerName}: ${record.message}\n";
    }

    // TODO limit the size of this string
  });

  await Location.requestPermission();
  BrilliantBluetooth.init();
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashPage(),
    );
  }
}
