import 'package:flutter_test/flutter_test.dart';
import 'package:field_flash/models/device_profile.dart';
import 'package:field_flash/services/usb_device_service.dart';

void main() {
  group('UsbDeviceService.detect', () {
    test('ESP32-S3 native USB (0x303A:0x1001)', () {
      final profile = UsbDeviceService.detect(vid: 0x303A, pid: 0x1001);
      expect(profile, isNotNull);
      expect(profile!.protocol, FlashProtocolType.espRom);
      expect(profile.name, contains('ESP32-S3'));
    });

    test('CP2102 UART bridge (0x10C4:0xEA60)', () {
      final profile = UsbDeviceService.detect(vid: 0x10C4, pid: 0xEA60);
      expect(profile, isNotNull);
      expect(profile!.protocol, FlashProtocolType.espRom);
    });

    test('CH343 UART bridge (0x1A86:0x55D4)', () {
      final profile = UsbDeviceService.detect(vid: 0x1A86, pid: 0x55D4);
      expect(profile, isNotNull);
      expect(profile!.protocol, FlashProtocolType.espRom);
    });

    test('RAK4631 Nordic DFU (0x2886:0x0044)', () {
      final profile = UsbDeviceService.detect(vid: 0x2886, pid: 0x0044);
      expect(profile, isNotNull);
      expect(profile!.protocol, FlashProtocolType.nordicDfu);
      expect(profile.name, contains('RAK4631'));
    });

    test('Adafruit UF2 (VID 0x239A, any PID)', () {
      final profile = UsbDeviceService.detect(vid: 0x239A, pid: 0xBEEF);
      expect(profile, isNotNull);
      expect(profile!.protocol, FlashProtocolType.uf2);
    });

    test('unknown VID/PID returns null', () {
      expect(UsbDeviceService.detect(vid: 0xDEAD, pid: 0xBEEF), isNull);
    });

    test('known VID with wrong PID returns null (for exact-match entries)', () {
      // CP2102 PID is 0xEA60 — different PID should not match
      expect(UsbDeviceService.detect(vid: 0x10C4, pid: 0x0001), isNull);
    });

    test('allProfiles lists all known devices', () {
      expect(UsbDeviceService.allProfiles.length, greaterThan(3));
    });
  });
}
