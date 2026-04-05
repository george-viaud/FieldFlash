import 'dart:async';
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';
import 'package:field_flash/protocols/flash_protocol.dart';

/// [UsbConnection] backed by the usb_serial package (CDC-ACM).
/// Handles permission popup, baud-rate config, and DTR/RTS automatically.
class UsbSerialConnection implements UsbConnection {
  final UsbPort _port;

  UsbSerialConnection._(this._port);

  /// Opens the first available USB serial device (any VID/PID).
  /// Uses listDevices() so it works regardless of chip type.
  static Future<UsbSerialConnection?> openEsp32() async {
    final devices = await UsbSerial.listDevices();
    if (devices.isEmpty) return null;

    for (final device in devices) {
      try {
        final type = _driverType(device.vid);
        final port = await device.create(type);
        if (port == null) continue;
        final ok = await port.open();
        if (!ok) { await port.close(); continue; }
        await port.setPortParameters(
          115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE,
        );
        return UsbSerialConnection._(port);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static String _driverType(int? vid) {
    switch (vid) {
      case 0x10C4: return UsbSerial.CP210x; // Silicon Labs CP2102/CP2104
      case 0x1A86: return UsbSerial.CH34x;  // QinHeng CH340/CH343
      case 0x0403: return UsbSerial.FTDI;   // FTDI FT232
      default:     return UsbSerial.CDC;    // ESP32-S3 native USB, CDC-ACM
    }
  }

  /// Classic esptool reset sequence for CP210x/CH34x boards (Heltec V3 etc).
  /// RTS → EN (reset), DTR → IO0 (boot mode select), both via inverters on board.
  Future<void> resetIntoBootloader() async {
    await _port.setDTR(false); await _port.setRTS(true);  // EN=LOW (reset), IO0=HIGH
    await Future.delayed(const Duration(milliseconds: 100));
    await _port.setDTR(true);  await _port.setRTS(false); // EN=HIGH (start), IO0=LOW (bootloader)
    await Future.delayed(const Duration(milliseconds: 50));
    await _port.setDTR(false);                            // release IO0
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
