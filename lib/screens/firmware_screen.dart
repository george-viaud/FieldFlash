import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:field_flash/models/firmware_asset.dart';
import 'package:field_flash/models/firmware_source.dart';
import 'package:field_flash/services/app_providers.dart';
import 'package:field_flash/services/github_releases_service.dart';

class FirmwareScreen extends ConsumerStatefulWidget {
  const FirmwareScreen({super.key});

  @override
  ConsumerState<FirmwareScreen> createState() => _FirmwareScreenState();
}

class _FirmwareScreenState extends ConsumerState<FirmwareScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _searchQuery = '';
  String? _selectedTag;
  // Per-asset download progress (0.0–1.0), null = not downloading
  final Map<String, double?> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedFirmwareProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Select Firmware'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.white38,
          indicatorColor: Colors.orange,
          tabs: const [
            Tab(key: Key('tab_local'), text: 'Local', icon: Icon(Icons.folder_open)),
            Tab(key: Key('tab_online'), text: 'Online', icon: Icon(Icons.cloud_download)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _LocalTab(
                  selected: selected,
                  onPicked: (src) =>
                      ref.read(selectedFirmwareProvider.notifier).state = src,
                ),
                _OnlineTab(
                  searchQuery: _searchQuery,
                  selectedTag: _selectedTag,
                  downloadProgress: _downloadProgress,
                  onSearchChanged: (q) => setState(() => _searchQuery = q),
                  onTagChanged: (t) => setState(() => _selectedTag = t),
                  onSelect: (src) =>
                      ref.read(selectedFirmwareProvider.notifier).state = src,
                  onDownloadProgressUpdate: (name, p) =>
                      setState(() => _downloadProgress[name] = p),
                ),
              ],
            ),
          ),
          if (selected != null) ...[
            _SelectedBar(
              source: selected,
              onContinue: () => Navigator.of(context).pushNamed('/preflash'),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Local Tab ───────────────────────────────────────────────────────────────

class _LocalTab extends ConsumerWidget {
  final FirmwareSource? selected;
  final ValueChanged<FirmwareSource> onPicked;

  const _LocalTab({required this.selected, required this.onPicked});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(firmwareLibraryServiceProvider);

    return libraryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.orange)),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
      data: (library) {
        // Scan files directly so we always have the real File.path — no
        // existsSync() guesswork in the tap handler.
        final files = library.cacheDir.existsSync()
            ? (library.cacheDir.listSync().whereType<File>().toList()
              ..sort((a, b) => a.path.compareTo(b.path)))
            : <File>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Library section ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      color: Colors.white38, size: 16),
                  const SizedBox(width: 8),
                  const Text('Firmware Library',
                      style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.8)),
                  const Spacer(),
                  Text('${files.length} file${files.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: Colors.white24, fontSize: 12)),
                ],
              ),
            ),
            if (files.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'No firmware downloaded yet.\nUse the Online tab to fetch MeshCore releases.',
                  key: Key('library_empty_hint'),
                  style: TextStyle(color: Colors.white24, fontSize: 13, height: 1.5),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  key: const Key('library_list'),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: files.length,
                  itemBuilder: (_, i) {
                    final file = files[i];
                    final filename = file.uri.pathSegments.last;
                    final asset = FirmwareAsset.fromAssetName(
                      name: filename,
                      downloadUrl: file.path,
                      sizeBytes: file.lengthSync(),
                    );
                    // Compare by filename so isSelected works after picking
                    final isSelected = selected?.displayName == filename;
                    return ListTile(
                      key: Key('library_item_$filename'),
                      leading: Icon(
                        Icons.memory,
                        color: isSelected ? Colors.orange : Colors.white38,
                      ),
                      title: Text(asset.displayName,
                          style: TextStyle(
                              color: isSelected ? Colors.orange : Colors.white70,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      subtitle: Text(
                        '${asset.version} · ${asset.format.name}',
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: Colors.orange, size: 20),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.white24, size: 20),
                            tooltip: 'Remove from library',
                            onPressed: () async {
                              await library.delete(asset);
                              ref.invalidate(firmwareLibraryServiceProvider);
                            },
                          ),
                        ],
                      ),
                      // Use the real file.path — no existsSync() lookup needed
                      onTap: () => onPicked(FirmwareSource.localFile(file.path)),
                    );
                  },
                ),
              ),
            if (files.isEmpty) const Spacer(),
            // ── Browse for file outside library ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: OutlinedButton.icon(
                key: const Key('btn_pick_file'),
                onPressed: () => _pick(context),
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Browse for file…'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white38,
                    side: const BorderSide(color: Colors.white12)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pick(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['bin', 'uf2', 'zip'],
    );
    if (result != null && result.files.single.path != null) {
      onPicked(FirmwareSource.localFile(result.files.single.path!));
    }
  }
}

