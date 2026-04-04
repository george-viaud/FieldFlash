import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:field_flash/models/device_profile.dart';
import 'package:field_flash/services/app_providers.dart';
import 'package:field_flash/services/usb_device_service.dart';
import 'package:field_flash/services/usb_bulk_connection.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  DeviceProfile? _manualOverride;

  @override
  void initState() {
    super.initState();
    _listenForUsbEvents();
  }

  void _listenForUsbEvents() {
    usbDeviceEvents.listen((event) {
      if (event['event'] == 'attached') {
        final vid = event['vendorId'] as int? ?? 0;
        final pid = event['productId'] as int? ?? 0;
        final name = event['deviceName'] as String?;
        final profile = UsbDeviceService.detect(vid: vid, pid: pid);
        if (profile != null && mounted) {
          ref.read(detectedDeviceProvider.notifier).state = profile;
          ref.read(detectedDeviceNameProvider.notifier).state = name;
        }
      } else if (event['event'] == 'detached') {
        if (mounted) {
          ref.read(detectedDeviceProvider.notifier).state = null;
          ref.read(detectedDeviceNameProvider.notifier).state = null;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final detected = ref.watch(detectedDeviceProvider);
    final effective = _manualOverride ?? detected;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('FieldFlash'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _UsbDiagram(),
            const SizedBox(height: 32),
            if (effective != null) ...[
              _DeviceCard(profile: effective),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('btn_continue'),
                onPressed: () => Navigator.of(context).pushNamed('/firmware'),
                child: const Text('Select Firmware →'),
              ),
            ] else ...[
              const Text(
                'Connect your device via USB-C',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 16),
              const _WaitingIndicator(),
            ],
            const Spacer(),
            _ManualOverrideDropdown(
              selected: _manualOverride,
              onChanged: (p) => setState(() => _manualOverride = p),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsbDiagram extends StatelessWidget {
  const _UsbDiagram();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(Icons.usb, size: 64, color: Colors.white38),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceProfile profile;
  const _DeviceCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green.shade900,
      child: ListTile(
        key: const Key('device_card'),
        leading: const Icon(Icons.developer_board, color: Colors.greenAccent),
        title: Text(profile.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${profile.vidPidString} · ${profile.protocol.name}',
          style: const TextStyle(color: Colors.white60),
        ),
      ),
    );
  }
}

class _WaitingIndicator extends StatelessWidget {
  const _WaitingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          key: Key('waiting_indicator'),
          strokeWidth: 2,
          color: Colors.white38,
        ),
      ),
    );
  }
}

class _ManualOverrideDropdown extends StatelessWidget {
  final DeviceProfile? selected;
  final ValueChanged<DeviceProfile?> onChanged;

  const _ManualOverrideDropdown({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final profiles = UsbDeviceService.allProfiles;
    return DropdownButtonFormField<DeviceProfile>(
      key: const Key('manual_override_dropdown'),
      value: selected,
      dropdownColor: Colors.grey.shade900,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'Manual device override',
        labelStyle: TextStyle(color: Colors.white54),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Auto-detect')),
        ...profiles.map((p) => DropdownMenuItem(
              value: p,
              child: Text(p.name),
            )),
      ],
      onChanged: onChanged,
    );
  }
}
