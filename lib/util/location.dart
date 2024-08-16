import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:logging/logging.dart';

final _log = Logger("Location");

Position? _position;

class Location {
  static Future<void> requestPermission(BuildContext context) async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      _log.info("Requesting location permission from user");

      if (Platform.isAndroid) {
        Completer completer = Completer();
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text("Allow location?"),
              content: const Text(
                  "Noa can give responses and recommendations based on your current location even when the app is in the background. This is optional and can be turned off at anytime from your system settings"),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    completer.complete();
                  },
                  child: const Text('Okay'),
                )
              ],
            ),
          );
        }
        await completer.future;
      }

      await Geolocator.requestPermission();
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _log.info("Permission rejected by user. Won't use location");
        return;
      }
    }

    startLocationStream();
  }

static void startLocationStream() async {
    late LocationSettings locationSettings;
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _log.info("location permission not present. Won't use location");
      return;
    }

    if (Platform.isIOS) {
      locationSettings = AppleSettings(
          accuracy: LocationAccuracy.low,
          pauseLocationUpdatesAutomatically: true);
    }

    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.low,
          intervalDuration: const Duration(minutes: 5));
    }

    Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position? position) {
      _log.fine("Location updated. Accuracy: ${position!.accuracy}");
      _position = position;
    });
  }

  static Future<String> getAddress() async {
    String appendComma(String string) {
      if (string != "") {
        string += ", ";
      }
      return string;
    }

    try {
      if (_position == null) {
        return "";
      }

      _log.info(
          "Using co-ordinates: Latitude: ${_position!.latitude}, longitude: ${_position!.longitude}");

      geocoding.Placemark placemark = (await geocoding.placemarkFromCoordinates(
        _position!.latitude,
        _position!.longitude,
      ))
          .first;

      String returnString = "";

      if (placemark.name != null) {
        returnString += placemark.name!;
      }

      if (placemark.street != null && placemark.street != placemark.name) {
        returnString = appendComma(returnString);
        returnString += placemark.street!;
      }

      if (placemark.subLocality != null) {
        returnString = appendComma(returnString);
        returnString += placemark.subLocality!;
      }

      if (placemark.locality != null) {
        returnString = appendComma(returnString);
        returnString += placemark.locality!;
      }

      if (placemark.postalCode != null) {
        returnString = appendComma(returnString);
        returnString += placemark.postalCode!;
      }

      if (placemark.country != null) {
        returnString = appendComma(returnString);
        returnString += placemark.country!;
      }

      return returnString;
    } catch (error) {
      _log.warning("Could not get location: $error");
      return Future.error(error);
    }
  }
}
