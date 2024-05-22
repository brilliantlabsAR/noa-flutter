import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:noa/style.dart';
import 'package:noa/widgets/top_title_bar.dart';

Widget _regulationEntry(String country, Widget body) {
  return Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(country, style: textStyleDark),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [body],
          ),
        ),
      ],
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
        body: Padding(
          padding: const EdgeInsets.only(left: 42, right: 42),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child:
                              Text("Country", style: textStyleLightSubHeading),
                        ),
                        Expanded(
                          child: Text("Label", style: textStyleLightSubHeading),
                        ),
                      ],
                    ),
                    _regulationEntry(
                      "United States",
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text("FCC ID: 2BFWB-F1",
                                  style: textStyleDark)),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Image.asset('assets/images/fcc_icon.png'),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              "This device complies with Part 15 of the FCC Rules. Operation is subject to the following two conditions: (1) This device may not cause harmful interference, and (2) This device must accept any interference received, including interference that may cause undesired operation.",
                              style: textStyleDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _regulationEntry(
                      "Europe / \nUnited Kingdom",
                      Image.asset('assets/images/eu_reg_icons.png'),
                    ),
                    _regulationEntry(
                      "Japan",
                      Image.asset('assets/images/telec_icon.png'),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 40, bottom: 8),
                  child: Text(
                    "Brilliant Labs Pte Ltd\n68 Circular Road #02-01\n049422 Singapore",
                    style: textStyleDark,
                    textAlign: TextAlign.center,
                  ),
                ),
                const Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Text(
                      "Frame is made in Singapore",
                      style: textStyleDark,
                    )),
              ],
            ),
          ),
        ));
  }
}
