import 'package:flutter_test/flutter_test.dart';
import 'package:field_flash/models/flash_progress.dart';

void main() {
  group('FlashProgress', () {
    test('bytesWritten and totalBytes compute percentage', () {
      final p = FlashProgress(
        bytesWritten: 512,
        totalBytes: 1024,
        message: 'Writing block 1',
      );
      expect(p.percentage, closeTo(0.5, 0.0001));
    });

    test('percentage is 0 when totalBytes is 0', () {
      final p = FlashProgress(
        bytesWritten: 0,
        totalBytes: 0,
        message: 'Starting',
      );
      expect(p.percentage, 0.0);
    });

    test('percentage clamps to 1.0', () {
      final p = FlashProgress(
        bytesWritten: 2048,
        totalBytes: 1024,
        message: 'Done',
      );
      expect(p.percentage, 1.0);
    });

    test('done() factory sets bytesWritten == totalBytes', () {
      final p = FlashProgress.done(totalBytes: 256);
      expect(p.bytesWritten, 256);
      expect(p.percentage, 1.0);
    });

    test('error() factory carries message', () {
      final p = FlashProgress.error('Timeout waiting for sync');
      expect(p.isError, isTrue);
      expect(p.message, contains('Timeout'));
    });

    test('non-error progress has isError false', () {
      final p = FlashProgress(bytesWritten: 0, totalBytes: 100, message: 'ok');
      expect(p.isError, isFalse);
    });
  });
}
