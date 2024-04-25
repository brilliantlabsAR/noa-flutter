import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:noa/main.dart';
import 'package:noa/style.dart';
import 'package:noa/util/show_toast.dart';
import 'package:noa/widgets/bottom_nav_bar.dart';
import 'package:noa/widgets/top_title_bar.dart';

Widget _logTextBox(BuildContext context, String data) {
  return Expanded(
    child: GestureDetector(
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: data));
        if (context.mounted) {
          showToast("Copied", context);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colorLight),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 28),
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              data,
              style: textStyleLight,
            ),
          ),
        ),
      ),
    ),
  );
}

class HackPage extends StatelessWidget {
  const HackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorDark,
      appBar: topTitleBar(context, 'HACK', true, false),
      body: Padding(
        padding: const EdgeInsets.only(left: 42, right: 42),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text("Bluetooth log", style: textStyleLightSubHeading),
          ),
          _logTextBox(context, globalBluetoothLog),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text("App log", style: textStyleLightSubHeading),
          ),
          _logTextBox(context, globalAppLog),
        ]),
      ),
      bottomNavigationBar: bottomNavBar(context, 2, true),
    );
  }
}
