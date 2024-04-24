import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logging/logging.dart';

final _log = Logger("Location");

class Location {
  static Future<void> requestPermission() async {
    if (await Geolocator.checkPermission() == LocationPermission.denied) {
      _log.info("Requesting location permission from user");
      await Geolocator.requestPermission();
    }
  }

  static Future<String> getAddress() async {
    String appendComma(String string) {
      if (string != "") {
        string += ", ";
      }
      return string;
    }

    try {
      if (await Geolocator.isLocationServiceEnabled() == false) {
        _log.warning("Service is disabled in phone settings");
        return "";
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _log.warning("User has denied location");
        return "";
      }

      Position position = await Geolocator.getCurrentPosition();

      _log.info(
          "Got co-ordinates: Latitude: ${position.latitude}, longitude: ${position.longitude}, accuracy: ${position.accuracy}m");

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String returnString = "";

      if (placemarks[0].name != null) {
        returnString += placemarks[0].name!;
      }

      if (placemarks[0].street != null &&
          placemarks[0].street != placemarks[0].name) {
        returnString = appendComma(returnString);
        returnString += placemarks[0].street!;
      }

      if (placemarks[0].subLocality != null) {
        returnString = appendComma(returnString);
        returnString += placemarks[0].subLocality!;
      }

      if (placemarks[0].locality != null) {
        returnString = appendComma(returnString);
        returnString += placemarks[0].locality!;
      }

      if (placemarks[0].postalCode != null) {
        returnString = appendComma(returnString);
        returnString += placemarks[0].postalCode!;
      }

      if (placemarks[0].country != null) {
        returnString = appendComma(returnString);
        returnString += placemarks[0].country!;
      }

      return returnString;
    } catch (error) {
      return Future.error(error);
    }
  }
}
