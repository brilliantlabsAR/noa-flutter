import 'dart:io';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:logging/logging.dart';

final _log = Logger("Location");

Position? _position;

class Location {
  static Future<void> requestPermission() async {
    if (await Geolocator.checkPermission() == LocationPermission.denied) {
      _log.info("Requesting location permission from user");
      await Geolocator.requestPermission();
    }

    late LocationSettings locationSettings;

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
