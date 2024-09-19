import 'package:flutter/material.dart';
import 'package:noa/style.dart';
import 'package:noa/pages/noa.dart';
import 'package:noa/pages/tune.dart';
import 'package:noa/pages/hack.dart';
import 'package:noa/util/switch_page.dart';

Color getButtonColor(bool selected, bool darkMode) {
  return selected
      ? (darkMode ? colorWhite : colorDark)
      : (darkMode ? colorLight : colorLight);
}

Widget bottomNavBar(BuildContext context, int selected, bool darkMode) {
  return Container(
    height: 50,
    margin: const EdgeInsets.only(left: 42, right: 42, bottom: 50),
    decoration: BoxDecoration(
      color: darkMode ? colorLight : colorLight,
      borderRadius: const BorderRadius.all(Radius.circular(20)),
    ),
    child: Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              switchPage(context, const NoaPage());
            },
            onHorizontalDragUpdate: (details) {
              if (selected == 0 && details.delta.dx > 8) {
                switchPage(context, const TunePage());
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: getButtonColor(selected == 0, darkMode),
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              child: Center(
                child: Text(
                  "CHAT",
                  style: darkMode ? textStyleDarkWidget : textStyleWhiteWidget,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              switchPage(context, const TunePage());
            },
            onHorizontalDragUpdate: (details) {
              if (selected == 1 && details.delta.dx > 8) {
                switchPage(context, const HackPage());
              } else if (selected == 1 && details.delta.dx < -8) {
                switchPage(context, const NoaPage());
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: getButtonColor(selected == 1, darkMode),
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              child: Center(
                child: Text(
                  "HACK",
                  style: darkMode ? textStyleDarkWidget : textStyleWhiteWidget,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              switchPage(context, const HackPage());
            },
            onHorizontalDragUpdate: (details) {
              if (selected == 2 && details.delta.dx < -8) {
                switchPage(context, const TunePage());
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: getButtonColor(selected == 2, darkMode),
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              child: Center(
                child: Text(
                  "LOG",
                  style: darkMode ? textStyleDarkWidget : textStyleWhiteWidget,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}