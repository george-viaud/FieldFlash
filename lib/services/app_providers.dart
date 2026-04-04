import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:field_flash/models/device_profile.dart';
import 'package:field_flash/models/firmware_source.dart';
import 'package:field_flash/models/flash_progress.dart';
import 'package:field_flash/services/github_releases_service.dart';
import 'package:field_flash/services/firmware_library_service.dart';

// Currently connected/detected device (null = not connected)
final detectedDeviceProvider = StateProvider<DeviceProfile?>((ref) => null);

// Selected firmware source (null = not chosen)
final selectedFirmwareProvider = StateProvider<FirmwareSource?>((ref) => null);

// Flash state
enum FlashState { idle, flashing, done, error }

final flashStateProvider = StateProvider<FlashState>((ref) => FlashState.idle);

// Live flash progress events
final flashProgressProvider = StateProvider<FlashProgress?>((ref) => null);

// GitHub releases service (singleton)
final githubReleasesServiceProvider = Provider<GithubReleasesService>(
  (ref) => GithubReleasesService(),
);

// Firmware library service (async — needs app documents dir)
final firmwareLibraryServiceProvider =
    FutureProvider<FirmwareLibraryService>((ref) async {
  return FirmwareLibraryService.create();
});

// Fetched MeshCore releases (null = not yet loaded)
final meshcoreReleasesProvider =
    FutureProvider<List<ReleaseInfo>>((ref) async {
  final svc = ref.watch(githubReleasesServiceProvider);
  return svc.fetchReleases();
});
