

// takes a string and returns a list of TxTextSpriteBlock objects
import 'dart:ui';

import 'package:frame_ble/frame_ble.dart';
import 'package:frame_msg/tx/text_sprite_block.dart';

Future<TxTextSpriteBlock> textToSprites(String text, {
  int width = 620,
  int fontSize = 48,
  int maxDisplayRows = 10,
  TextDirection textDirection = TextDirection.ltr,
  TextAlign textAlign = TextAlign.start,
}) async {
   // create a TxTextSpriteBlock object
   var tsb = TxTextSpriteBlock(
      width: width,
      fontSize: fontSize,
      maxDisplayRows: maxDisplayRows,
      textDirection: textDirection,
      textAlign: textAlign,
      text: text,
    );

   // rasterize the text to sprites
   await tsb.rasterize(startLine: 0, endLine: tsb.numLines - 1);
   return tsb;
}

// send textsprites to BrilliantDevice
Future <void> sendSprites(BrilliantDevice device, String text, {
  int width = 620,
  int fontSize = 48,
  int maxDisplayRows = 10,
  TextDirection textDirection = TextDirection.ltr,
  TextAlign textAlign = TextAlign.start,
}) async {
  try{
   // create a TxTextSpriteBlock object
   var tsb = await textToSprites(text, width: width, fontSize: fontSize, maxDisplayRows: maxDisplayRows, textDirection: textDirection, textAlign: textAlign);
   // send the sprites to the device
    await device.sendMessage(0x24, tsb.pack());
    for (var sprite in tsb.rasterizedSprites) {
      await device.sendMessage(0x24, sprite.pack());
    }
  } catch (e) {
    throw Exception('Error sending sprites: $e');
  }
}