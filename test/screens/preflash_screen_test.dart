import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:field_flash/models/device_profile.dart';
import 'package:field_flash/models/firmware_source.dart';
import 'package:field_flash/services/app_providers.dart';
import 'package:field_flash/screens/preflash_screen.dart';

Widget _wrap({DeviceProfile? device, FirmwareSource? firmware}) {
  return ProviderScope(
    overrides: [
      if (device != null) detectedDeviceProvider.overrideWith((ref) => device),
      if (firmware != null)
        selectedFirmwareProvider.overrideWith((ref) => firmware),
    ],
    child: const MaterialApp(
      home: PreFlashScreen(),
    ),
  );
}

void main() {
  group('PreFlashScreen', () {
    testWidgets('shows start flash button', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.byKey(const Key('btn_start_flash')), findsOneWidget);
    });

    testWidgets('shows ESP boot mode instructions for ESP device', (tester) async {
      const profile = DeviceProfile(
        vid: 0x303A,
        pid: 0x1001,
        name: 'ESP32-S3',
        protocol: FlashProtocolType.espRom,
      );
      await tester.pumpWidget(_wrap(device: profile));
      expect(find.text('Boot mode'), findsOneWidget);
      expect(find.textContaining('BOOT'), findsOneWidget);
    });

    testWidgets('shows nRF boot mode instructions for Nordic DFU device', (tester) async {
      const profile = DeviceProfile(
        vid: 0x2886,
        pid: 0x0044,
        name: 'RAK4631',
        protocol: FlashProtocolType.nordicDfu,
      );
      await tester.pumpWidget(_wrap(device: profile));
      expect(find.textContaining('RESET'), findsOneWidget);
    });

    testWidgets('shows checklist items', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.byKey(const Key('check_battery')), findsOneWidget);
      expect(find.byKey(const Key('check_firmware')), findsOneWidget);
      expect(find.byKey(const Key('check_file')), findsOneWidget);
    });

    testWidgets('checklist items are checkboxes that can be toggled', (tester) async {
      await tester.pumpWidget(_wrap());
      final checklistItem = find.byKey(const Key('check_battery'));
      final checkbox = find.descendant(
          of: checklistItem, matching: find.byType(CheckboxListTile));
      expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
      await tester.tap(checklistItem);
      await tester.pump();
      expect(tester.widget<CheckboxListTile>(checkbox).value, isTrue);
    });
  });
}
