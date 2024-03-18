import 'package:flutter/material.dart';
import 'package:noa/bluetooth.dart';
import 'package:noa/pages/noa.dart';
import 'package:noa/style.dart';
import 'package:noa/util/switch_page.dart';

class PairPage extends StatefulWidget {
  const PairPage({super.key});

  @override
  State<PairPage> createState() => _PairPageState();
}

class _PairPageState extends State<PairPage> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await frameBluetooth.isPaired()) {
        frameBluetooth.connect(false);
        if (context.mounted) {
          switchPage(context, const NoaPage());
        }
      } else {
        await frameBluetooth.connect(true);
        if (context.mounted) {
          switchPage(context, const NoaPage());
        }
      }
    });
    return Scaffold(
      backgroundColor: backgroundDarkColor,
      appBar: AppBar(
        backgroundColor: backgroundDarkColor,
        title: Image.asset('assets/brilliant_logo.png'),
      ),
      body: const Center(
        child: Text(
          "Pair",
          style: TextStyle(color: textLightColor),
        ),
      ),
    );
  }
}
