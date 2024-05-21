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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text("FCC ID: 2BFWB-F1",
                                  style: textStyleDark)),
                          Text(
                            "This device complies with Part 15 of the FCC Rules. Operation is subject to the following two conditions: (1)This device may not cause harmful interference, and (2)This device must accept any interference received, including interference that may cause undesired operation",
                            style: textStyleDark,
                          ),
                        ],
                      ),
                    ),
                    _regulationEntry(
                        "Europe / \nUnited Kingdom", const Text("TODO")),
                    _regulationEntry("Japan", const Text("TODO")),
                  ],
                ),
                const Padding(
                    padding: EdgeInsets.only(top: 30, bottom: 8),
                    child: Text(
                      "Frame is made in Singapore",
                      style: textStyleDark,
                    )),
                const Padding(
                    padding: EdgeInsets.only(bottom: 50),
                    child: Text(
                      "TODO Address",
                      style: textStyleDark,
                    )),
              ],
            ),
          ),
        ));
  }
}
