import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:field_flash/models/firmware_asset.dart';
import 'package:field_flash/services/firmware_library_service.dart';

class MockHttpClient extends Mock implements http.Client {}

FirmwareAsset _asset({
  String device = 'Heltec_v3',
  FirmwareFormat format = FirmwareFormat.mergedBin,
  String version = 'v1.14.1',
}) {
  final ext = format == FirmwareFormat.uf2 ? '.uf2' : '-merged.bin';
  final name = '${device}_companion_radio_usb-$version-abc$ext';
  return FirmwareAsset(
    name: name,
    downloadUrl: 'https://example.com/$name',
    sizeBytes: 1024,
    device: device,
    version: version,
    connectionType: ConnectionType.usb,
    format: format,
  );
}

void main() {
  late MockHttpClient client;
  late Directory tmpDir;
  late FirmwareLibraryService service;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  setUp(() async {
    client = MockHttpClient();
    tmpDir = await Directory.systemTemp.createTemp('fw_test_');
    service = FirmwareLibraryService(
      cacheDir: tmpDir,
      httpClient: client,
    );
  });

  tearDown(() async {
    await tmpDir.delete(recursive: true);
  });

  group('FirmwareLibraryService', () {
    test('isCached returns false for unknown asset', () {
      expect(service.isCached(_asset()), isFalse);
    });

    test('download writes file to cache dir', () async {
      final bytes = Uint8List.fromList(List.generate(256, (i) => i & 0xFF));
      when(() => client.get(any())).thenAnswer(
          (_) async => http.Response.bytes(bytes, 200));

      final asset = _asset();
      await service.download(asset, onProgress: (_) {});

      expect(service.isCached(asset), isTrue);
      final cached = File('${tmpDir.path}/${asset.cacheFileName}');
      expect(await cached.readAsBytes(), bytes);
    });

    test('cachedPath returns path after download', () async {
      final bytes = Uint8List.fromList([0xDE, 0xAD]);
      when(() => client.get(any())).thenAnswer(
          (_) async => http.Response.bytes(bytes, 200));

      final asset = _asset();
      await service.download(asset, onProgress: (_) {});
      final path = service.cachedPath(asset);
      expect(path, isNotNull);
      expect(File(path!).existsSync(), isTrue);
    });

    test('cachedAssets lists all downloaded files', () async {
      final bytes = Uint8List.fromList([0x01]);
      when(() => client.get(any())).thenAnswer(
          (_) async => http.Response.bytes(bytes, 200));

      final a1 = _asset(device: 'Heltec_v3');
      final a2 = _asset(device: 'RAK_4631', format: FirmwareFormat.uf2);
      await service.download(a1, onProgress: (_) {});
      await service.download(a2, onProgress: (_) {});

      final cached = service.cachedAssets();
      expect(cached.length, 2);
    });

    test('delete removes file and marks as not cached', () async {
      final bytes = Uint8List.fromList([0x01]);
      when(() => client.get(any())).thenAnswer(
          (_) async => http.Response.bytes(bytes, 200));

      final asset = _asset();
      await service.download(asset, onProgress: (_) {});
      expect(service.isCached(asset), isTrue);

      await service.delete(asset);
      expect(service.isCached(asset), isFalse);
    });

    test('onProgress callback receives increasing values ending at 1.0', () async {
      final bytes = Uint8List.fromList(List.generate(1024, (i) => i & 0xFF));
      when(() => client.get(any())).thenAnswer(
          (_) async => http.Response.bytes(bytes, 200));

      final progressValues = <double>[];
      await service.download(_asset(), onProgress: progressValues.add);

      expect(progressValues.last, 1.0);
      for (int i = 1; i < progressValues.length; i++) {
        expect(progressValues[i], greaterThanOrEqualTo(progressValues[i - 1]));
      }
    });

    test('throws on HTTP error', () async {
      when(() => client.get(any())).thenAnswer(
          (_) async => http.Response('Not Found', 404));
      expect(service.download(_asset(), onProgress: (_) {}), throwsException);
    });
  });
}
