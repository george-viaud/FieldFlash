import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:field_flash/models/flash_progress.dart';
import 'package:field_flash/services/app_providers.dart';
import 'package:field_flash/screens/flash_screen.dart';

Widget _wrap({FlashProgress? progress, FlashState state = FlashState.idle}) {
  return ProviderScope(
    overrides: [
      flashStateProvider.overrideWith((ref) => state),
      flashProgressProvider.overrideWith((ref) => progress),
    ],
    child: const MaterialApp(
      home: FlashScreen(autoStart: false),
    ),
  );
}

void main() {
  group('FlashScreen', () {
    testWidgets('shows progress bar', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump(); // let initState/postFrameCallback run
      expect(find.byKey(const Key('flash_progress_bar')), findsOneWidget);
    });

    testWidgets('shows 0% initially', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.textContaining('0.0%'), findsOneWidget);
    });

    testWidgets('shows done button when flash completes', (tester) async {
      final progress = FlashProgress.done(totalBytes: 1024);
      await tester.pumpWidget(_wrap(
        progress: progress,
        state: FlashState.done,
      ));
      await tester.pump();
      expect(find.byKey(const Key('btn_done')), findsOneWidget);
      expect(find.textContaining('Done'), findsOneWidget);
    });

    testWidgets('shows error button on flash failure', (tester) async {
      final progress = FlashProgress.error('Timeout');
      await tester.pumpWidget(_wrap(
        progress: progress,
        state: FlashState.error,
      ));
      await tester.pump();
      expect(find.byKey(const Key('btn_done')), findsOneWidget);
      expect(find.text('Back to Start'), findsOneWidget);
    });

    testWidgets('log view is present', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();
      expect(find.byKey(const Key('flash_log')), findsOneWidget);
    });
  });
}
