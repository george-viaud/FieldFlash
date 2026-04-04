import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:field_flash/models/firmware_asset.dart';

class FirmwareLibraryService {
  final Directory cacheDir;
  final http.Client httpClient;

  FirmwareLibraryService({
    required this.cacheDir,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  /// Creates a service using the app's documents directory as cache.
  static Future<FirmwareLibraryService> create() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/firmware_library');
    await dir.create(recursive: true);
    return FirmwareLibraryService(cacheDir: dir);
  }

  File _fileFor(FirmwareAsset asset) =>
      File('${cacheDir.path}/${asset.cacheFileName}');

  bool isCached(FirmwareAsset asset) => _fileFor(asset).existsSync();

  String? cachedPath(FirmwareAsset asset) {
    final f = _fileFor(asset);
    return f.existsSync() ? f.path : null;
  }

  /// Downloads [asset] and saves to cache. Calls [onProgress] with 0.0–1.0.
  Future<void> download(
    FirmwareAsset asset, {
    required void Function(double) onProgress,
  }) async {
    final resp = await httpClient.get(Uri.parse(asset.downloadUrl));
    if (resp.statusCode != 200) {
      throw Exception('Download failed: HTTP ${resp.statusCode}');
    }

    final bytes = resp.bodyBytes;
    final file = _fileFor(asset);

    // Write in chunks so onProgress fires
    const chunkSize = 4096;
    final sink = file.openWrite();
    int written = 0;
    final total = bytes.length;
    while (written < total) {
      final end = (written + chunkSize).clamp(0, total);
      sink.add(bytes.sublist(written, end));
      written = end;
      onProgress(total > 0 ? written / total : 1.0);
    }
    await sink.close();
    onProgress(1.0);
  }

  /// All assets currently in the local cache (by scanning cache dir).
  List<FirmwareAsset> cachedAssets() {
    if (!cacheDir.existsSync()) return [];
    return cacheDir
        .listSync()
        .whereType<File>()
        .map((f) => FirmwareAsset.fromAssetName(
              name: f.uri.pathSegments.last,
              downloadUrl: '',
              sizeBytes: f.lengthSync(),
            ))
        .toList();
  }

  Future<void> delete(FirmwareAsset asset) async {
    final f = _fileFor(asset);
    if (f.existsSync()) await f.delete();
  }
}
