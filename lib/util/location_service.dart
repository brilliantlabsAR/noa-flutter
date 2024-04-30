import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:location/location.dart';
import 'package:logging/logging.dart';

final _log = Logger("Location");

LocationData? _position;

class LocationService {
  static Future<void> requestPermission() async {
    Location location = Location();

    if (await location.hasPermission() == PermissionStatus.denied) {
      _log.info("Requesting location permission from user");
      await location.requestPermission();
    }

    await location.enableBackgroundMode(enable: true);

    await location.changeSettings(
      accuracy: LocationAccuracy.balanced,
      interval: 30000,
      distanceFilter: 1000,
    );

    location.onLocationChanged.listen((position) {
      _log.info("Location updated. Accuracy: ${position.accuracy}");
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
        _position!.latitude!,
        _position!.longitude!,
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
      return Future.error(error);
    }
  }
}
