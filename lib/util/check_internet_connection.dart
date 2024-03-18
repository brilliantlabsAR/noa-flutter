import 'dart:io';

class CheckInternetConnectionError implements Exception {
  CheckInternetConnectionError();
}

Future<void> checkInternetConnection() async {
  try {
    final result = await InternetAddress.lookup('www.google.com');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      return;
    }
  } catch (_) {}

  return Future.error(CheckInternetConnectionError());
}
