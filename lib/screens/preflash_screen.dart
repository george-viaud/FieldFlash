import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:field_flash/models/device_profile.dart';
import 'package:field_flash/services/app_providers.dart';

class PreFlashScreen extends ConsumerWidget {
  const PreFlashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(detectedDeviceProvider);
    final firmware = ref.watch(selectedFirmwareProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Pre-Flash Checklist'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (device != null) _BootModeInstructions(device: device),
            const SizedBox(height: 24),
            _ChecklistItem(
              key: const Key('check_battery'),
              label: 'Battery or power supply connected',
            ),
            _ChecklistItem(
              key: const Key('check_firmware'),
              label: 'Firmware matches device: ${device?.name ?? '?'}',
            ),
            _ChecklistItem(
              key: const Key('check_file'),
              label: 'File: ${firmware?.displayName ?? '?'}',
            ),
            const Spacer(),
            FilledButton(
              key: const Key('btn_start_flash'),
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.of(context).pushNamed('/flash'),
              child: const Text("I'm ready — Start Flash"),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootModeInstructions extends StatelessWidget {
  final DeviceProfile device;
  const _BootModeInstructions({required this.device});

  @override
  Widget build(BuildContext context) {
    final isEsp = device.protocol == FlashProtocolType.espRom;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Boot mode',
              style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            isEsp
                ? 'The app will reset the device into bootloader mode automatically via USB — no button press needed.\n\nJust make sure the device is powered and connected.'
                : '1. Double-tap RESET quickly\n2. LED will pulse — bootloader active',
            style: const TextStyle(color: Colors.white70, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatefulWidget {
  final String label;
  const _ChecklistItem({super.key, required this.label});

  @override
  State<_ChecklistItem> createState() => _ChecklistItemState();
}

class _ChecklistItemState extends State<_ChecklistItem> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: _checked,
      onChanged: (v) => setState(() => _checked = v ?? false),
      title: Text(widget.label, style: const TextStyle(color: Colors.white70)),
      activeColor: Colors.greenAccent,
      checkColor: Colors.black,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
