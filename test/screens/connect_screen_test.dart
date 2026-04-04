import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:field_flash/models/device_profile.dart';
import 'package:field_flash/services/app_providers.dart';
import 'package:field_flash/screens/connect_screen.dart';

Widget _wrap({DeviceProfile? device}) {
  return ProviderScope(
    overrides: [
      if (device != null)
        detectedDeviceProvider.overrideWith((ref) => device),
    ],
    child: const MaterialApp(
      home: ConnectScreen(),
    ),
  );
}

void main() {
  group('ConnectScreen', () {
    testWidgets('shows waiting indicator when no device connected', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.byKey(const Key('waiting_indicator')), findsOneWidget);
      expect(find.byKey(const Key('btn_continue')), findsNothing);
    });

    testWidgets('shows device card when device detected', (tester) async {
      const profile = DeviceProfile(
        vid: 0x303A,
        pid: 0x1001,
        name: 'ESP32-S3 (native USB)',
        protocol: FlashProtocolType.espRom,
      );
      await tester.pumpWidget(_wrap(device: profile));
      expect(find.byKey(const Key('device_card')), findsOneWidget);
      expect(find.text('ESP32-S3 (native USB)'), findsOneWidget);
    });

    testWidgets('shows continue button when device detected', (tester) async {
      const profile = DeviceProfile(
        vid: 0x303A,
        pid: 0x1001,
        name: 'ESP32-S3 (native USB)',
        protocol: FlashProtocolType.espRom,
      );
      await tester.pumpWidget(_wrap(device: profile));
      expect(find.byKey(const Key('btn_continue')), findsOneWidget);
    });

    testWidgets('manual override dropdown is always visible', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.byKey(const Key('manual_override_dropdown')), findsOneWidget);
    });
  });
}
