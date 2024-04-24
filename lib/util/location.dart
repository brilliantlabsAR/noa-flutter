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

      Placemark placemark = (await placemarkFromCoordinates(
              position.latitude, position.longitude))
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
      return Future.error(error);
    }
  }
}
