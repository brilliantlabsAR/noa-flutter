import 'package:flutter/material.dart';
import 'package:noa/pages/account.dart';
import 'package:noa/style.dart';

AppBar topTitleBar(
    BuildContext context, String title, bool darkMode, bool accountPage) {
  return AppBar(
    toolbarHeight: 84,
    automaticallyImplyLeading: false,
    backgroundColor: darkMode ? colorDark : colorWhite,
    scrolledUnderElevation: 0,
    title: Text(
      title,
      style: darkMode ? textStyleWhiteTitle : textStyleDarkTitle,
    ),
    centerTitle: false,
    titleSpacing: 42,
    actions: [
      Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(right: 42),
          child: GestureDetector(
            onTap: () {
              if (accountPage) {
                Navigator.pop(context);
              } else {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation1, animation2) =>
                        const AccountPage(),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              }
            },
            child: Icon(accountPage ? Icons.cancel : Icons.person,
                color: darkMode ? colorWhite : colorDark),
          ))
    ],
  );
}
