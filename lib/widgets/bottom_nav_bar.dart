import 'package:flutter/material.dart';
import 'package:noa/style.dart';
import 'package:noa/pages/noa.dart';
import 'package:noa/pages/tune.dart';
import 'package:noa/pages/hack.dart';

Widget BottomNavBar(BuildContext context, int selected) {
  return Container(
    height: 50,
    margin: EdgeInsets.only(left: 41, right: 42, bottom: 50),
    decoration: const BoxDecoration(
      color: lightWidget,
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
    child: Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation1, animation2) => NoaPage(),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: selected == 0 ? darkWidget : lightWidget,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              child: const Center(
                  child: Text(
                "NOA",
                style: tabsTextStyle,
              )),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation1, animation2) => TunePage(),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: selected == 1 ? darkWidget : lightWidget,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              child: const Center(
                  child: Text(
                "TUNE",
                style: tabsTextStyle,
              )),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation1, animation2) => HackPage(),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: selected == 2 ? darkWidget : lightWidget,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
              child: const Center(
                child: Text(
                  "HACK",
                  style: tabsTextStyle,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
