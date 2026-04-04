enum FlashProtocolType { espRom, nordicDfu, uf2 }

class DeviceProfile {
  final int vid;
  final int pid;
  final String name;
  final FlashProtocolType protocol;

  const DeviceProfile({
    required this.vid,
    required this.pid,
    required this.name,
    required this.protocol,
  });

  String get vidPidString =>
      '0x${vid.toRadixString(16).padLeft(4, '0')}:'
      '0x${pid.toRadixString(16).padLeft(4, '0')}';

  @override
  bool operator ==(Object other) =>
      other is DeviceProfile && other.vid == vid && other.pid == pid;

  @override
  int get hashCode => Object.hash(vid, pid);

  @override
  String toString() => 'DeviceProfile($name, $vidPidString, $protocol)';
}
