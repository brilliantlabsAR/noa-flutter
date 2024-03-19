import 'dart:async';
import 'package:flutter/material.dart';
import 'package:noa/bluetooth.dart';
import 'package:noa/pages/noa.dart';
import 'package:noa/style.dart';
import 'package:noa/util/switch_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DialogState {
  searching,
  found,
  connecting,
  invalid,
  updating,
}

class PairPage extends StatefulWidget {
  const PairPage({super.key});

  @override
  State<PairPage> createState() => _PairPageState();
}

class _PairPageState extends State<PairPage> {
  late BrilliantScannedDevice _nearestDevice;

  final _scanStreamController = StreamController<BrilliantScannedDevice>();
  final _connectionStreamController = StreamController<BrilliantDevice>();

  DialogState _dialogState = DialogState.searching;
  late String _connectionBoxText;
  late String _connectionBoxButtonText;
  late bool _connectionBoxButtonEnabled;

  _setDialogState(DialogState newState) {
    _dialogState = newState;
    if (mounted) {
      setState(() {
        switch (newState) {
          case DialogState.searching:
            _connectionBoxText = "Bring your device close";
            _connectionBoxButtonText = "Searching";
            _connectionBoxButtonEnabled = false;
            break;
          case DialogState.found:
            _connectionBoxText = "Frame found";
            _connectionBoxButtonText = "Pair";
            _connectionBoxButtonEnabled = true;
            break;
          case DialogState.connecting:
            _connectionBoxText = "Frame found";
            _connectionBoxButtonText = "Connecting";
            _connectionBoxButtonEnabled = false;
            break;
          case DialogState.invalid:
            _connectionBoxText = "Un-pair Frame first";
            _connectionBoxButtonText = "Try again";
            _connectionBoxButtonEnabled = true;
          case DialogState.updating:
            _connectionBoxText = "Updating";
            _connectionBoxButtonText = "Keep your device close";
            _connectionBoxButtonEnabled = false;
            break;
        }
      });
    }
  }

  _scanListener() {
    _scanStreamController.stream
        .where((event) => event.rssi > -55)
        .timeout(const Duration(seconds: 2), onTimeout: (_) {
      if (_dialogState == DialogState.found) {
        _setDialogState(DialogState.searching);
      }
    }).listen((scanResult) {
      if (_dialogState == DialogState.searching) {
        _setDialogState(DialogState.found);
        _nearestDevice = scanResult;
        print("Found device: ${scanResult.device.remoteId.toString()}");
      }
    });
  }

  _startScanning() async {
    // Load previous paired device if there is one
    final preferences = await SharedPreferences.getInstance();
    String? deviceUuid = preferences.getString('pairedDeviceUuid');

    // If there is, attempt to reconnect whenever the device comes into range
    if (deviceUuid != null) {
      if (mounted) {
        switchPage(context, const NoaPage());
      }
    }

    // Otherwise scan for a new device
    else {
      BrilliantBluetooth.scan(_scanStreamController);
    }
  }

  _connectionListener() {
    _connectionStreamController.stream.listen((device) async {
      print(device.name);
      print(device.state);

      if (device.state == BrilliantConnectionState.connected) {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString('pairedDeviceUuid', device.uuid);
        if (mounted) {
          switchPage(context, const NoaPage());
        }
      }

      if (device.state == BrilliantConnectionState.invalid) {
        _setDialogState(DialogState.invalid);
      }
    });
  }

  @override
  void initState() {
    _setDialogState(DialogState.searching);
    _scanListener();
    _connectionListener();
    _startScanning();
    super.initState();
  }

  @override
  void dispose() {
    BrilliantBluetooth.stopScan();
    _scanStreamController.close();
    _connectionStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ///
    });
    return Scaffold(
      backgroundColor: colorDark,
      appBar: AppBar(
        backgroundColor: colorDark,
        title: Image.asset('assets/brilliant_logo.png'),
      ),
      body: Column(
        children: [
          const Expanded(
            child: Center(
              child: Text("Setup you device", style: textStyleLightHeading),
            ),
          ),
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              margin: const EdgeInsets.only(bottom: 22, left: 11, right: 11),
              decoration: const BoxDecoration(
                color: colorWhite,
                borderRadius: BorderRadius.all(Radius.circular(42)),
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20, right: 20),
                      child: GestureDetector(
                        onTap: () {
                          switchPage(context, const NoaPage());
                        },
                        child: const Icon(
                          Icons.cancel,
                          color: colorDark,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    _connectionBoxText,
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      color: colorDark,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ), //
                  Expanded(
                    child: Image.asset('assets/temp_frame.png'),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (_dialogState == DialogState.found) {
                        _setDialogState(DialogState.connecting);
                        BrilliantBluetooth.stopScan();
                        BrilliantBluetooth.connect(
                          _nearestDevice,
                          _connectionStreamController,
                        );
                      }
                      if (_dialogState == DialogState.invalid) {
                        _setDialogState(DialogState.searching);
                        _startScanning();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _connectionBoxButtonEnabled
                            ? colorDark
                            : colorLight,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(20)),
                      ),
                      height: 50,
                      margin: const EdgeInsets.only(
                          left: 31, right: 31, bottom: 28),
                      child: Center(
                        child: Text(
                          _connectionBoxButtonText,
                          style: textStyleWhiteWidget,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
