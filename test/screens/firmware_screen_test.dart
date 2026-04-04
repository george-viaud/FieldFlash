import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:field_flash/models/firmware_asset.dart';
import 'package:field_flash/models/firmware_source.dart';
import 'package:field_flash/services/app_providers.dart';
import 'package:field_flash/services/firmware_library_service.dart';
import 'package:field_flash/services/github_releases_service.dart';
import 'package:field_flash/screens/firmware_screen.dart';

// A real FirmwareLibraryService backed by a temp directory
FirmwareLibraryService _makeLibrary() {
  final dir = Directory.systemTemp.createTempSync('fw_ui_test_');
  return FirmwareLibraryService(cacheDir: dir);
}

ReleaseInfo _fakeRelease() => ReleaseInfo(
      tag: 'companion-v1.14.1',
      name: 'Companion Firmware v1.14.1',
      publishedAt: '2026-03-20T03:53:00Z',
      htmlUrl: 'https://example.com',
      releaseNotes: 'Test release',
      assets: [
        FirmwareAsset.fromAssetName(
          name: 'Heltec_v3_companion_radio_usb-v1.14.1-abc-merged.bin',
          downloadUrl: 'https://example.com/a.bin',
          sizeBytes: 512,
        ),
        FirmwareAsset.fromAssetName(
          name: 'RAK_4631_companion_radio_usb-v1.14.1-abc.uf2',
          downloadUrl: 'https://example.com/b.uf2',
          sizeBytes: 256,
        ),
      ],
    );

Widget _wrap({
  FirmwareSource? firmware,
  List<ReleaseInfo>? releases,
  FirmwareLibraryService? library,
}) {
  final lib = library ?? _makeLibrary();
  final rels = releases ?? [_fakeRelease()];
  return ProviderScope(
    overrides: [
      if (firmware != null)
        selectedFirmwareProvider.overrideWith((ref) => firmware),
      meshcoreReleasesProvider.overrideWith(
        (ref) => Future.value(rels),
      ),
      firmwareLibraryServiceProvider.overrideWith(
        (ref) => Future.value(lib),
      ),
    ],
    child: const MaterialApp(home: FirmwareScreen()),
  );
}

void main() {
  group('FirmwareScreen — Local tab', () {
    testWidgets('shows empty library hint when no files downloaded',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library_empty_hint')), findsOneWidget);
    });

    testWidgets('shows browse button', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('btn_pick_file')), findsOneWidget);
    });

    testWidgets('does not show continue bar when no firmware selected',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('btn_continue')), findsNothing);
    });

    testWidgets('shows continue bar when firmware is selected', (tester) async {
      final fw = FirmwareSource.localFile('/sdcard/firmware.bin');
      await tester.pumpWidget(_wrap(firmware: fw));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('btn_continue')), findsOneWidget);
      expect(find.byKey(const Key('selected_firmware_name')), findsOneWidget);
    });

    testWidgets('library list shows downloaded files and allows selection',
        (tester) async {
      final lib = _makeLibrary();
      const assetName = 'Heltec_v3_companion_radio_usb-v1.14.1-abc-merged.bin';
      File('${lib.cacheDir.path}/$assetName')
          .writeAsBytesSync([0xDE, 0xAD, 0xBE, 0xEF]);

      await tester.pumpWidget(_wrap(library: lib));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library_list')), findsOneWidget);
      expect(find.textContaining('Heltec v3'), findsWidgets);

      // Tapping the item should trigger onPicked (continue bar appears)
      await tester.tap(find.byKey(const Key('library_item_$assetName')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('btn_continue')), findsOneWidget);
    });
  });

  group('FirmwareScreen — Online tab', () {
    Future<void> _goOnline(WidgetTester tester) async {
      await tester.pumpWidget(_wrap());
      await tester.tap(find.byKey(const Key('tab_online')));
      await tester.pumpAndSettle();
    }

    testWidgets('shows two tabs', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.byKey(const Key('tab_local')), findsOneWidget);
      expect(find.byKey(const Key('tab_online')), findsOneWidget);
    });

    testWidgets('Online tab shows release picker', (tester) async {
      await _goOnline(tester);
      expect(find.byKey(const Key('release_picker')), findsOneWidget);
    });

    testWidgets('Online tab shows search bar', (tester) async {
      await _goOnline(tester);
      expect(find.byKey(const Key('firmware_search')), findsOneWidget);
    });

    testWidgets('Online tab lists devices', (tester) async {
      await _goOnline(tester);
      expect(find.byKey(const Key('asset_list')), findsOneWidget);
      // Heltec_v3 and RAK_4631 should appear
      expect(find.textContaining('Heltec'), findsWidgets);
      expect(find.textContaining('RAK'), findsWidgets);
    });

    testWidgets('search filters list', (tester) async {
      await _goOnline(tester);
      final search = find.byKey(const Key('firmware_search'));
      await tester.enterText(search, 'heltec');
      await tester.pump();
      expect(find.textContaining('Heltec'), findsWidgets);
      expect(find.textContaining('RAK'), findsNothing);
    });

    testWidgets('shows loading indicator while releases load', (tester) async {
      // Completer never completes → releases stay in loading state, no pending timers
      final completer = Completer<List<ReleaseInfo>>();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          meshcoreReleasesProvider.overrideWith((ref) => completer.future),
          firmwareLibraryServiceProvider.overrideWith(
            (ref) => Future.value(_makeLibrary()),
          ),
        ],
        child: const MaterialApp(home: FirmwareScreen()),
      ));
      await tester.tap(find.byKey(const Key('tab_online')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('releases_loading')), findsOneWidget);
    });

    testWidgets('shows error view on fetch failure', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          meshcoreReleasesProvider.overrideWith(
            (ref) => Future.error(Exception('network error')),
          ),
          firmwareLibraryServiceProvider.overrideWith(
            (ref) => Future.value(_makeLibrary()),
          ),
        ],
        child: const MaterialApp(home: FirmwareScreen()),
      ));
      await tester.tap(find.byKey(const Key('tab_online')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('releases_error')), findsOneWidget);
    });
  });
}
