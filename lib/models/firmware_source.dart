import 'package:path/path.dart' as p;

class FirmwareSource {
  final String _path;
  final bool isLocal;
  final String? repo;
  final String? tag;
  final String? _downloadUrl;

  FirmwareSource._({
    required String path,
    required this.isLocal,
    this.repo,
    this.tag,
    String? downloadUrl,
  })  : _path = path,
        _downloadUrl = downloadUrl;

  factory FirmwareSource.localFile(String filePath) => FirmwareSource._(
        path: filePath,
        isLocal: true,
      );

  factory FirmwareSource.githubRelease({
    required String repo,
    required String tag,
    required String assetName,
    required String downloadUrl,
  }) =>
      FirmwareSource._(
        path: assetName,
        isLocal: false,
        repo: repo,
        tag: tag,
        downloadUrl: downloadUrl,
      );

  String get displayName => p.basename(_path);

  String get fileExtension => p.extension(_path).toLowerCase();

  /// Absolute path to the file on disk (local files and cached downloads).
  String get filePath => isLocal ? _path : (_downloadUrl ?? _path);

  String? get downloadUrl => _downloadUrl;
}
