import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:noa/style.dart';
import 'package:noa/util/app_log.dart';
import 'package:noa/util/show_toast.dart';
import 'package:noa/widgets/top_title_bar.dart';

final ScrollController _bluetoothLogScrollController = ScrollController();
final ScrollController _appLogScrollController = ScrollController();

Widget _logTextBox(
  BuildContext context,
  String data,
  ScrollController controller,
) {
  return Expanded(
    child: GestureDetector(
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: data));
        if (context.mounted) {
          showToast("Copied", context);
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Color.fromRGBO(245, 245, 245, 1),
          borderRadius: BorderRadius.all(Radius.circular(0)),
        ),
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 28),
        width: double.infinity,
        child: SingleChildScrollView(
          controller: controller,
          scrollDirection: Axis.vertical,
          reverse: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              data,
              style: textStyleDark,
            ),
          ),
        ),
      ),
    ),
  );
}

class HackPage extends ConsumerWidget {
  const HackPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bluetoothLogScrollController.animateTo(
          _bluetoothLogScrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut);
      _appLogScrollController.animateTo(
          _appLogScrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut);
    });

    return Scaffold(
      backgroundColor: colorWhite,
      appBar: topTitleBar(context, 'Hack', false, false),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                "Bluetooth log",
                style: textStyleLightSubHeading.copyWith(
                  fontWeight: FontWeight.w400,
                  fontSize: 14.0,
                ),
              ),
            ),
            _logTextBox(
              context,
              ref.watch(appLog).bluetooth,
              _bluetoothLogScrollController,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                "App log",
                style: textStyleLightSubHeading.copyWith(
                  fontWeight: FontWeight.w400,
                  fontSize: 14.0,
                ),
              ),
            ),
            _logTextBox(
              context,
              ref.watch(appLog).app,
              _appLogScrollController,
            ),
          ],
        ),
      )
    );
  }
}