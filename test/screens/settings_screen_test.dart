import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:field_flash/screens/settings_screen.dart';

void main() {
  group('SettingsScreen', () {
    testWidgets('lists known devices', (tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: SettingsScreen()),
      ));
      // At least one entry from the VID/PID table should appear
      expect(find.textContaining('ESP32'), findsWidgets);
    });

    testWidgets('shows Known Devices section heading', (tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: SettingsScreen()),
      ));
      expect(find.text('Known Devices'), findsOneWidget);
    });
  });
}
