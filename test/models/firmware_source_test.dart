import 'package:flutter_test/flutter_test.dart';
import 'package:field_flash/models/firmware_source.dart';

void main() {
  group('FirmwareSource', () {
    test('localFile carries path and infers name', () {
      final src = FirmwareSource.localFile('/sdcard/firmware.bin');
      expect(src.isLocal, isTrue);
      expect(src.displayName, 'firmware.bin');
    });

    test('githubRelease carries repo, tag, and asset name', () {
      final src = FirmwareSource.githubRelease(
        repo: 'meshtastic/firmware',
        tag: 'v2.5.1',
        assetName: 'firmware-heltec-v3.bin',
        downloadUrl: 'https://example.com/firmware.bin',
      );
      expect(src.isLocal, isFalse);
      expect(src.displayName, 'firmware-heltec-v3.bin');
      expect(src.tag, 'v2.5.1');
    });

    test('localFile fileExtension lowercase', () {
      final src = FirmwareSource.localFile('/path/to/MY_FIRMWARE.BIN');
      expect(src.fileExtension, '.bin');
    });

    test('githubRelease fileExtension from assetName', () {
      final src = FirmwareSource.githubRelease(
        repo: 'meshtastic/firmware',
        tag: 'v2.5.1',
        assetName: 'firmware.uf2',
        downloadUrl: 'https://example.com/firmware.uf2',
      );
      expect(src.fileExtension, '.uf2');
    });
  });
}
