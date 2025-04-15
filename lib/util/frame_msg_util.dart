import 'dart:convert';
import 'dart:typed_data';

import 'package:frame_msg/tx_msg.dart';

/// A message containing a String of plain text and emoji,
/// plus optional top-left corner position coordinates for the
/// text to be printed in the Frame display (Lua/1-based, i.e. [1,1] to [640,400])
/// plus an optional palette offset (1..15, 0/'VOID' is invalid), plus optional character spacing
class TxRichText extends TxMsg {
  final String _text;
  final int _x, _y;
  final int _paletteOffset;
  final int _spacing;
  final String _emoji;

  TxRichText(
    {required String text, 
    int x = 1, 
    int y = 1, 
    int paletteOffset = 1, 
    int spacing = 4, 
    String emoji = '' }) : _text = text, _x = x, _y = y, _paletteOffset = paletteOffset, _spacing = spacing, _emoji = emoji;

  @override
  Uint8List pack() {
    final stringBytes = utf8.encode(_text);
    final strlen = stringBytes.length;
    final emojiBytes = utf8.encode(_emoji);
    final emojiLen = emojiBytes.length;
    final totalLen = strlen + emojiLen;

    Uint8List bytes = Uint8List(7 + totalLen);
    bytes[0] = _x >> 8;   // x msb
    bytes[1] = _x & 0xFF; // x lsb
    bytes[2] = _y >> 8;   // y msb
    bytes[3] = _y & 0xFF; // y lsb
    bytes[4] = _paletteOffset & 0x0F; // 1..15
    bytes[5] = _spacing & 0xFF;
    bytes[6] = strlen & 0xFF; // length of the string
    bytes.setRange(7, strlen + 7, stringBytes);
    // Add emoji bytes if present
    if (emojiLen > 0) {
      bytes.setRange(7 + strlen, 7 + totalLen, emojiBytes);
    }
    return bytes;
  }
}
