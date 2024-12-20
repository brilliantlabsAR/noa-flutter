import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/pages/login.dart';
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
      if (ref.watch(app.model).state.current == app.State.waitForLogin) {
        switchPage(context, const LoginPage());
      }
    });

    String pairingBoxText = "";
    String pairingBoxButtonText = "";
    String tutorialText = "";
    Image pairingBoxImage = Image.asset('assets/images/charge.gif');
    bool pairingBoxButtonEnabled = false;
    bool showPairingBox = true;
    int updateProgress = ref.watch(app.model).bluetoothUploadProgress.toInt();
    String deviceName = ref.watch(app.model).deviceName;
    dynamic nextState;
    dynamic previousState;
    switch (ref.watch(app.model).state.current) {
      case app.State.chargeFrame:
        pairingBoxText = "Charge Frame for 2 hours";
        pairingBoxButtonText = "Next";
        pairingBoxButtonEnabled = false;
        showPairingBox = false;
        pairingBoxImage = Image.asset('assets/images/part1.gif');
        tutorialText = "1. To charge Frame, place Mister Power on the bridge of Frame, ensuring a firm, even fit.";
        nextState = app.State.chargeFrame2;
        previousState = app.State.chargeFrame;
        break;
      case app.State.chargeFrame2:
        pairingBoxText = "Charge Frame for 2 hours";
        pairingBoxButtonText = "Next";
        pairingBoxButtonEnabled = false;
        showPairingBox = false;
        pairingBoxImage = Image.asset('assets/images/part1.gif');
        tutorialText = "2. Plug a USB-C cable into the bottom of Mister Power. An orange light will appear on the back of Mister Power. Once charging for both Frame and Mister Power is complete, the light will turn off.";
        nextState = app.State.removeDock;
        previousState = app.State.chargeFrame;
      case app.State.removeDock:
        pairingBoxText = "Remove Dock from Frame";
        pairingBoxButtonText = "Next";
        pairingBoxButtonEnabled = false;
        showPairingBox = false;
        pairingBoxImage = Image.asset('assets/images/part2.gif');
        tutorialText = "3. Remove the Dock from Frame by gently pulling it away from the Frame.";
        nextState = app.State.readyToPair;
        previousState = app.State.chargeFrame2;
        break;
      case app.State.readyToPair:
        pairingBoxText = "Ready to pair your device";
        pairingBoxButtonText = "Next";
        pairingBoxImage = Image.asset('assets/images/part3.gif');
        pairingBoxButtonEnabled = true;
        nextState = app.State.scanning;
        previousState = app.State.removeDock;
        break;
      case app.State.scanning:
        pairingBoxText = "Bring your device close";
        pairingBoxButtonText = "Searching";
        pairingBoxImage = Image.asset('assets/images/part3.gif');
        pairingBoxButtonEnabled = false;
        break;
      case app.State.found:
        pairingBoxText = "$deviceName found";
        pairingBoxButtonText = "Pair";
        pairingBoxImage = Image.asset('assets/images/part3.gif');
        pairingBoxButtonEnabled = true;
        break;
      case app.State.connect:
      case app.State.stopLuaApp:
      case app.State.checkFirmwareVersion:
      case app.State.triggerUpdate:
        pairingBoxText = "$deviceName found";
        pairingBoxButtonText = "Connecting";
        pairingBoxImage = Image.asset('assets/images/part3.gif');
        pairingBoxButtonEnabled = false;
        break;
      case app.State.updateFirmware:
        pairingBoxText = "Updating software $updateProgress%";
        pairingBoxButtonText = "Keep your device close";
        pairingBoxImage = Image.asset('assets/images/part3.gif');
        pairingBoxButtonEnabled = false;
        break;
      case app.State.uploadMainLua:
        pairingBoxText = "Setting up Noa 50%";
        pairingBoxButtonText = "Keep your device close";
        pairingBoxImage = Image.asset('assets/images/part3.gif');
        pairingBoxButtonEnabled = false;
        break;
      case app.State.uploadGraphicsLua:
        pairingBoxText = "Setting up Noa 68%";
        pairingBoxButtonText = "Keep your device close";
        pairingBoxImage = Image.asset('assets/images/part3.gif');
        pairingBoxButtonEnabled = false;
        break;
      case app.State.uploadStateLua:
        pairingBoxText = "Setting up Noa 83%";
        pairingBoxButtonText = "Keep your device close";
        pairingBoxImage = Image.asset('assets/images/part3.gif');
        pairingBoxButtonEnabled = false;
        break;
      case app.State.requiresRepair:
        pairingBoxText = "Reset Frame";
        pairingBoxButtonText = "un-pair Frame";
        pairingBoxImage = Image.asset('assets/images/part3.gif');
        pairingBoxButtonEnabled = true;
        showPairingBox = false;
        tutorialText = "1. Make sure Frame is removed from your phone's Bluetooth settings.";
        nextState = app.State.resetFrame;
        previousState = app.State.readyToPair;
        break;
      case app.State.resetFrame:
        pairingBoxText = "Reset Frame";
        pairingBoxImage = Image.asset('assets/images/part4.gif');
        tutorialText = "2. Attach mister power and a usb-c power cable to the frame.";
        showPairingBox = false;
        pairingBoxButtonEnabled = false;
        previousState = app.State.requiresRepair;
        nextState = app.State.retryPairing;
        break;
      case app.State.retryPairing:
        pairingBoxText = "Reset Frame";
        pairingBoxButtonText = "Try again";
        pairingBoxImage = Image.asset('assets/images/part5.gif');
        tutorialText = "3. Hold the button on the back of Mister Power for 5 seconds.";
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
            aspectRatio: 0.75,
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
                          ref.watch(app.model).state.current = app.State.disconnected;
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
                    pairingBoxText,
                    style: const TextStyle(
                      fontFamily: 'SF Pro Display',
                      color: colorDark,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ), //
                  Expanded(
                    child: pairingBoxImage,
                  ),
                  // textbox
                  Padding(
                    padding:  const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                    child:  
                    Text(
                    tutorialText,
                    textAlign: TextAlign.justify,
                    style:  const TextStyle(
                      fontFamily: 'SF Pro Display',
                      color: colorDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  ),
                  if(!showPairingBox) Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // left arrow
                          Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20, bottom: 30),
                            child: GestureDetector(
                              onTap: () {
                                ref.watch(app.model).state.current = previousState;
                                switchPage(context, const PairingPage());
                              },
                              child: const Icon(
                                Icons.keyboard_arrow_left_rounded,
                                color: colorDark,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                        // right arrow
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 20, bottom: 30),
                            child: GestureDetector(
                              onTap: () {
                                ref.watch(app.model).state.current = nextState;
                                switchPage(context, const PairingPage());
                              },
                              child: const Icon(
                                Icons.keyboard_arrow_right_rounded,
                                color: colorDark,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                      ],
                  ),
                   
                 if (showPairingBox) GestureDetector(
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
