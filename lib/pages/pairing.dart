import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/pages/noa.dart';
import 'package:noa/style.dart';
import 'package:noa/util/alert_dialog.dart';
import 'package:noa/util/switch_page.dart';

class PairingPage extends ConsumerWidget {
  const PairingPage({super.key});


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // TODO can we leave the page earlier?
      // Leave once done
      if (ref.watch(app.model).state.current == app.State.connected ||
          ref.watch(app.model).state.current == app.State.disconnected) {
        switchPage(context, const NoaPage());
      }

    });
    final gpsStatus = ref.watch(app.model).gpsStatusController.stream;
    final bluetoothStatus = ref.watch(app.model).bluetoothController.stream;

    // if (!gpsStatus.h || !bluetoothStatus) {
    //   WidgetsBinding.instance?.addPostFrameCallback((_) {
    //     showDialog(
    //       context: context,
    //       builder: (BuildContext context) {
    //         return AlertDialog(
    //           title: Text('GPS or Bluetooth Disabled'),
    //           content: Text('Please enable GPS and Bluetooth to use this app.'),
    //           actions: <Widget>[
    //             TextButton(
    //               onPressed: () {
    //                 Navigator.of(context).pop();
    //               },
    //               child: Text('OK'),
    //             ),
    //           ],
    //         );
    //       },
    //     );
    //   });
    // }




    String pairingBoxText = "";
    String pairingBoxButtonText = "";
    bool pairingBoxButtonEnabled = false;

    switch (ref.watch(app.model).state.current) {
      case app.State.init:
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
      case app.State.sendBreak:
      case app.State.checkVersion:
        pairingBoxText = "Frame found";
        pairingBoxButtonText = "Connecting";
        pairingBoxButtonEnabled = false;
        break;
      case app.State.updatingFirmware:
        pairingBoxText = "Updating software";
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
      case app.State.connected:
        break;
      case app.State.disconnected:
        break;
    }

    return Scaffold(
      backgroundColor: colorDark,
      appBar: AppBar(
        backgroundColor: colorDark,
        title: Image.asset('assets/images/brilliant_logo.png'),
      ),
      body:


      Column(
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

          StreamBuilder<bool>(
            stream: ref.watch(app.model).bluetoothController.stream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {

                bool status = snapshot.data ?? false;
                if(!status)
                {



                  WidgetsBinding.instance?.addPostFrameCallback((_) {
                    alertDialog(
                      context,
                      "Bluetooth is disabled",
                      "Please turn on Bluetooth",
                    );});
                }
                return SizedBox() ;
              } else {
                return SizedBox(); // Return an empty SizedBox while waiting for the GPS or Bluetooth status to be enabled
              }
            },),
          StreamBuilder<bool>(
            stream: ref.watch(app.model).gpsStatusController.stream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {

                bool status = snapshot.data ?? false;
               if(!status)
                 {
                 WidgetsBinding.instance?.addPostFrameCallback((_) {
                   alertDialog(
                     context,
                     "Gps is disabled",
                     "Please turn on Gps",
                   );});
                 }
                return SizedBox() ;
              } else {
                return SizedBox(); // Return an empty SizedBox while waiting for the GPS or Bluetooth status to be enabled
              }
            },),
        ],
      ),
    );
  }
}
