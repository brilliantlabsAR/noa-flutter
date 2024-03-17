import 'package:flutter/material.dart';
import 'package:noa/services/noa_api.dart';
import 'package:noa/style.dart';
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
      body: Center(
        child: Column(
          children: [
            _accountInfoText("Signed In As", _userEmail),
            _accountInfoText("Tokens Used", _userTokens),
            _accountInfoText("Requests Used", _userRequests),
            _accountInfoText("Plan", _userPlan)
          ],
        ),
      ),
    );
  }
}
