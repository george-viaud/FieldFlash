import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:field_flash/services/usb_device_service.dart';
import 'package:field_flash/models/device_profile.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Known Devices',
            style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          ...UsbDeviceService.allProfiles.map(_buildDeviceTile),
          const Divider(color: Colors.white12, height: 40),
          const Text(
            'Theme',
            style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          const ListTile(
            leading: Icon(Icons.dark_mode, color: Colors.white54),
            title: Text('Dark mode', style: TextStyle(color: Colors.white70)),
            trailing: Text('Always', style: TextStyle(color: Colors.white38)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(DeviceProfile p) {
    return ListTile(
      leading: const Icon(Icons.developer_board, color: Colors.white38),
      title: Text(p.name, style: const TextStyle(color: Colors.white70)),
      subtitle: Text(
        '${p.vidPidString} · ${p.protocol.name}',
        style: const TextStyle(color: Colors.white38, fontSize: 12),
      ),
    );
  }
}
