import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:noa/main.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/noa_api.dart';
import 'package:noa/style.dart';
import 'package:noa/util/alert_dialog.dart';
import 'package:noa/widgets/bottom_nav_bar.dart';
import 'package:noa/widgets/top_title_bar.dart';

final ScrollController _scrollController = ScrollController();

class NoaPage extends ConsumerWidget {
  const NoaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.watch(app.model).state.current ==
          app.State.sendResponseToDevice) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
      }
    });

    return Scaffold(
      backgroundColor: colorWhite,
      appBar: topTitleBar(context, 'NOA', false, false),
      body: PageStorage(
        bucket: globalPageStorageBucket,
        child: ListView.builder(
          key: const PageStorageKey<String>('noaPage'),
          controller: _scrollController,
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
                            .difference(ref
                                .watch(app.model)
                                .noaMessages[index - 1]
                                .time)
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
                if (ref.watch(app.model).noaMessages[index].image != null)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colorLight,
                        width: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(10.5),
                    ),
                    margin: const EdgeInsets.only(
                        top: 10, bottom: 10, left: 65, right: 65),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox.fromSize(
                        child: Image.memory(
                            ref.watch(app.model).noaMessages[index].image!),
                      ),
                    ),
                  ),


                if(Platform.isAndroid)
                StreamBuilder<bool>(
                  stream: ref.watch(app.model).bluetoothController.stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {

                      bool status = snapshot.data ?? false;
                      if(!status)
                      {



                        WidgetsBinding.instance?.addPostFrameCallback((_) {
                          alertDialog(
                            context,
                            "Bluetooth is disabled",
                            "Please turn on Bluetooth",
                          );});
                      }
                      return SizedBox() ;
                    } else {
                      return SizedBox(); // Return an empty SizedBox while waiting for the GPS or Bluetooth status to be enabled
                    }
                  },),

                if(Platform.isAndroid)
                StreamBuilder<bool>(
                  stream: ref.watch(app.model).gpsStatusController.stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {

                      bool status = snapshot.data ?? false;
                      if(!status)
                      {
                        WidgetsBinding.instance?.addPostFrameCallback((_) {
                          alertDialog(
                            context,
                            "Gps is disabled",
                            "Please turn on Gps",
                          );});
                      }
                      return SizedBox() ;
                    } else {
                      return SizedBox(); // Return an empty SizedBox while waiting for the GPS or Bluetooth status to be enabled
                    }
                  },),


              ],
            );
          },
          padding: const EdgeInsets.only(bottom: 20),
        ),
      ),
      bottomNavigationBar: bottomNavBar(context, 0, false),
    );
  }
}
