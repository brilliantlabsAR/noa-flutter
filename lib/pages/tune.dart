import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/style.dart';
import 'package:noa/widgets/bottom_nav_bar.dart';
import 'package:noa/widgets/top_title_bar.dart';

Widget _textBox(WidgetRef ref, int index) {
  late String title;
  late String value;
  late bool isCustomServerEnabled = ref.watch(app.model.select((v) => v.customServer));
  late bool willShow = true;
  switch (index) {
    case 0:
      willShow = !isCustomServerEnabled;
      title = "System prompt";
      value = ref.watch(app.model.select((v) => v.tunePrompt)); 
      break;
  }
  if (!willShow) {
    return Container();
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
            minLines: 8,
            maxLines: null,
            onTapOutside: (event) => FocusScope.of(ref.context).unfocus(),
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

Widget _inputBox(WidgetRef ref, int index) {
  late String title;
  late String value;
  late bool isCustomServerEnabled = ref.watch(app.model.select((v) => v.customServer));
  late bool willShow = true;

  switch (index) {
    case 0:
      willShow = isCustomServerEnabled;
      title = "API Endpoint";
      value = ref.watch(app.model.select((v) => v.apiEndpoint));
      break;
    case 1:
      willShow = isCustomServerEnabled;
      title = "API Header Value";
      value = ref.watch(app.model.select((v) => v.apiHeader));
      break;
    case 2:
      willShow = isCustomServerEnabled;
      title = "API Header Key";
      value = ref.watch(app.model.select((v) => v.apiToken));
      break;
  }
  if (!willShow) {
    return Container();
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
            minLines: 1,
            maxLines: null,
            onTapOutside: (event) => FocusScope.of(ref.context).unfocus(),
            onChanged: (value) {
              switch (index) {
                case 0:
                  ref.read(app.model.select((v) => v.apiEndpoint = value));
                  break;
                case 1:
                  ref.read(app.model.select((v) => v.apiHeader = value));
                  break;
                case 2:
                  ref.read(app.model.select((v) => v.apiToken = value));
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
  late bool isCustomServerEnabled = ref.watch(app.model.select((v) => v.customServer));
  late bool willShow = true;
  switch (index) {
    case 0:
      willShow = !isCustomServerEnabled;
      title = "Temperature";
      divisions = 100;
      value = ref.watch(app.model.select((v) => v.tuneTemperature));
      label = value.toString();
      break;
    case 1:
      willShow = !isCustomServerEnabled;
      title = "Response length";
      divisions = 4;
      value = ref.watch(app.model.select((v) => v.tuneLength.index));
      label = ref.watch(app.model.select((v) => v.tuneLength.name));
      break;
  }
  if (!willShow) {
    return Container();
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
  late String disableOption = "Disabled";
  late String enableOption = "Enabled";
  late bool isCustomServerEnabled = ref.watch(app.model.select((v) => v.customServer));
  late bool willShow = true;

  switch (index) {
    case 0:
      willShow = !isCustomServerEnabled;
      title = "Text to speech";
      value = ref.watch(app.model.select((v) => v.textToSpeech));
      disableOption = "Disabled";
      enableOption = "Enabled";
    case 1:
      willShow = !isCustomServerEnabled;
      title = "Promptless";
      value = ref.watch(app.model.select((v) => v.promptless));
    case 2:
      title = "Server";
      value = ref.watch(app.model.select((v) => v.customServer));
      disableOption = "Noa Server";
      enableOption = "Custom Server";
  }
  if (!willShow) {
    return Container();
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
             Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(disableOption, style: textStyleDark),
            ),
            Switch(
              value: value,
              activeColor: colorDark,
              inactiveTrackColor: colorWhite,
              inactiveThumbColor: colorLight,
              onChanged: (value) {
                switch (index) {
                  case 0:
                    ref.read(app.model.select((v) => v.textToSpeech = value));
                    break;
                  case 1:
                    ref.read(app.model.select((v) => v.promptless = value));
                    break;
                  case 2:
                    ref.read(app.model.select((v) => v.customServer = value));
                    break;
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, left: 8),
              child: Text(enableOption, style: textStyleDark),
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
      appBar: topTitleBar(context, 'HACK', false, false),
      body: Padding(
        padding: const EdgeInsets.only(left: 42, right: 42),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _checkBox(ref, 2),
              _textBox(ref, 0),
              _slider(ref, 0),
              _slider(ref, 1),
              _checkBox(ref, 0),
              _inputBox(ref, 0),
              _inputBox(ref, 2),
              _inputBox(ref, 1),
              _checkBox(ref, 1),
            ],
          ),
        ),
      ),
      bottomNavigationBar: bottomNavBar(context, 1, false),
    );
  }
}