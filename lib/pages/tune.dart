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
      title = "In the style of";
      value = ref.watch(app.model.select((v) => v.tuneStyle));
      break;
    case 1:
      title = "Tone";
      value = ref.watch(app.model.select((v) => v.tuneTone));
      break;
    case 2:
      title = "Formatted as";
      value = ref.watch(app.model.select((v) => v.tuneFormat));
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
            onChanged: (value) {
              switch (index) {
                case 0:
                  ref.read(app.model.select((v) => v.tuneStyle = value));
                  break;
                case 1:
                  ref.read(app.model.select((v) => v.tuneTone = value));
                  break;
                case 2:
                  ref.read(app.model.select((v) => v.tuneFormat = value));
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
                  ref.read(app.model.select((v) => v.length = enumValue));
                  break;
              }
            },
          ),
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
        child: Column(
          children: [
            _textBox(ref, 0),
            _textBox(ref, 1),
            _textBox(ref, 2),
            _slider(ref, 0),
            _slider(ref, 1),
          ],
        ),
      ),
      bottomNavigationBar: bottomNavBar(context, 1, false),
    );
  }
}
