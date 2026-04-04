import 'package:flutter_test/flutter_test.dart';
import 'package:field_flash/models/device_profile.dart';

void main() {
  group('DeviceProfile', () {
    test('equality based on vid and pid', () {
      final a = DeviceProfile(
        vid: 0x303A,
        pid: 0x1001,
        name: 'ESP32-S3',
        protocol: FlashProtocolType.espRom,
      );
      final b = DeviceProfile(
        vid: 0x303A,
        pid: 0x1001,
        name: 'ESP32-S3 clone',
        protocol: FlashProtocolType.espRom,
      );
      expect(a, equals(b));
    });

    test('different vid/pid are not equal', () {
      final a = DeviceProfile(
        vid: 0x303A,
        pid: 0x1001,
        name: 'ESP32-S3',
        protocol: FlashProtocolType.espRom,
      );
      final b = DeviceProfile(
        vid: 0x10C4,
        pid: 0xEA60,
        name: 'CP2102',
        protocol: FlashProtocolType.espRom,
      );
      expect(a, isNot(equals(b)));
    });

    test('toString includes name', () {
      final profile = DeviceProfile(
        vid: 0x2886,
        pid: 0x0044,
        name: 'RAK4631',
        protocol: FlashProtocolType.nordicDfu,
      );
      expect(profile.toString(), contains('RAK4631'));
    });

    test('vidPidString formats as 0xVVVV:0xPPPP', () {
      final profile = DeviceProfile(
        vid: 0x303A,
        pid: 0x1001,
        name: 'ESP32-S3',
        protocol: FlashProtocolType.espRom,
      );
      expect(profile.vidPidString, '0x303a:0x1001');
    });
  });
}
