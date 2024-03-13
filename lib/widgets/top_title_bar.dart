import 'package:flutter/material.dart';
import 'package:noa/style.dart';

AppBar TopTitleBar(BuildContext context, String title, bool darkMode) {
  return AppBar(
    backgroundColor: darkMode ? backgroundDarkColor : backgroundLightColor,
    title: Text(
      title,
      style: darkMode ? darkTitleTextStyle : lightTitleTextStyle,
    ),
    centerTitle: false,
    titleSpacing: 42,
    actions: [
      Container(
        width: 28,
        height: 28,
        margin: EdgeInsets.only(right: 42),
        child: Icon(Icons.person,
            color: darkMode ? textLightColor : textDarkColor),
      )
    ],
  );
}
