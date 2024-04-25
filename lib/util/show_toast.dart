import 'package:flutter/material.dart';

void showToast(String message, BuildContext context) {
  final scaffold = ScaffoldMessenger.of(context);
  scaffold.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 1500),
      margin: const EdgeInsets.only(left: 42, right: 42, bottom: 20),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      padding: const EdgeInsets.all(7),
      content: Center(child: Text(message)),
    ),
  );
}
