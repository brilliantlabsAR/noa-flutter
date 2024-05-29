import 'dart:io';
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final _log = Logger("Foreground task");

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(NoaForegroundTask());
}

class NoaForegroundTask extends TaskHandler {
  SendPort? _sendPort;

  @override
  void onStart(DateTime timestamp, SendPort? sendPort) async {
    _sendPort = sendPort;
    _log.info("Started");
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    sendPort?.send("connect");
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) async {
    _log.info("Destroyed");
    FlutterForegroundTask.stopService();
  }

  // @override
  // void onNotificationButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    _sendPort?.send('onNotificationPressed');
  }
}

class ForegroundTask {
  void init() async {
    await _requestPermissionForAndroid();
    _initForegroundTask();
    await _startForegroundTask();
  }

  Future<void> _requestPermissionForAndroid() async {
    if (!Platform.isAndroid) {
      return;
    }
    final NotificationPermission notificationPermissionStatus =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermissionStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        visibility: NotificationVisibility.VISIBILITY_PRIVATE,
        isSticky: false,
        foregroundServiceType: AndroidForegroundServiceType.CONNECTED_DEVICE,
        channelId: 'noa_service',
        channelName: 'Listening...',
        channelDescription: 'Noa is listening for your questions',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
          backgroundColor: Color.fromARGB(255, 232, 232, 232),
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: true,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 10000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<bool> _startForegroundTask() async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        notificationTitle: 'Noa',
        notificationText: 'Listening...',
        callback: startCallback,
      );
    }
  }

  static Future<bool> stopForegroundTask() {
    return FlutterForegroundTask.stopService();
  }
}
