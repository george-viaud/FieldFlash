enum ConnectionType { ble, usb, unknown }

enum FirmwareFormat { mergedBin, bin, uf2, zip, other }

/// A single downloadable firmware asset from a GitHub release.
class FirmwareAsset {
  final String name; // original filename
  final String downloadUrl;
  final int sizeBytes;
  final String device; // e.g. "Heltec_v3"
  final String version; // e.g. "v1.14.1"
  final ConnectionType connectionType;
  final FirmwareFormat format;

  const FirmwareAsset({
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.device,
    required this.version,
    required this.connectionType,
    required this.format,
  });

  /// Parse a MeshCore asset filename.
  /// Pattern: {Device}_companion_radio_{ble|usb}-{version}-{hash}[-merged].{ext}
  factory FirmwareAsset.fromAssetName({
    required String name,
    required String downloadUrl,
    required int sizeBytes,
  }) {
    // Split at "_companion_radio_"
    final companionIdx = name.indexOf('_companion_radio_');
    final device =
        companionIdx >= 0 ? name.substring(0, companionIdx) : name;

    // Connection type: look for "_ble-" or "_usb-"
    ConnectionType connType;
    if (name.contains('_radio_ble-')) {
      connType = ConnectionType.ble;
    } else if (name.contains('_radio_usb-')) {
      connType = ConnectionType.usb;
    } else {
      connType = ConnectionType.unknown;
    }

    // Version: first token starting with "v" after the connection type marker
    final versionMatch =
        RegExp(r'-(v\d+\.\d+\.\d+)-').firstMatch(name);
    final version = versionMatch?.group(1) ?? '';

    // Format
    FirmwareFormat fmt;
    if (name.endsWith('-merged.bin')) {
      fmt = FirmwareFormat.mergedBin;
    } else if (name.endsWith('.bin')) {
      fmt = FirmwareFormat.bin;
    } else if (name.endsWith('.uf2')) {
      fmt = FirmwareFormat.uf2;
    } else if (name.endsWith('.zip')) {
      fmt = FirmwareFormat.zip;
    } else {
      fmt = FirmwareFormat.other;
    }

    return FirmwareAsset(
      name: name,
      downloadUrl: downloadUrl,
      sizeBytes: sizeBytes,
      device: device,
      version: version,
      connectionType: connType,
      format: fmt,
    );
  }

  /// Human-readable device label: underscores → spaces.
  String get displayName => device.replaceAll('_', ' ');

  /// Whether this asset is the preferred variant for its device+connection.
  /// merged.bin > bin for ESP32; uf2 > zip for nRF52.
  bool get isPreferred =>
      format == FirmwareFormat.mergedBin || format == FirmwareFormat.uf2;

  /// Safe filename for local cache storage.
  String get cacheFileName => name;

  /// File extension for use with [FirmwareSource].
  String get fileExtension {
    if (format == FirmwareFormat.mergedBin) return '.bin';
    if (format == FirmwareFormat.bin) return '.bin';
    if (format == FirmwareFormat.uf2) return '.uf2';
    if (format == FirmwareFormat.zip) return '.zip';
    return '';
  }
}
