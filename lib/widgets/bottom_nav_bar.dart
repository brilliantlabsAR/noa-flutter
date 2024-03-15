import 'package:flutter/material.dart';
import 'package:noa/style.dart';
import 'package:noa/pages/noa.dart';
import 'package:noa/pages/tune.dart';
import 'package:noa/pages/hack.dart';

void switchPage(BuildContext context, Widget page) {
  Navigator.pushReplacement(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation1, animation2) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

Color getButtonColor(bool selected, bool darkMode) {
  return selected
      ? (darkMode ? widgetSelectedDarkColor : widgetSelectedLightColor)
      : (darkMode ? widgetBackgroundDarkColor : widgetBackgroundLightColor);
}

Widget BottomNavBar(BuildContext context, int selected, bool darkMode) {
  return Container(
    height: 50,
    margin: const EdgeInsets.only(left: 41, right: 42, bottom: 50),
    decoration: BoxDecoration(
      color: darkMode ? widgetBackgroundDarkColor : widgetBackgroundLightColor,
      borderRadius: const BorderRadius.all(Radius.circular(20)),
    ),
    child: Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              // switchPage(context, NoaPage(widget.bluetooth));
            },
            onHorizontalDragUpdate: (details) {
              if (selected == 0 && details.delta.dx > 8) {
                switchPage(context, TunePage());
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: getButtonColor(selected == 0, darkMode),
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              child: Center(
                child: Text(
                  "NOA",
                  style: darkMode
                      ? bottomTabTextDarkStyle
                      : bottomTabTextLightStyle,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              switchPage(context, TunePage());
            },
            onHorizontalDragUpdate: (details) {
              if (selected == 1 && details.delta.dx > 8) {
                switchPage(context, HackPage());
              } else if (selected == 1 && details.delta.dx < -8) {
                // switchPage(context, NoaPage());
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: getButtonColor(selected == 1, darkMode),
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              child: Center(
                child: Text(
                  "TUNE",
                  style: darkMode
                      ? bottomTabTextDarkStyle
                      : bottomTabTextLightStyle,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              switchPage(context, HackPage());
            },
            onHorizontalDragUpdate: (details) {
              if (selected == 2 && details.delta.dx < -8) {
                switchPage(context, TunePage());
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: getButtonColor(selected == 2, darkMode),
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              child: Center(
                child: Text(
                  "HACK",
                  style: darkMode
                      ? bottomTabTextDarkStyle
                      : bottomTabTextLightStyle,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