// ─── Online Tab ──────────────────────────────────────────────────────────────

class _OnlineTab extends ConsumerWidget {
  final String searchQuery;
  final String? selectedTag;
  final Map<String, double?> downloadProgress;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<FirmwareSource> onSelect;
  final void Function(String assetName, double? progress)
      onDownloadProgressUpdate;

  const _OnlineTab({
    required this.searchQuery,
    required this.selectedTag,
    required this.downloadProgress,
    required this.onSearchChanged,
    required this.onTagChanged,
    required this.onSelect,
    required this.onDownloadProgressUpdate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releasesAsync = ref.watch(meshcoreReleasesProvider);
    final libraryAsync = ref.watch(firmwareLibraryServiceProvider);

    return releasesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          key: Key('releases_loading'),
          color: Colors.orange,
        ),
      ),
      error: (e, _) => _ErrorView(
        key: const Key('releases_error'),
        message: e.toString(),
        onRetry: () => ref.invalidate(meshcoreReleasesProvider),
      ),
      data: (releases) {
        if (releases.isEmpty) {
          return const Center(
            child: Text('No releases found.',
                style: TextStyle(color: Colors.white38)),
          );
        }
        final tag = selectedTag ?? releases.first.tag;
        final release = releases.firstWhere((r) => r.tag == tag,
            orElse: () => releases.first);
        final svc = ref.read(githubReleasesServiceProvider);
        final assets =
            svc.searchAssets(release.assets, query: searchQuery);

        return libraryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(message: e.toString(), onRetry: () {}),
          data: (library) => Column(
            children: [
              _ReleasePickerBar(
                releases: releases,
                selectedTag: tag,
                onChanged: onTagChanged,
              ),
              _SearchBar(
                key: const Key('firmware_search'),
                onChanged: onSearchChanged,
              ),
              Expanded(
                child: _AssetList(
                  key: const Key('asset_list'),
                  assets: assets,
                  library: library,
                  downloadProgress: downloadProgress,
                  onDownload: (asset) =>
                      _download(context, ref, asset, library, release),
                  onSelect: (asset) => _selectCached(asset, library),
                  onDelete: (asset) async {
                    await library.delete(asset);
                    ref.invalidate(firmwareLibraryServiceProvider);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    FirmwareAsset asset,
    dynamic library,
    ReleaseInfo release,
  ) async {
    onDownloadProgressUpdate(asset.name, 0.0);
    try {
      await library.download(asset, onProgress: (p) {
        onDownloadProgressUpdate(asset.name, p);
      });
      onDownloadProgressUpdate(asset.name, null);
      ref.invalidate(firmwareLibraryServiceProvider);
    } catch (e) {
      onDownloadProgressUpdate(asset.name, null);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Download failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _selectCached(FirmwareAsset asset, dynamic library) {
    final path = library.cachedPath(asset);
    if (path != null) {
      onSelect(FirmwareSource.githubRelease(
        repo: 'meshcore-dev/MeshCore',
        tag: asset.version,
        assetName: asset.name,
        downloadUrl: path,
      ));
    }
  }
}

class _ReleasePickerBar extends StatelessWidget {
  final List<ReleaseInfo> releases;
  final String selectedTag;
  final ValueChanged<String?> onChanged;

  const _ReleasePickerBar({
    required this.releases,
    required this.selectedTag,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DropdownButtonFormField<String>(
        key: const Key('release_picker'),
        value: selectedTag,
        dropdownColor: Colors.grey.shade900,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          labelText: 'Release',
          labelStyle: TextStyle(color: Colors.white54),
          enabledBorder:
              OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: releases
            .map((r) => DropdownMenuItem(
                  value: r.tag,
                  child: Text('${r.name} (${r.tag})',
                      style: const TextStyle(color: Colors.white70)),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchBar({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Filter by device name…',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _AssetList extends StatelessWidget {
  final List<FirmwareAsset> assets;
  final dynamic library; // FirmwareLibraryService
  final Map<String, double?> downloadProgress;
  final ValueChanged<FirmwareAsset> onDownload;
  final ValueChanged<FirmwareAsset> onSelect;
  final ValueChanged<FirmwareAsset> onDelete;

  const _AssetList({
    super.key,
    required this.assets,
    required this.library,
    required this.downloadProgress,
    required this.onDownload,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return const Center(
        child: Text('No matching devices.',
            style: TextStyle(color: Colors.white38)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: assets.length,
      itemBuilder: (_, i) => _AssetTile(
        asset: assets[i],
        cached: library.isCached(assets[i]) as bool,
        progress: downloadProgress[assets[i].name],
        onDownload: () => onDownload(assets[i]),
        onSelect: () => onSelect(assets[i]),
        onDelete: () => onDelete(assets[i]),
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  final FirmwareAsset asset;
  final bool cached;
  final double? progress; // null = idle, 0–1 = downloading
  final VoidCallback onDownload;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  const _AssetTile({
    required this.asset,
    required this.cached,
    required this.progress,
    required this.onDownload,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloading = progress != null;
    final connLabel =
        asset.connectionType == ConnectionType.usb ? 'USB' : 'BLE';
    final fmtLabel = asset.format == FirmwareFormat.mergedBin
        ? 'merged.bin'
        : asset.format.name;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: Colors.white.withOpacity(0.05),
      child: Column(
        children: [
          ListTile(
            key: Key('asset_${asset.name}'),
            leading: Icon(
              cached ? Icons.check_circle : Icons.memory_outlined,
              color: cached ? Colors.greenAccent : Colors.white38,
            ),
            title: Text(asset.displayName,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500)),
            subtitle: Text('$connLabel · $fmtLabel · ${asset.version}',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
            trailing: _TrailingActions(
              cached: cached,
              isDownloading: isDownloading,
              onDownload: onDownload,
              onSelect: onSelect,
              onDelete: onDelete,
            ),
          ),
          if (isDownloading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white12,
                valueColor:
                    const AlwaysStoppedAnimation(Colors.orange),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrailingActions extends StatelessWidget {
  final bool cached;
  final bool isDownloading;
  final VoidCallback onDownload;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  const _TrailingActions({
    required this.cached,
    required this.isDownloading,
    required this.onDownload,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (isDownloading) {
      return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange));
    }
    if (cached) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: onSelect,
            child: const Text('Use', style: TextStyle(color: Colors.greenAccent)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white24),
            tooltip: 'Delete from library',
            onPressed: onDelete,
          ),
        ],
      );
    }
    return IconButton(
      icon: const Icon(Icons.download, color: Colors.orange),
      tooltip: 'Download',
      onPressed: onDownload,
    );
  }
}

// ─── Selected bar / continue ─────────────────────────────────────────────────

class _SelectedBar extends StatelessWidget {
  final FirmwareSource source;
  final VoidCallback onContinue;

  const _SelectedBar({required this.source, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.orange.shade900.withOpacity(0.95),
          border: const Border(top: BorderSide(color: Colors.orange, width: 1.5)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Row(
          children: [
            const Icon(Icons.memory, color: Colors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source.displayName,
                      key: const Key('selected_firmware_name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(source.isLocal ? 'Local file' : 'MeshCore ${source.tag}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const Key('btn_continue'),
              onPressed: onContinue,
              icon: const Icon(Icons.bolt, size: 18),
              label: const Text('Flash →'),
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error view ──────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Colors.white24, size: 48),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
