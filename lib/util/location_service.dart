import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:location/location.dart';
import 'package:logging/logging.dart';

final _log = Logger("Location");

class LocationService {
  static Future<void> requestPermission() async {
    Location location = Location();

    if (await location.hasPermission() == PermissionStatus.denied) {
      _log.info("Requesting location permission from user");
      await location.requestPermission();
    }

    location.enableBackgroundMode(enable: true);
  }

  static Future<String> getAddress() async {
    String appendComma(String string) {
      if (string != "") {
        string += ", ";
      }
      return string;
    }

    try {
      Location location = Location();

      if (await location.serviceEnabled() == false) {
        _log.warning("Service is disabled in phone settings");
        return "";
      }

      PermissionStatus permission = await location.hasPermission();
      if (permission == PermissionStatus.denied ||
          permission == PermissionStatus.deniedForever) {
        _log.warning("User has denied location");
        return "";
      }

      LocationData position = await location.getLocation();

      _log.info(
          "Got co-ordinates: Latitude: ${position.latitude}, longitude: ${position.longitude}, accuracy: ${position.accuracy}m");

      geocoding.Placemark placemark = (await geocoding.placemarkFromCoordinates(
              position.latitude!, position.longitude!))
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
