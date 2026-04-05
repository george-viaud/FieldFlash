import 'dart:async';
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';
import 'package:field_flash/protocols/flash_protocol.dart';

/// [UsbConnection] backed by the usb_serial package (CDC-ACM).
/// Handles permission popup, baud-rate config, and DTR/RTS automatically.
class UsbSerialConnection implements UsbConnection {
  final UsbPort _port;

  UsbSerialConnection._(this._port);

  /// Opens the first recognized ESP32 USB serial device.
  /// Returns null if none found or open fails.
  static Future<UsbSerialConnection?> openEsp32() async {
    // Try each known ESP32 VID/PID + driver in priority order.
    final candidates = [
      (vid: 0x303A, pid: 0x1001, type: UsbSerial.CDC),   // ESP32-S3 native USB
      (vid: 0x10C4, pid: 0xEA60, type: UsbSerial.CP210x), // CP2102
      (vid: 0x1A86, pid: 0x55D4, type: UsbSerial.CH34x),  // CH343
    ];

    for (final c in candidates) {
      final port = await UsbSerial.create(c.vid, c.pid, c.type);
      if (port == null) continue;
      final ok = await port.open();
      if (!ok) { await port.close(); continue; }
      await port.setPortParameters(
        115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE,
      );
      return UsbSerialConnection._(port);
    }
    return null;
  }

  /// ESP32-S3 USB JTAG/Serial reset sequence (matches esptool-js usbJTAGSerialReset).
  /// Toggles DTR/RTS to put the device into ROM bootloader mode.
  Future<void> resetIntoBootloader() async {
    await _port.setDTR(false); await _port.setRTS(false);
    await Future.delayed(const Duration(milliseconds: 100));
    await _port.setDTR(true);  await _port.setRTS(false);
    await Future.delayed(const Duration(milliseconds: 100));
    await _port.setDTR(false); await _port.setRTS(true);
    await Future.delayed(const Duration(milliseconds: 100));
    await _port.setDTR(false); await _port.setRTS(false);
  }

  @override
  Future<int> write(Uint8List data) async {
    await _port.write(data);
    return data.length;
  }

  @override
  Future<Uint8List> read(int maxBytes, {Duration timeout = const Duration(milliseconds: 500)}) {
    final completer = Completer<Uint8List>();
    final buf = BytesBuilder();
    Timer? timer;
    StreamSubscription<Uint8List>? sub;

    void done() {
      timer?.cancel();
      sub?.cancel();
      if (!completer.isCompleted) completer.complete(buf.toBytes());
    }

    timer = Timer(timeout, done);
    sub = _port.inputStream?.listen(
      (chunk) {
        buf.add(chunk);
        if (buf.length >= maxBytes) done();
      },
      onError: (_) => done(),
      onDone: done,
    );

    return completer.future;
  }

  @override
  Future<void> close() async {
    await _port.close();
  }
}
