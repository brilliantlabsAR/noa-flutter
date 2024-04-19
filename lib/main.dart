import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:noa/bluetooth.dart';
import 'package:noa/models/noa_message_model.dart';
import 'package:noa/pages/splash.dart';

final messages = ChangeNotifierProvider<NoaMessageModel>((ref) {
  return NoaMessageModel();
});

void main() async {
  await dotenv.load(); // Load environment variables

  Logger.root.level = Level.FINER;
  Logger.root.onRecord.listen((record) {
    if (kDebugMode) {
      print('${record.level.name} - ${record.loggerName}: ${record.message}');
    }
  });

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
