import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noa/api.dart';
import 'package:noa/pages/pairing.dart';
import 'package:noa/style.dart';
import 'package:noa/util/alert_dialog.dart';
import 'package:noa/util/check_internet_connection.dart';
import 'package:noa/util/sign_in.dart';
import 'package:noa/util/switch_page.dart';
import 'package:permission_handler/permission_handler.dart';

import '../locationService.dart';
import '../util/location_state.dart';

Widget _loginButton(
  BuildContext context,
  WidgetRef ref,
  String image,
  Function action,
) {
  return GestureDetector(
    onTap: () async {
      try {


        await action();

        if (context.mounted) {
          switchPage(context, const PairingPage());
        }
      } on CheckInternetConnectionError catch (_) {
        if (context.mounted) {
          alertDialog(
            context,
            "Couldn't Sign In",
            "Noa requires an internet connection",
          );
        }
      } on NoaApiServerError catch (error) {
        if (context.mounted) {
          alertDialog(
            context,
            "Couldn't Sign In",
            "Server responded with an error: $error",
          );
        }
      } catch (_) {}
    },
    child: Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Image.asset(image),
    ),
  );
}

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  Future<void> _getLocation() async {
    try {
      Position position = await LocationService().getCurrentLocation();
      String? address =
      await LocationService().getAddressFromCoordinates(position);

      updateName(address?? "not Specified");

      print(address);
    } catch (e) {
      print("Error fetching location: $e");
    }
  }
  Future<void> _requestPermissions() async {

    try {
      // Permissions to request
      List<Permission> permissions = [
        Permission.location,
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.storage,
        Permission.mediaLibrary,
      ];

      // Request permissions
      await permissions.request();
    }
    catch(ex){
      print(ex.toString());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    _requestPermissions();
    _getLocation();
    // Skip this screen if already signed in
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await NoaApi.loadSavedAuthToken();
        if (context.mounted) {
          switchPage(context, const PairingPage());
        }
      } catch (_) {}
    });
    // Otherwise show the page
    return Scaffold(
      backgroundColor: colorDark,
      appBar: AppBar(
        backgroundColor: colorDark,
        title: Image.asset('assets/images/brilliant_logo.png'),
      ),
      body: Column(
        children: [
          Expanded(child: Image.asset('assets/images/noa_logo.png')),
          Column(
            children: [
              _loginButton(
                context,
                ref,
                'assets/images/sign_in_with_apple_button.png',
                SignIn().withApple,
              ),
              _loginButton(
                context,
                ref,
                'assets/images/sign_in_with_google_button.png',
                SignIn().withGoogle,
              ),
              _loginButton(
                context,
                ref,
                'assets/images/sign_in_with_discord_button.png',
                SignIn().withDiscord,
              ),
            ],
          )
        ],
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.only(bottom: 48, top: 48),
        child: Text(
            // TODO add links here
            "Privacy Policy and Terms and Conditions of Noa",
            textAlign: TextAlign.center,
            style: textStyleWhite),
      ),
    );
  }
}
