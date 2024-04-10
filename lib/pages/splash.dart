import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/pages/login.dart';
import 'package:noa/pages/noa.dart';
import 'package:noa/style.dart';
import 'package:noa/util/switch_page.dart';

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(app.model).triggerEvent(app.Event.init);
      Timer(const Duration(milliseconds: 1500), () {
        if (ref.watch(app.model).pairedDevice == null) {
          switchPage(context, const LoginPage());
        } else {
          switchPage(context, const NoaPage());
        }
      });
    });

    return Scaffold(
      backgroundColor: colorWhite,
      body: Center(
        child: Image.asset('assets/images/brilliant_logo_black.png'),
      ),
    );
  }
}
