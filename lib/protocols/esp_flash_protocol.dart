import 'dart:async';
import 'dart:typed_data';

import 'package:field_flash/models/flash_progress.dart';
import 'package:field_flash/protocols/esp_commands.dart';
import 'package:field_flash/protocols/flash_protocol.dart';
import 'package:field_flash/protocols/slip.dart';

const int _blockSize = 0x400; // 1KB blocks for reliable transfer
const int _syncRetries = 10;
const Duration _readTimeout = Duration(milliseconds: 1500);

class EspFlashProtocol implements FlashProtocol {
  @override
  Stream<FlashProgress> flash(
      UsbConnection connection, Uint8List firmware) async* {
    try {
      // --- Sync ---
      yield FlashProgress(
          bytesWritten: 0, totalBytes: firmware.length, message: 'Syncing…');

      final synced = await _sync(connection);
      if (!synced) {
        yield FlashProgress.error(
            'Failed to sync with device. Hold BOOT, tap RST, then retry.');
        return;
      }

      yield FlashProgress(
          bytesWritten: 0,
          totalBytes: firmware.length,
          message: 'Sync OK. Starting flash…');

      // --- Flash Begin ---
      final numBlocks = (firmware.length + _blockSize - 1) ~/ _blockSize;
      final beginPkt = buildFlashBeginPacket(
        eraseSize: firmware.length,
        numBlocks: numBlocks,
        blockSize: _blockSize,
        offset: 0x0000,
      );
      await connection.write(slipEncode(beginPkt));
      final beginResp = await _readResponse(connection);
      if (beginResp == null || !beginResp.success) {
        yield FlashProgress.error('FLASH_BEGIN failed');
        return;
      }

      // --- Flash Data blocks ---
      int bytesWritten = 0;
      for (int seq = 0; seq < numBlocks; seq++) {
        final start = seq * _blockSize;
        final end =
            (start + _blockSize).clamp(0, firmware.length) as int;
        final block = firmware.sublist(start, end);

        // Pad last block to blockSize
        final paddedBlock = Uint8List(_blockSize)..setRange(0, block.length, block);

        final dataPkt =
            buildFlashDataPacket(data: paddedBlock, sequence: seq);
        await connection.write(slipEncode(dataPkt));

        final dataResp = await _readResponse(connection);
        if (dataResp == null || !dataResp.success) {
          yield FlashProgress.error(
              'FLASH_DATA block $seq failed (error 0x${dataResp?.errorCode.toRadixString(16) ?? '?'})');
          return;
        }

        bytesWritten = end;
        yield FlashProgress(
          bytesWritten: bytesWritten,
          totalBytes: firmware.length,
          message:
              'Writing block ${seq + 1}/$numBlocks (${bytesWritten ~/ 1024} KB)',
        );
      }

      // --- Flash End ---
      final endPkt = buildFlashEndPacket(reboot: true);
      await connection.write(slipEncode(endPkt));
      // No response expected for FLASH_END in some ROM versions; best-effort read.
      await _readResponse(connection);

      yield FlashProgress.done(totalBytes: firmware.length);
    } finally {
      await connection.close();
    }
  }

  Future<bool> _sync(UsbConnection connection) async {
    // Drain any boot-log garbage already in the RX buffer.
    await connection.read(4096, timeout: const Duration(milliseconds: 300));

    for (int attempt = 0; attempt < _syncRetries; attempt++) {
      await connection.write(slipEncode(buildSyncPacket()));
      await Future.delayed(const Duration(milliseconds: 100));
      final resp = await _readResponse(connection);
      if (resp != null && resp.op == kEspSync) {
        // ESP ROM sends 8 SYNC response frames total — drain the remaining 7
        // so they don't corrupt subsequent command responses.
        for (int i = 0; i < 7; i++) {
          await _readResponse(connection);
        }
        return true;
      }
    }
    return false;
  }

  /// Reads raw bytes and extracts the first valid SLIP frame from anywhere
  /// in the buffer. The ESP32 may prepend boot-log text before the frame.
  Future<EspResponse?> _readResponse(UsbConnection connection) async {
    final raw = await connection.read(1024, timeout: _readTimeout);
    if (raw.isEmpty) return null;
    // Find the first 0xC0 delimiter — skip any leading boot-log text.
    final start = raw.indexOf(0xC0);
    if (start == -1) return null;
    try {
      final decoded = slipDecode(Uint8List.sublistView(raw, start));
      return parseEspResponse(decoded);
    } catch (_) {
      return null;
    }
  }
}
