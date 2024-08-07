import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/style.dart';
import 'package:noa/widgets/bottom_nav_bar.dart';
import 'package:noa/widgets/top_title_bar.dart';

Widget _textBox(WidgetRef ref, int index) {
  late String title;
  late String value;

  switch (index) {
    case 0:
      title = "System prompt";
      value = ref.watch(app.model.select((v) => v.tunePrompt));
      break;
  }
  return Padding(
    padding: const EdgeInsets.only(bottom: 21),
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
          child: TextFormField(
            initialValue: value,
            minLines: 3,
            maxLines: null,
            onChanged: (value) {
              switch (index) {
                case 0:
                  ref.read(app.model.select((v) => v.tunePrompt = value));
                  break;
              }
            },
            style: textStyleDark,
            decoration: const InputDecoration.collapsed(
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

Widget _slider(WidgetRef ref, int index) {
  late String title;
  late int divisions;
  late int value;
  late String label;

  switch (index) {
    case 0:
      title = "Temperature";
      divisions = 100;
      value = ref.watch(app.model.select((v) => v.tuneTemperature));
      label = value.toString();
      break;
    case 1:
      title = "Response length";
      divisions = 4;
      value = ref.watch(app.model.select((v) => v.tuneLength.index));
      label = ref.watch(app.model.select((v) => v.tuneLength.name));
      break;
  }
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
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
            label: label,
            value: value.toDouble(),
            divisions: divisions,
            min: 0,
            max: divisions.toDouble(),
            onChanged: (double value) {
              switch (index) {
                case 0:
                  ref.read(app.model
                      .select((v) => v.tuneTemperature = value.toInt()));
                  break;
                case 1:
                  late app.TuneLength enumValue;
                  switch (value.toInt()) {
                    case 0:
                      enumValue = app.TuneLength.shortest;
                      break;
                    case 1:
                      enumValue = app.TuneLength.short;
                      break;
                    case 2:
                      enumValue = app.TuneLength.standard;
                      break;
                    case 3:
                      enumValue = app.TuneLength.long;
                      break;
                    case 4:
                      enumValue = app.TuneLength.longest;
                      break;
                  }
                  ref.read(app.model.select((v) => v.tuneLength = enumValue));
                  break;
              }
            },
          ),
        ),
      ],
    ),
  );
}

Widget _checkBox(WidgetRef ref, int index) {
  late String title;
  late bool value;

  switch (index) {
    case 0:
      title = "Text to speech";
      value = ref.watch(app.model.select((v) => v.textToSpeech));
  }

  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(title, style: textStyleLightSubHeading),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text("Disabled", style: textStyleDark),
            ),
            Switch(
              value: value,
              activeColor: colorDark,
              inactiveTrackColor: colorWhite,
              inactiveThumbColor: colorLight,
              onChanged: (value) =>
                  ref.read(app.model.select((v) => v.textToSpeech = value)),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8, left: 8),
              child: Text("Enabled", style: textStyleDark),
            ),
          ],
        ),
      ],
    ),
  );
}

class TunePage extends ConsumerWidget {
  const TunePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: colorWhite,
      appBar: topTitleBar(context, 'TUNE', false, false),
      body: Padding(
        padding: const EdgeInsets.only(left: 42, right: 42),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _textBox(ref, 0),
              _slider(ref, 0),
              _slider(ref, 1),
              _checkBox(ref, 0),
            ],
          ),
        ),
      ),
      bottomNavigationBar: bottomNavBar(context, 1, false),
    );
  }
}
