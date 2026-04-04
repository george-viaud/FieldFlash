import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:field_flash/models/firmware_asset.dart';
import 'package:field_flash/services/github_releases_service.dart';

class MockHttpClient extends Mock implements http.Client {}

// Minimal GitHub releases API response with two assets
const _fakeReleasesJson = '''
[
  {
    "tag_name": "companion-v1.14.1",
    "name": "Companion Firmware v1.14.1",
    "published_at": "2026-03-20T03:53:00Z",
    "html_url": "https://github.com/meshcore-dev/MeshCore/releases/tag/companion-v1.14.1",
    "body": "Bug fixes and improvements.",
    "assets": [
      {
        "name": "Heltec_v3_companion_radio_usb-v1.14.1-abc-merged.bin",
        "browser_download_url": "https://github.com/dl/Heltec_v3_companion_radio_usb-v1.14.1-abc-merged.bin",
        "size": 500000
      },
      {
        "name": "Heltec_v3_companion_radio_usb-v1.14.1-abc.bin",
        "browser_download_url": "https://github.com/dl/Heltec_v3_companion_radio_usb-v1.14.1-abc.bin",
        "size": 200000
      },
      {
        "name": "RAK_4631_companion_radio_usb-v1.14.1-abc.uf2",
        "browser_download_url": "https://github.com/dl/RAK_4631_companion_radio_usb-v1.14.1-abc.uf2",
        "size": 300000
      },
      {
        "name": "RAK_4631_companion_radio_usb-v1.14.1-abc.zip",
        "browser_download_url": "https://github.com/dl/RAK_4631_companion_radio_usb-v1.14.1-abc.zip",
        "size": 150000
      }
    ]
  },
  {
    "tag_name": "companion-v1.13.0",
    "name": "Companion Firmware v1.13.0",
    "published_at": "2026-02-01T10:00:00Z",
    "html_url": "https://github.com/meshcore-dev/MeshCore/releases/tag/companion-v1.13.0",
    "body": "Previous release.",
    "assets": []
  }
]
''';

void main() {
  late MockHttpClient client;
  late GithubReleasesService service;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() {
    client = MockHttpClient();
    service = GithubReleasesService(client: client);
  });

  void _stubReleases() {
    when(() => client.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => http.Response(_fakeReleasesJson, 200),
    );
  }

  group('GithubReleasesService.fetchReleases', () {
    test('returns list of releases', () async {
      _stubReleases();
      final releases = await service.fetchReleases();
      expect(releases.length, 2);
    });

    test('parses tag and display name', () async {
      _stubReleases();
      final releases = await service.fetchReleases();
      expect(releases.first.tag, 'companion-v1.14.1');
      expect(releases.first.name, 'Companion Firmware v1.14.1');
    });

    test('parses assets into FirmwareAsset list', () async {
      _stubReleases();
      final releases = await service.fetchReleases();
      expect(releases.first.assets.length, 4);
    });

    test('asset parsed correctly', () async {
      _stubReleases();
      final releases = await service.fetchReleases();
      final asset = releases.first.assets.first;
      expect(asset.device, 'Heltec_v3');
      expect(asset.format, FirmwareFormat.mergedBin);
    });

    test('throws on non-200 response', () async {
      when(() => client.get(any(), headers: any(named: 'headers')))
          .thenAnswer((_) async => http.Response('Not Found', 404));
      expect(service.fetchReleases(), throwsException);
    });
  });

  group('GithubReleasesService.preferredAssets', () {
    test('filters to preferred assets only', () async {
      _stubReleases();
      final releases = await service.fetchReleases();
      final preferred = service.preferredAssets(releases.first.assets);
      // merged.bin preferred over .bin; uf2 preferred over zip
      expect(preferred.every((a) => a.isPreferred), isTrue);
    });

    test('returns one asset per device+connection combo', () async {
      _stubReleases();
      final releases = await service.fetchReleases();
      final preferred = service.preferredAssets(releases.first.assets);
      // Heltec_v3+usb → 1, RAK_4631+usb → 1 = 2 total
      expect(preferred.length, 2);
    });

    test('search filters by device name (case-insensitive)', () async {
      _stubReleases();
      final releases = await service.fetchReleases();
      final results =
          service.searchAssets(releases.first.assets, query: 'heltec');
      expect(results.every((a) => a.device.toLowerCase().contains('heltec')),
          isTrue);
    });

    test('empty search returns all preferred assets', () async {
      _stubReleases();
      final releases = await service.fetchReleases();
      final results = service.searchAssets(releases.first.assets, query: '');
      expect(results, isNotEmpty);
    });
  });
}
