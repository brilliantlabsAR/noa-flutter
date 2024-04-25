import 'package:flutter/material.dart';
import 'package:noa/style.dart';
import 'package:noa/widgets/bottom_nav_bar.dart';
import 'package:noa/widgets/top_title_bar.dart';

Widget _textBox(String title, String token) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 36),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(title, style: textStyleLightSubHeading),
        ),
        Container(
          decoration: const BoxDecoration(
            color: colorLight,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          padding: const EdgeInsets.only(
            top: 5,
            bottom: 7,
            left: 10,
            right: 10,
          ),
          child: const TextField(
            style: textStyleDark,
            decoration: InputDecoration.collapsed(
              fillColor: colorLight,
              filled: true,
              hintText: "",
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _slider(String title, int divisions, String token) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: Text(title, style: textStyleLightSubHeading),
        ),
        SliderTheme(
          data: const SliderThemeData(
            trackHeight: 5,
            activeTrackColor: colorLight,
            activeTickMarkColor: colorLight,
            inactiveTrackColor: colorLight,
            inactiveTickMarkColor: colorLight,
            thumbColor: colorLight,
            valueIndicatorColor: colorDark,
            trackShape: RectangularSliderTrackShape(),
          ),
          child: Slider(
            label: "hi",
            value: 2,
            divisions: divisions,
            min: 0,
            max: divisions.toDouble(),
            onChanged: (double newValue) {
              print(newValue);
            },
          ),
        ),
      ],
    ),
  );
}

class TunePage extends StatelessWidget {
  const TunePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorWhite,
      appBar: topTitleBar(context, 'TUNE', false, false),
      body: Padding(
        padding: const EdgeInsets.only(left: 42, right: 42),
        child: Column(
          children: [
            _textBox("In the style of", ""),
            _textBox("Tone", ""),
            _textBox("Formatted as", ""),
            _slider("Temperature", 99, ""),
            _slider("Response length", 4, ""),
          ],
        ),
      ),
      bottomNavigationBar: bottomNavBar(context, 1, false),
    );
  }
}
