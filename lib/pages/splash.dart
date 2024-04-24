import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noa/locationService.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/pages/login.dart';
import 'package:noa/pages/noa.dart';
import 'package:noa/style.dart';
import 'package:noa/util/location_state.dart';
import 'package:noa/util/switch_page.dart';

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});
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
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _getLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(app.model).triggerEvent(app.Event.init);
      Timer(const Duration(milliseconds: 1500), () {

        if (ref.watch(app.model).pairedDevice == null) {
          switchPage(context, const LoginPage());
        } else {
          switchPage(context, const NoaPage());
        }
      });
    });

    return Scaffold(
      backgroundColor: colorWhite,
      body: Center(
        child: Image.asset('assets/images/brilliant_logo_black.png'),
      ),
    );
  }
}
