import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:noa/main.dart';
import 'package:noa/models/app_logic_model.dart' as app;
import 'package:noa/noa_api.dart';
import 'package:noa/pages/pairing.dart';
import 'package:noa/style.dart';
import 'package:noa/util/show_toast.dart';
import 'package:noa/util/switch_page.dart';
import 'package:noa/widgets/bottom_nav_bar.dart';
import 'package:noa/widgets/top_title_bar.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:uuid/uuid.dart';

final ScrollController _scrollController = ScrollController();

class NoaPage extends ConsumerWidget {
  const NoaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (ref.watch(app.model).state.current) {
        case app.State.stopLuaApp:
        case app.State.checkFirmwareVersion:
        case app.State.uploadMainLua:
        case app.State.uploadGraphicsLua:
        case app.State.uploadStateLua:
        case app.State.triggerUpdate:
        case app.State.updateFirmware:
          switchPage(context, const PairingPage());
          break;
        default:
      }
      Timer(const Duration(milliseconds: 100), () {
        if (context.mounted) {
          ref.watch(app.model.select((value) {
            if (value.noaMessages.length > 6) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            }
          }));
        }
      });
    });

    return Scaffold(
      backgroundColor: colorWhite,
      appBar: topTitleBar(context, 'CHAT', false, false),
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
                        child: GestureDetector(
                          onLongPress: () async {
                            await SaverGallery.saveImage(
                                ref.watch(app.model).noaMessages[index].image!,
                                name: const Uuid().v1(),
                                androidExistNotSave: false);
                            if (context.mounted) {
                              showToast("Saved to photos", context);
                            }
                          },
                          child: Image.memory(
                              ref.watch(app.model).noaMessages[index].image!),
                        ),
                      ),
                    ),
                  ),
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