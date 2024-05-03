import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

class AppLog extends ChangeNotifier {
  String app = "";
  String bluetooth = "";

  AppLog() {
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((log) {
      if (kDebugMode) {
        print('${log.level.name} - ${log.loggerName}: ${log.message}');
      }
      if (log.loggerName == "Bluetooth") {
        bluetooth += "${log.level.name} - ${log.message}\n";
      } else {
        app += "${log.level.name} - ${log.loggerName}: ${log.message}\n";
      }
      // TODO limit the size of this string
      notifyListeners();
    });
  }
}

final appLog = ChangeNotifierProvider<AppLog>((ref) => AppLog());
