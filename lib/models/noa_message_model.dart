import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';

class NoaMessage {
  String message;
  String from;
  DateTime time;

  NoaMessage({
    required this.message,
    required this.from,
    required this.time,
  });
}


// TODO remove this once no longer needed
class NoaMessageModel extends ChangeNotifier {

  StreamController<bool> gpsStatusController = StreamController<bool>();
  StreamController<bool> bluetoothController = StreamController<bool>();
  bool ispopUpShowing = false;
  void _listenToGPSStatusChanges() async {
    gpsStatusController.add(await Geolocator.isLocationServiceEnabled());


    var subscription = FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      print(state);
      bluetoothController.add(state == BluetoothAdapterState.on);
    });

    try {
      Geolocator.getPositionStream().listen((position) {
        // Do something when the position changes
      });

      StreamSubscription<ServiceStatus> serviceStatusStream = Geolocator
          .getServiceStatusStream().listen(
              (ServiceStatus status) {
            gpsStatusController.add(status == ServiceStatus.enabled);
          });
    }
    catch(ex){
      print(ex);
    }
  }


  List<NoaMessage> messages = [];

  NoaMessageModel() {
    addMessage(
      "I'm looking for some new sneakers. Could you help me find some?",
      "User",
      DateTime.now(),
    );
    addMessage(
      "Sure! What kind of style are you looking for?",
      "Noa",
      DateTime.now().add(const Duration(seconds: 2)),
    );
    addMessage(
      "Maybe something like these?",
      "User",
      DateTime.now().add(const Duration(seconds: 4)),
    );
    addMessage(
      "Those look like some nice designer kicks! If you're on a budget check these out from Camperlab, or if you want to splash out, Balenciaga have something similar.",
      "Noa",
      DateTime.now().add(const Duration(seconds: 5)),
    );
    addMessage(
      "What's a good color to go for?",
      "User",
      DateTime.now().add(const Duration(seconds: 2938)),
    );
    addMessage(
      "You can never go wrong with a classic blue sneaker. Alternatively, light green seems to be in style right now.",
      "Noa",
      DateTime.now().add(const Duration(seconds: 2941)),
    );
  }

  void addMessage(
    String message,
    String from,
    DateTime time,
  ) {
    messages.add(NoaMessage(message: message, from: from, time: time));
    notifyListeners();
  }
}
