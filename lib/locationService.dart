import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;

  LocationService._internal();

  // Function to get the current location
  Future<Position> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      print("Error getting current location: $e");
      return Future.error("Error getting current location");
    }
  }

  // Function to get the address from coordinates
  Future<String?> getAddressFromCoordinates(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude,);
      Placemark place = placemarks[0];
      return "${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
    } catch (e) {
      print("Error getting address from coordinates: $e");
      return Future.error("Error getting address from coordinates");
    }
  }


  Future<String?> getAddressFromCoordinatesApi(double latitude, double longitude) async {
    const apiKey = 'Enter Api Key';
    final apiUrl =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$apiKey';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);

        if (decodedResponse['status'] == 'OK') {
          // Extract formatted address from the results
          return decodedResponse['results'][0]['formatted_address'];
        } else {
          // Handle error case
          print('Error: ${decodedResponse['status']}');
          return null;
        }
      } else {
        // Handle HTTP error
        print('HTTP error ${response.statusCode}');
        return null;
      }
    } catch (e) {
      // Handle other errors
      print('Error: $e');
      return null;
    }
  }
}