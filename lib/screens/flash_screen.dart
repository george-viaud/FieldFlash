import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:field_flash/models/flash_progress.dart';
import 'package:field_flash/protocols/esp_flash_protocol.dart';
import 'package:field_flash/services/app_providers.dart';
import 'package:field_flash/services/usb_serial_connection.dart';
import 'package:field_flash/models/device_profile.dart';

class FlashScreen extends ConsumerStatefulWidget {
  const FlashScreen({super.key, this.autoStart = true});

  /// Set to false in tests to prevent auto-starting the flash sequence.
  final bool autoStart;

  @override
  ConsumerState<FlashScreen> createState() => _FlashScreenState();
}

class _FlashScreenState extends ConsumerState<FlashScreen> {
  final List<String> _log = [];
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startFlash());
    }
  }

  Future<void> _startFlash() async {
    if (_started) return;
    _started = true;

    final device = ref.read(detectedDeviceProvider);
    final firmware = ref.read(selectedFirmwareProvider);

    if (device == null || firmware == null) {
      ref.read(flashStateProvider.notifier).state = FlashState.error;
      ref.read(flashProgressProvider.notifier).state =
          FlashProgress.error('No device or firmware selected');
      return;
    }

    ref.read(flashStateProvider.notifier).state = FlashState.flashing;

    // Load firmware bytes
    late Uint8List bytes;
    try {
      bytes = await File(firmware.filePath).readAsBytes();
    } catch (e) {
      ref.read(flashStateProvider.notifier).state = FlashState.error;
      ref.read(flashProgressProvider.notifier).state =
          FlashProgress.error('Cannot read firmware file: $e');
      return;
    }

    // Open device via usb_serial — handles permission popup and CDC setup.
    setState(() => _log.add('Opening USB device…'));
    UsbSerialConnection? conn = await UsbSerialConnection.openEsp32();
    if (conn == null) {
      ref.read(flashStateProvider.notifier).state = FlashState.error;
      ref.read(flashProgressProvider.notifier).state =
          FlashProgress.error('No USB device found — is it plugged in?');
      return;
    }

    // Reset into ROM bootloader via DTR/RTS (matches esptool-js behaviour).
    setState(() => _log.add('Resetting into bootloader…'));
    await conn.resetIntoBootloader();
    await conn.close();

    // Wait for device to reboot and re-enumerate.
    await Future.delayed(const Duration(milliseconds: 1500));

    // Re-open the fresh bootloader connection.
    conn = await UsbSerialConnection.openEsp32();
    if (conn == null) {
      ref.read(flashStateProvider.notifier).state = FlashState.error;
      ref.read(flashProgressProvider.notifier).state =
          FlashProgress.error('Device did not come back after reset — try again');
      return;
    }

    final protocol = _protocolFor(device);

    await for (final progress in protocol.flash(conn, bytes)) {
      if (!mounted) return;
      ref.read(flashProgressProvider.notifier).state = progress;
      setState(() => _log.add(progress.message));

      if (progress.isError) {
        ref.read(flashStateProvider.notifier).state = FlashState.error;
        return;
      }
    }

    ref.read(flashStateProvider.notifier).state = FlashState.done;
  }

  dynamic _protocolFor(DeviceProfile device) {
    switch (device.protocol) {
      case FlashProtocolType.espRom:
        return EspFlashProtocol();
      default:
        throw UnsupportedError('Protocol ${device.protocol} not implemented in MVP');
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(flashProgressProvider);
    final state = ref.watch(flashStateProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Flashing…'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProgressSection(progress: progress, state: state),
            const SizedBox(height: 24),
            Expanded(child: _LogView(log: _log)),
            if (state == FlashState.done || state == FlashState.error) ...[
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('btn_done'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      state == FlashState.done ? Colors.green : Colors.red,
                ),
                onPressed: () =>
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false),
                child: Text(state == FlashState.done ? 'Done ✓' : 'Back to Start'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final FlashProgress? progress;
  final FlashState state;

  const _ProgressSection({required this.progress, required this.state});

  @override
  Widget build(BuildContext context) {
    final pct = progress?.percentage ?? 0.0;
    final color = state == FlashState.error
        ? Colors.red
        : state == FlashState.done
            ? Colors.greenAccent
            : Colors.orange;

    return Column(
      children: [
        LinearProgressIndicator(
          key: const Key('flash_progress_bar'),
          value: pct,
          backgroundColor: Colors.white12,
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 12,
        ),
        const SizedBox(height: 8),
        Text(
          '${(pct * 100).toStringAsFixed(1)}%  —  ${progress?.message ?? ''}',
          style: TextStyle(color: color, fontSize: 13),
        ),
      ],
    );
  }
}

class _LogView extends StatelessWidget {
  final List<String> log;
  const _LogView({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: ListView.builder(
        key: const Key('flash_log'),
        reverse: true,
        itemCount: log.length,
        itemBuilder: (_, i) => Text(
          log[log.length - 1 - i],
          style: const TextStyle(
              color: Colors.white54, fontSize: 11, fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
