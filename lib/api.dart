import 'package:noa/util/check_internet_connection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NoaApiNoAuthTokenError implements Exception {
  NoaApiNoAuthTokenError();
}

class NoaApiServerError implements Exception {
  int serverErrorCode;
  NoaApiServerError(this.serverErrorCode);

  @override
  String toString() {
    return "$serverErrorCode";
  }
}

enum NoaApiAuthProvider {
  google('google'),
  apple('apple'),
  discord('discord');

  const NoaApiAuthProvider(this.value);
  final String value;
}

class NoaApi {
  static Future<void> obtainAuthToken(
      String idToken, NoaApiAuthProvider authProvider) async {
    try {
      await checkInternetConnection();

      final response = await http.post(
        Uri.parse('https://api.brilliant.xyz/noa/signin'),
        body: {
          'id_token': idToken,
          'social_type': authProvider.value,
          'app': 'flutter',
        },
      );

      if (response.statusCode != 200) {
        throw NoaApiServerError(response.statusCode);
      }

      final decoded = jsonDecode(response.body);

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('userToken', decoded['token']);
    } catch (error) {
      return Future.error(error);
    }
  }

  static Future<String> loadSavedAuthToken() async {
    final preferences = await SharedPreferences.getInstance();
    final authToken = preferences.getString('userToken');
    if (authToken == null) {
      return Future.error(NoaApiNoAuthTokenError());
    }
    return authToken;
  }

  static Future<void> deleteSavedAuthToken() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('userToken');
  }

  static Future<dynamic> getProfile() async {
    try {
      await checkInternetConnection();
      final authToken = await loadSavedAuthToken();
      final response = await http.get(
        Uri.parse('https://api.brilliant.xyz/noa/profile_info'),
        headers: {
          "Authorization": authToken,
        },
      );
      if (response.statusCode != 200) {
        throw NoaApiServerError(response.statusCode);
      }
      return jsonDecode(response.body);
    } catch (error) {
      return Future.error(Exception(error));
    }
  }
}
