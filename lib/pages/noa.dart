import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noa/locationService.dart';
import 'package:noa/main.dart';
import 'package:noa/style.dart';
import 'package:noa/util/location_state.dart';
import 'package:noa/widgets/bottom_nav_bar.dart';
import 'package:noa/widgets/top_title_bar.dart';

class NoaPage extends ConsumerWidget {
  const NoaPage({super.key});
  Future<void> _getLocation() async {
    try {
      Position position = await LocationService().getCurrentLocation();
      String? address =
      await LocationService().getAddressFromCoordinates(position);

      updateName(address?? "not Specified");

      print(address);
    } catch (e) {
      print("Error fetching location: $e");
    }
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _getLocation();
    return Scaffold(
      backgroundColor: colorWhite,

      appBar: topTitleBar(context, 'NOA', false, false),

      body: ListView.builder(
        itemCount: ref.watch(messages).messages.length,
        itemBuilder: (context, index) {
          TextStyle style = textStyleLight;
          if (ref.watch(messages).messages[index].from == 'Noa') {
            style = textStyleDark;
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index == 0 ||
                  ref
                          .watch(messages)
                          .messages[index]
                          .time
                          .difference(
                              ref.watch(messages).messages[index - 1].time)
                          .inSeconds >
                      1700)
                Container(
                  margin: const EdgeInsets.only(top: 40, left: 42, right: 42),
                  child: Row(
                    children: [
                      Text(
                        "${ref.watch(messages).messages[index].time.hour.toString().padLeft(2, '0')}:${ref.watch(messages).messages[index].time.minute.toString().padLeft(2, '0')}",
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
                  ref.watch(messages).messages[index].message,
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
