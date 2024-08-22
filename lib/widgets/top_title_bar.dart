import 'package:flutter/material.dart';
import 'package:noa/pages/home.dart';
import 'package:noa/pages/account.dart';
import 'package:noa/style.dart';

AppBar topTitleBar(BuildContext context, String title, bool darkMode, bool accountPage) {
  return AppBar(
    toolbarHeight: 84,
    automaticallyImplyLeading: false,
    backgroundColor: darkMode ? colorDark : colorWhite,
    scrolledUnderElevation: 0,
    title: Text(
      title,
      style: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w300,
        color: darkMode ? colorWhite : colorDark,
      ),
    ),
    centerTitle: false,
    titleSpacing: 16,
    actions: Navigator.of(context).canPop()
        ? [
            Container(
              margin: EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.arrow_back, color: Colors.black, size: 18),
                label: Text('Back', style: TextStyle(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.black, width: 1),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ]
        : null,
  );
}