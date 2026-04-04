import 'package:flutter_test/flutter_test.dart';
import 'package:field_flash/models/firmware_asset.dart';

void main() {
  group('FirmwareAsset.fromAssetName — ESP32 merged bin', () {
    test('parses device, variant, version, format', () {
      final a = FirmwareAsset.fromAssetName(
        name: 'Heltec_v3_companion_radio_usb-v1.14.1-467959c-merged.bin',
        downloadUrl: 'https://example.com/a.bin',
        sizeBytes: 1024,
      );
      expect(a.device, 'Heltec_v3');
      expect(a.connectionType, ConnectionType.usb);
      expect(a.format, FirmwareFormat.mergedBin);
      expect(a.version, 'v1.14.1');
    });

    test('ble connection type', () {
      final a = FirmwareAsset.fromAssetName(
        name: 'Heltec_v3_companion_radio_ble-v1.14.1-467959c-merged.bin',
        downloadUrl: 'https://example.com/a.bin',
        sizeBytes: 512,
      );
      expect(a.connectionType, ConnectionType.ble);
      expect(a.format, FirmwareFormat.mergedBin);
    });

    test('plain .bin (not merged)', () {
      final a = FirmwareAsset.fromAssetName(
        name: 'Heltec_v3_companion_radio_usb-v1.14.1-467959c.bin',
        downloadUrl: 'https://example.com/a.bin',
        sizeBytes: 512,
      );
      expect(a.format, FirmwareFormat.bin);
    });

    test('uf2 format', () {
      final a = FirmwareAsset.fromAssetName(
        name: 'RAK_4631_companion_radio_usb-v1.14.1-467959c.uf2',
        downloadUrl: 'https://example.com/a.uf2',
        sizeBytes: 512,
      );
      expect(a.device, 'RAK_4631');
      expect(a.format, FirmwareFormat.uf2);
    });

    test('zip format (Nordic DFU package)', () {
      final a = FirmwareAsset.fromAssetName(
        name: 'RAK_4631_companion_radio_ble-v1.14.1-467959c.zip',
        downloadUrl: 'https://example.com/a.zip',
        sizeBytes: 512,
      );
      expect(a.format, FirmwareFormat.zip);
    });

    test('displayName is human-readable device name', () {
      final a = FirmwareAsset.fromAssetName(
        name: 'LilyGo_TDeck_companion_radio_usb-v1.14.1-467959c-merged.bin',
        downloadUrl: 'https://example.com/a.bin',
        sizeBytes: 512,
      );
      expect(a.displayName, 'LilyGo TDeck');
    });

    test('isPreferred: merged.bin is preferred over plain .bin for ESP32', () {
      final merged = FirmwareAsset.fromAssetName(
        name: 'Heltec_v3_companion_radio_usb-v1.14.1-x-merged.bin',
        downloadUrl: 'https://example.com/a.bin',
        sizeBytes: 512,
      );
      final plain = FirmwareAsset.fromAssetName(
        name: 'Heltec_v3_companion_radio_usb-v1.14.1-x.bin',
        downloadUrl: 'https://example.com/b.bin',
        sizeBytes: 512,
      );
      expect(merged.isPreferred, isTrue);
      expect(plain.isPreferred, isFalse);
    });

    test('uf2 is preferred over zip for nRF52', () {
      final uf2 = FirmwareAsset.fromAssetName(
        name: 'RAK_4631_companion_radio_usb-v1.14.1-x.uf2',
        downloadUrl: 'https://example.com/a.uf2',
        sizeBytes: 512,
      );
      final zip = FirmwareAsset.fromAssetName(
        name: 'RAK_4631_companion_radio_usb-v1.14.1-x.zip',
        downloadUrl: 'https://example.com/b.zip',
        sizeBytes: 512,
      );
      expect(uf2.isPreferred, isTrue);
      expect(zip.isPreferred, isFalse);
    });

    test('unknown format returns FirmwareFormat.other', () {
      final a = FirmwareAsset.fromAssetName(
        name: 'RAK_3x72_companion_radio_usb-v1.14.1-x.hex',
        downloadUrl: 'https://example.com/a.hex',
        sizeBytes: 512,
      );
      expect(a.format, FirmwareFormat.other);
    });

    test('cacheFileName is stable and safe for filesystem', () {
      final a = FirmwareAsset.fromAssetName(
        name: 'Heltec_v3_companion_radio_usb-v1.14.1-467959c-merged.bin',
        downloadUrl: 'https://example.com/a.bin',
        sizeBytes: 512,
      );
      expect(a.cacheFileName, isNot(contains('/')));
      expect(a.cacheFileName, endsWith('.bin'));
    });
  });
}
