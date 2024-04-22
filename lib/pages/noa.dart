import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/noa_api.dart';
import 'package:noa/style.dart';
import 'package:noa/widgets/bottom_nav_bar.dart';
import 'package:noa/widgets/top_title_bar.dart';

class NoaPage extends ConsumerWidget {
  const NoaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: colorWhite,

      appBar: topTitleBar(context, 'NOA', false, false),

      body: ListView.builder(
        itemCount: ref.watch(app.model).noaMessages.length,
        itemBuilder: (context, index) {
          TextStyle style = textStyleLight;
          if (ref.watch(app.model).noaMessages[index].from == NoaRole.noa) {
            style = textStyleDark;
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index == 0 ||
                  ref
                          .watch(app.model)
                          .noaMessages[index]
                          .time
                          .difference(
                              ref.watch(app.model).noaMessages[index - 1].time)
                          .inSeconds >
                      1700)
                Container(
                  margin: const EdgeInsets.only(top: 40, left: 42, right: 42),
                  child: Row(
                    children: [
                      Text(
                        "${ref.watch(app.model).noaMessages[index].time.hour.toString().padLeft(2, '0')}:${ref.watch(app.model).noaMessages[index].time.minute.toString().padLeft(2, '0')}",
                        style: const TextStyle(color: colorLight),
                      ),
                      const Flexible(
                        child: Divider(
                          indent: 10,
                          color: colorLight,
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                margin: const EdgeInsets.only(top: 10, left: 65, right: 42),
                child: Text(
                  ref.watch(app.model).noaMessages[index].message,
                  style: style,
                ),
              ),
            ],
          );
        },
      ),

      // Bottom bar
      bottomNavigationBar: bottomNavBar(context, 0, false),
    );
  }
}
