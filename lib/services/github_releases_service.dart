import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:field_flash/models/firmware_asset.dart';

class ReleaseInfo {
  final String tag;
  final String name;
  final String publishedAt;
  final String htmlUrl;
  final String releaseNotes;
  final List<FirmwareAsset> assets;

  const ReleaseInfo({
    required this.tag,
    required this.name,
    required this.publishedAt,
    required this.htmlUrl,
    required this.releaseNotes,
    required this.assets,
  });
}

class GithubReleasesService {
  static const _repo = 'meshcore-dev/MeshCore';
  static const _apiBase = 'https://api.github.com';

  final http.Client client;

  GithubReleasesService({http.Client? client})
      : client = client ?? http.Client();

  /// Fetches the latest releases from the MeshCore GitHub repo.
  Future<List<ReleaseInfo>> fetchReleases({int perPage = 10}) async {
    final uri = Uri.parse(
        '$_apiBase/repos/$_repo/releases?per_page=$perPage');
    final resp = await client.get(uri, headers: {
      'Accept': 'application/vnd.github+json',
    });
    if (resp.statusCode != 200) {
      throw Exception(
          'GitHub API error ${resp.statusCode}: ${resp.reasonPhrase}');
    }
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map(_parseRelease).toList();
  }

  ReleaseInfo _parseRelease(dynamic json) {
    final assets = (json['assets'] as List<dynamic>).map((a) {
      return FirmwareAsset.fromAssetName(
        name: a['name'] as String,
        downloadUrl: a['browser_download_url'] as String,
        sizeBytes: a['size'] as int,
      );
    }).toList();

    return ReleaseInfo(
      tag: json['tag_name'] as String,
      name: json['name'] as String,
      publishedAt: json['published_at'] as String,
      htmlUrl: json['html_url'] as String,
      releaseNotes: (json['body'] as String?) ?? '',
      assets: assets,
    );
  }

  /// Returns only the preferred asset per device+connection combination.
  /// merged.bin beats .bin; uf2 beats .zip.
  List<FirmwareAsset> preferredAssets(List<FirmwareAsset> assets) {
    final Map<String, FirmwareAsset> best = {};
    for (final asset in assets) {
      final key = '${asset.device}__${asset.connectionType.name}';
      final existing = best[key];
      if (existing == null || asset.isPreferred && !existing.isPreferred) {
        best[key] = asset;
      }
    }
    return best.values.toList()
      ..sort((a, b) => a.device.compareTo(b.device));
  }

  /// Filters preferred assets by [query] (case-insensitive device name match).
  /// Returns all preferred assets when [query] is empty.
  List<FirmwareAsset> searchAssets(List<FirmwareAsset> assets,
      {required String query}) {
    final preferred = preferredAssets(assets);
    if (query.isEmpty) return preferred;
    final q = query.toLowerCase();
    return preferred
        .where((a) => a.device.toLowerCase().contains(q))
        .toList();
  }
}
