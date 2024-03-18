import 'package:flutter/material.dart';
import 'package:noa/api.dart';
import 'package:noa/bluetooth.dart';
import 'package:noa/pages/login.dart';
import 'package:noa/style.dart';
import 'package:noa/util/switch_page.dart';
import 'package:noa/widgets/top_title_bar.dart';

String _userEmail = "Loading";
String _userPlan = "Loading";
String _userTokens = "Loading";
String _userRequests = "Loading";

Widget _accountInfoText(String title, String detail) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 42),
    child: Column(
      children: [
        Text(title, style: lightSubtitleTextStyle),
        Text(detail, style: lightTitleTextStyle),
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
        style: redText ? footerTextRedStyle : footerTextLightStyle,
      ),
    ),
  );
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final profile = await NoaApi.getProfile();
        if (context.mounted) {
          setState(() {
            _userEmail = profile['email'];
            _userPlan = profile['plan']['name'];
            _userTokens =
                "${profile['usage']['total_input'] + profile['usage']['total_output']}/${profile['plan']['allowed_tokens']}";
            _userRequests =
                "${profile['usage']['total_requests']}/${profile['plan']['max_requests']}";
          });
        }
      } catch (_) {}
    });
    return Scaffold(
      backgroundColor: backgroundLightColor,
      appBar: topTitleBar(context, 'ACCOUNT', false, true),
      body: Column(
        children: [
          Center(
            child: Column(
              children: [
                _accountInfoText("Signed In As", _userEmail),
                _accountInfoText("Tokens Used", _userTokens),
                _accountInfoText("Requests Used", _userRequests),
                _accountInfoText("Plan", _userPlan)
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
                  _linkedFooterText("Logout", false, () async {
                    await frameBluetooth.deletePairedDevice();
                    await NoaApi.deleteSavedAuthToken();
                    if (context.mounted) {
                      Navigator.pop(context);
                      switchPage(context, const LoginPage());
                    }
                  }),
                  _linkedFooterText("Privacy Policy", false, () {
                    // TODO
                  }),
                  _linkedFooterText("Terms & Conditions", false, () {
                    // TODO
                  }),
                  _linkedFooterText("Delete Account", true, () {
                    // TODO
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
