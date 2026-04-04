import 'dart:typed_data';
import 'package:field_flash/models/flash_progress.dart';

/// Abstracts raw USB bulk-transfer access so protocols can be tested without hardware.
abstract class UsbConnection {
  /// Writes [data] to the device. Returns bytes written or throws on error.
  Future<int> write(Uint8List data);

  /// Reads up to [maxBytes] from the device within [timeout].
  /// Returns empty list on timeout.
  Future<Uint8List> read(int maxBytes, {Duration timeout});

  /// Closes the connection.
  Future<void> close();
}

/// Base class for all chip-family flash protocols.
abstract class FlashProtocol {
  /// Flash [firmware] bytes onto the device via [connection].
  /// Yields [FlashProgress] events; last event is either [FlashProgress.done]
  /// or [FlashProgress.error].
  Stream<FlashProgress> flash(UsbConnection connection, Uint8List firmware);
}
