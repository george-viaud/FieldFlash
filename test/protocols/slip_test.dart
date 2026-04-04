import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:field_flash/protocols/slip.dart';

void main() {
  group('SLIP encode', () {
    test('wraps payload with 0xC0 delimiters', () {
      final payload = Uint8List.fromList([0x01, 0x02, 0x03]);
      final frame = slipEncode(payload);
      expect(frame.first, 0xC0);
      expect(frame.last, 0xC0);
      expect(frame.sublist(1, frame.length - 1), payload);
    });

    test('escapes 0xC0 bytes inside payload as 0xDB 0xDC', () {
      final payload = Uint8List.fromList([0xC0]);
      final frame = slipEncode(payload);
      // 0xC0 [START] + 0xDB 0xDC [escaped] + 0xC0 [END]
      expect(frame, [0xC0, 0xDB, 0xDC, 0xC0]);
    });

    test('escapes 0xDB bytes inside payload as 0xDB 0xDD', () {
      final payload = Uint8List.fromList([0xDB]);
      final frame = slipEncode(payload);
      expect(frame, [0xC0, 0xDB, 0xDD, 0xC0]);
    });

    test('escapes multiple special bytes', () {
      final payload = Uint8List.fromList([0xC0, 0xDB, 0x01]);
      final frame = slipEncode(payload);
      expect(frame, [0xC0, 0xDB, 0xDC, 0xDB, 0xDD, 0x01, 0xC0]);
    });

    test('empty payload encodes as two delimiters', () {
      final frame = slipEncode(Uint8List(0));
      expect(frame, [0xC0, 0xC0]);
    });
  });

  group('SLIP decode', () {
    test('strips delimiters and returns payload', () {
      final frame = Uint8List.fromList([0xC0, 0x01, 0x02, 0xC0]);
      expect(slipDecode(frame), [0x01, 0x02]);
    });

    test('unescapes 0xDB 0xDC back to 0xC0', () {
      final frame = Uint8List.fromList([0xC0, 0xDB, 0xDC, 0xC0]);
      expect(slipDecode(frame), [0xC0]);
    });

    test('unescapes 0xDB 0xDD back to 0xDB', () {
      final frame = Uint8List.fromList([0xC0, 0xDB, 0xDD, 0xC0]);
      expect(slipDecode(frame), [0xDB]);
    });

    test('round-trips arbitrary bytes', () {
      final original = Uint8List.fromList(
        List.generate(256, (i) => i),
      );
      expect(slipDecode(slipEncode(original)), original);
    });

    test('throws on invalid escape sequence', () {
      final bad = Uint8List.fromList([0xC0, 0xDB, 0x01, 0xC0]);
      expect(() => slipDecode(bad), throwsArgumentError);
    });
  });
}
