import 'package:flutter/material.dart';
import 'package:noa/widgets/bottom_nav_bar.dart';
import 'package:noa/widgets/top_title_bar.dart';

class TunePage extends StatelessWidget {
  const TunePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TopTitleBar(context, 'TUNE', false),
      body: const Center(
        child: Text("Tune"),
      ),
      bottomNavigationBar: BottomNavBar(context, 1),
    );
  }
}
