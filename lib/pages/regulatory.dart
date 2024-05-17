import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:noa/style.dart';
import 'package:noa/widgets/top_title_bar.dart';

Widget _accountInfoText(String title, String detail) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 42),
    child: Column(
      children: [
        Text(title, style: textStyleLightSubHeading),
        Text(detail, style: textStyleDarkTitle),
      ],
    ),
  );
}

Widget _linkedFooterText(String text, bool redText, Function action) {
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: GestureDetector(
      onTap: () => action(),
      child: Text(
        text,
        style: redText ? textStyleRed : textStyleDark,
      ),
    ),
  );
}

class RegulatoryPage extends ConsumerWidget {
  const RegulatoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
        backgroundColor: colorWhite,
        appBar: topTitleBar(context, 'REGULATORY', false, true),
        body: const Padding(
          padding: EdgeInsets.only(left: 42, right: 42),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Text("Country", style: textStyleLightSubHeading),
                  ),
                  Expanded(
                    child: Text("Label", style: textStyleLightSubHeading),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Text("United States", style: textStyleDark),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("FCC ID: 2BFWB-F1", style: textStyleDark),
                        Text(
                            "This device complies with Part 15 of the FCC Rules. Operation is subject to the following two conditions: (1)This device may not cause harmful interference, and (2)This device must accept any interference received, including interference that may cause undesired operation",
                            style: textStyleDark),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ));
  }
}
