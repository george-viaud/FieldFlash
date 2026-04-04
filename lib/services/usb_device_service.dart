import 'package:field_flash/models/device_profile.dart';

/// Lookup table of known USB VID/PID combinations.
/// Entries with [pidWildcard]=true match any PID for the given VID.
class _Entry {
  final int vid;
  final int? pid; // null = wildcard (any PID for this VID)
  final DeviceProfile profile;

  const _Entry(this.vid, this.pid, this.profile);
}

class UsbDeviceService {
  static final List<_Entry> _table = [
    _Entry(
      0x303A,
      0x1001,
      const DeviceProfile(
        vid: 0x303A,
        pid: 0x1001,
        name: 'ESP32-S3 (native USB)',
        protocol: FlashProtocolType.espRom,
      ),
    ),
    _Entry(
      0x10C4,
      0xEA60,
      const DeviceProfile(
        vid: 0x10C4,
        pid: 0xEA60,
        name: 'CP2102 USB-UART (ESP32)',
        protocol: FlashProtocolType.espRom,
      ),
    ),
    _Entry(
      0x1A86,
      0x55D4,
      const DeviceProfile(
        vid: 0x1A86,
        pid: 0x55D4,
        name: 'CH343 USB-UART (ESP32)',
        protocol: FlashProtocolType.espRom,
      ),
    ),
    _Entry(
      0x2886,
      0x0044,
      const DeviceProfile(
        vid: 0x2886,
        pid: 0x0044,
        name: 'RAK4631 (nRF52840)',
        protocol: FlashProtocolType.nordicDfu,
      ),
    ),
    // Adafruit / nRF52 UF2: match any PID for VID 0x239A
    _Entry(
      0x239A,
      null,
      const DeviceProfile(
        vid: 0x239A,
        pid: 0x0000,
        name: 'Adafruit UF2 Device',
        protocol: FlashProtocolType.uf2,
      ),
    ),
  ];

  /// Returns a [DeviceProfile] for the given [vid]/[pid], or null if unknown.
  /// Exact VID+PID matches take priority; wildcard (PID=null) entries are fallback.
  static DeviceProfile? detect({required int vid, required int pid}) {
    // Exact match first
    for (final entry in _table) {
      if (entry.vid == vid && entry.pid == pid) return entry.profile;
    }
    // Wildcard VID match
    for (final entry in _table) {
      if (entry.vid == vid && entry.pid == null) return entry.profile;
    }
    return null;
  }

  /// All known device profiles (for display in manual-override UI).
  static List<DeviceProfile> get allProfiles =>
      _table.map((e) => e.profile).toList();
}
