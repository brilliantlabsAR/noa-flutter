import 'package:flutter/material.dart';
import 'package:noa/bluetooth.dart';
import 'package:noa/pages/noa.dart';
import 'package:noa/style.dart';

class PairPage extends StatefulWidget {
  const PairPage({super.key});

  @override
  State<PairPage> createState() => _PairPageState();
}

class _PairPageState extends State<PairPage> {
  void _connect() async {
    // TODO enable this again
    FrameConnectionEnum device =
        FrameConnectionEnum.connected; // await widget.bluetooth.connect(true);

    switch (device) {
      case FrameConnectionEnum.connected:
      case FrameConnectionEnum.new_connection:
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation1, animation2) => NoaPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        break;
      case FrameConnectionEnum.dfu_mode:
        // TODO
        break;
    }
  }

  void initState() {
    super.initState();
    // _connect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDarkColor,
      appBar: AppBar(
        backgroundColor: backgroundDarkColor,
        title: Image.asset('assets/brilliant_logo.png'),
      ),
      body: const Center(
        child: Text("Pair"),
      ),
    );
  }
}
