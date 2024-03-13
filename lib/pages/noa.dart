import 'package:flutter/material.dart';
import 'package:noa/models/noa_message_model.dart';
import 'package:noa/style.dart';
import 'package:noa/widgets/bottom_nav_bar.dart';
import 'package:noa/widgets/top_title_bar.dart';

class NoaPage extends StatefulWidget {
  NoaPage({super.key});

  @override
  State<NoaPage> createState() => _NoaPageState();
}

class _NoaPageState extends State<NoaPage> {
  List<NoaMessageModel> messages = [];

  @override
  void initState() {
    super.initState();
    messages.add(NoaMessageModel.addMessage(
      "I’m looking for some new sneakers. Could you help me find some?",
      "User",
      DateTime.now(),
    ));
    messages.add(NoaMessageModel.addMessage(
      "Sure! What kind of style are you looking for?",
      "Noa",
      DateTime.now().add(const Duration(seconds: 2)),
    ));
    messages.add(NoaMessageModel.addMessage(
      "Maybe something like these?",
      "User",
      DateTime.now().add(const Duration(seconds: 4)),
    ));
    messages.add(NoaMessageModel.addMessage(
      "Those look like some nice designer kicks! If you’re on a budget check these out from Camperlab, or if you want to splash out, Balenciaga have something similar.",
      "Noa",
      DateTime.now().add(const Duration(seconds: 5)),
    ));
    messages.add(NoaMessageModel.addMessage(
      "What's a good color to go for?",
      "User",
      DateTime.now().add(const Duration(seconds: 2938)),
    ));
    messages.add(NoaMessageModel.addMessage(
      "You can never go wrong with a classic blue sneaker. Alternatively, light green seems to be in style right now.",
      "Noa",
      DateTime.now().add(const Duration(seconds: 2941)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLightColor,

      appBar: TopTitleBar(context, 'NOA', false),

      body: Container(
        child: ListView.builder(
          itemCount: messages.length,
          itemBuilder: (context, index) {
            TextStyle style = userMessageTextStyle;
            if (messages[index].from == 'Noa') {
              style = noaMessageTextStyle;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index == 0 ||
                    messages[index]
                            .time
                            .difference(messages[index - 1].time)
                            .inSeconds >
                        1700)
                  Container(
                    margin: EdgeInsets.only(top: 40, left: 42, right: 42),
                    child: Row(
                      children: [
                        Text(
                          "${messages[index].time.hour.toString().padLeft(2, '0')}:${messages[index].time.minute.toString().padLeft(2, '0')}",
                          style: TextStyle(color: textLightColor),
                        ),
                        const Flexible(
                          child: Divider(
                            indent: 10,
                            color: textLightColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  margin: EdgeInsets.only(top: 10, left: 65, right: 42),
                  child: Text(
                    messages[index].message,
                    style: style,
                  ),
                ),
              ],
            );
          },
        ),
      ),

      // Bottom bar
      bottomNavigationBar: BottomNavBar(context, 0, false),
    );
  }
}
