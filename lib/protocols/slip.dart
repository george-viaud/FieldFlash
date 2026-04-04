import 'dart:typed_data';

const int _frameEnd = 0xC0;
const int _frameEsc = 0xDB;
const int _transFrameEnd = 0xDC; // follows 0xDB to represent 0xC0
const int _transFrameEsc = 0xDD; // follows 0xDB to represent 0xDB

/// Encodes [payload] into a SLIP frame: 0xC0 [escaped bytes] 0xC0
Uint8List slipEncode(Uint8List payload) {
  final buf = BytesBuilder();
  buf.addByte(_frameEnd);
  for (final b in payload) {
    if (b == _frameEnd) {
      buf.addByte(_frameEsc);
      buf.addByte(_transFrameEnd);
    } else if (b == _frameEsc) {
      buf.addByte(_frameEsc);
      buf.addByte(_transFrameEsc);
    } else {
      buf.addByte(b);
    }
  }
  buf.addByte(_frameEnd);
  return buf.toBytes();
}

/// Decodes a SLIP frame, stripping delimiters and unescaping bytes.
/// Throws [ArgumentError] on invalid escape sequences.
Uint8List slipDecode(Uint8List frame) {
  // Strip leading/trailing 0xC0 delimiters if present.
  int start = 0;
  int end = frame.length;
  if (end > 0 && frame[0] == _frameEnd) start = 1;
  if (end > start && frame[end - 1] == _frameEnd) end -= 1;

  final buf = BytesBuilder();
  int i = start;
  while (i < end) {
    final b = frame[i];
    if (b == _frameEsc) {
      i++;
      if (i >= end) throw ArgumentError('Truncated SLIP escape sequence');
      final next = frame[i];
      if (next == _transFrameEnd) {
        buf.addByte(_frameEnd);
      } else if (next == _transFrameEsc) {
        buf.addByte(_frameEsc);
      } else {
        throw ArgumentError(
            'Invalid SLIP escape sequence: 0xDB 0x${next.toRadixString(16)}');
      }
    } else {
      buf.addByte(b);
    }
    i++;
  }
  return buf.toBytes();
}
