import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/pages/regulatory.dart';
import 'package:noa/pages/splash.dart';
import 'package:noa/style.dart';
import 'package:noa/util/switch_page.dart';
import 'package:noa/widgets/top_title_bar.dart';
import 'package:url_launcher/url_launcher.dart';

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

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: colorWhite,
      appBar: topTitleBar(context, 'ACCOUNT', false, true),
      body: Column(
        children: [
          Center(
            child: Column(
              children: [
                _accountInfoText(
                    "Signed In As", ref.watch(app.model).noaUser.email),
                _accountInfoText("Credits Used",
                    "${ref.watch(app.model).noaUser.creditsUsed} / ${ref.watch(app.model).noaUser.maxCredits}"),
                _accountInfoText("Plan", ref.watch(app.model).noaUser.plan)
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 42, bottom: 50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _linkedFooterText("Tutorials", false, () async {
                    try {
                      await launchUrl(Uri.parse(
                          "https://www.youtube.com/playlist?list=PLfbaC5GRVJJgSPdN-KWndTld35tihu1Ic"));
                    } catch (_) {}
                  }),
                  _linkedFooterText("Logout", false, () async {
                    ref.read(app.model).triggerEvent(app.Event.logoutPressed);
                    if (context.mounted) {
                      Navigator.pop(context);
                      switchPage(context, const SplashPage());
                    }
                  }),
                  _linkedFooterText("Privacy Policy", false, () async {
                    try {
                      await launchUrl(Uri.parse(
                          "https://brilliant.xyz/pages/privacy-policy"));
                    } catch (_) {}
                  }),
                  _linkedFooterText("Terms & Conditions", false, () async {
                    try {
                      await launchUrl(Uri.parse(
                          "https://brilliant.xyz/pages/terms-conditions"));
                    } catch (_) {}
                  }),
                  _linkedFooterText("Regulatory", false, () async {
                    switchPage(context, const RegulatoryPage());
                  }),
                  _linkedFooterText("Delete Account", true, () {
                    // TODO ask user to confirm
                    ref.read(app.model).triggerEvent(app.Event.deletePressed);
                    if (context.mounted) {
                      Navigator.pop(context);
                      switchPage(context, const SplashPage());
                    }
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
