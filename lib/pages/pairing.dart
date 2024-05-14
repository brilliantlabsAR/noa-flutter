import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/pages/noa.dart';
import 'package:noa/style.dart';
import 'package:noa/util/switch_page.dart';

class PairingPage extends ConsumerWidget {
  const PairingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.watch(app.model).state.current == app.State.connected ||
          ref.watch(app.model).state.current == app.State.disconnected) {
        switchPage(context, const NoaPage());
      }
    });

    String pairingBoxText = "";
    String pairingBoxButtonText = "";
    bool pairingBoxButtonEnabled = false;
    int updateProgress = ref.watch(app.model).bluetoothUploadProgress.toInt();

    switch (ref.watch(app.model).state.current) {
      case app.State.scanning:
        pairingBoxText = "Bring your device close";
        pairingBoxButtonText = "Searching";
        pairingBoxButtonEnabled = false;
        break;
      case app.State.found:
        pairingBoxText = "Frame found";
        pairingBoxButtonText = "Pair";
        pairingBoxButtonEnabled = true;
        break;
      case app.State.connect:
      case app.State.stopLuaApp:
      case app.State.checkVersion:
      case app.State.triggerUpdate:
        pairingBoxText = "Frame found";
        pairingBoxButtonText = "Connecting";
        pairingBoxButtonEnabled = false;
        break;
      case app.State.updateFirmware:
        pairingBoxText = "Updating software $updateProgress%";
        pairingBoxButtonText = "Keep your device close";
        pairingBoxButtonEnabled = false;
        break;
      case app.State.uploadMainLua:
        pairingBoxText = "Setting up Noa 50%";
        pairingBoxButtonText = "Keep your device close";
        pairingBoxButtonEnabled = false;
        break;
      case app.State.uploadGraphicsLua:
        pairingBoxText = "Setting up Noa 68%";
        pairingBoxButtonText = "Keep your device close";
        pairingBoxButtonEnabled = false;
        break;
      case app.State.uploadStateLua:
        pairingBoxText = "Setting up Noa 83%";
        pairingBoxButtonText = "Keep your device close";
        pairingBoxButtonEnabled = false;
        break;
      case app.State.requiresRepair:
        pairingBoxText = "Un-pair Frame first";
        pairingBoxButtonText = "Try again";
        pairingBoxButtonEnabled = true;
        break;
    }

    return Scaffold(
      backgroundColor: colorDark,
      appBar: AppBar(
        backgroundColor: colorDark,
        title: Image.asset('assets/images/brilliant_logo.png'),
      ),
      body: Column(
        children: [
          const Expanded(
            child: Center(
              child: Text("Setup your device", style: textStyleLightHeading),
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
                          ref
                              .read(app.model)
                              .triggerEvent(app.Event.cancelPressed);
                        },
                        child: const Icon(
                          Icons.cancel,
                          color: colorDark,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    pairingBoxText,
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      color: colorDark,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ), //
                  Expanded(
                    child: Image.asset('assets/images/temp_frame.png'),
                  ),
                  GestureDetector(
                    onTap: () {
                      ref.read(app.model).triggerEvent(app.Event.buttonPressed);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: pairingBoxButtonEnabled ? colorDark : colorLight,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(20)),
                      ),
                      height: 50,
                      margin: const EdgeInsets.only(
                          left: 31, right: 31, bottom: 28),
                      child: Center(
                        child: Text(
                          pairingBoxButtonText,
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
