import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:field_flash/protocols/esp_commands.dart';

void main() {
  group('EspChecksum', () {
    test('XOR of all bytes, initial value 0xEF', () {
      // Known value: single byte 0x01 → 0xEF ^ 0x01 = 0xEE
      expect(espChecksum(Uint8List.fromList([0x01])), 0xEE);
    });

    test('empty data returns seed 0xEF', () {
      expect(espChecksum(Uint8List(0)), 0xEF);
    });

    test('all-zero bytes returns seed unchanged', () {
      expect(espChecksum(Uint8List.fromList([0x00, 0x00, 0x00])), 0xEF);
    });
  });

  group('buildEspCommand', () {
    test('produces 8-byte header + data', () {
      final data = Uint8List.fromList([0xAA, 0xBB]);
      final pkt = buildEspCommand(op: 0x08, data: data, checksum: 0x00);
      expect(pkt.length, 8 + data.length);
    });

    test('header byte 0 is direction 0x00 (host→device)', () {
      final pkt = buildEspCommand(op: 0x08, data: Uint8List(0), checksum: 0);
      expect(pkt[0], 0x00);
    });

    test('header byte 1 is opcode', () {
      final pkt = buildEspCommand(op: 0x02, data: Uint8List(0), checksum: 0);
      expect(pkt[1], 0x02);
    });

    test('header bytes 2-3 are little-endian data length', () {
      final data = Uint8List(7);
      final pkt = buildEspCommand(op: 0x08, data: data, checksum: 0);
      final len = pkt[2] | (pkt[3] << 8);
      expect(len, 7);
    });

    test('header bytes 4-7 are little-endian checksum', () {
      final pkt = buildEspCommand(op: 0x08, data: Uint8List(0), checksum: 0xDEADBEEF);
      final bd = ByteData.sublistView(pkt);
      expect(bd.getUint32(4, Endian.little), 0xDEADBEEF);
    });
  });

  group('buildSyncPacket', () {
    test('is 36 bytes of data (8 header + 28 payload)', () {
      // SYNC data is: [0x07, 0x07, 0x12, 0x20] + 32×0x55
      final pkt = buildSyncPacket();
      expect(pkt.length, 8 + 36);
    });

    test('opcode is ESP_SYNC = 0x08', () {
      final pkt = buildSyncPacket();
      expect(pkt[1], 0x08);
    });
  });

  group('buildFlashBeginPacket', () {
    test('opcode is ESP_FLASH_BEGIN = 0x02', () {
      final pkt = buildFlashBeginPacket(
        eraseSize: 0x1000,
        numBlocks: 1,
        blockSize: 0x400,
        offset: 0x10000,
      );
      expect(pkt[1], 0x02);
    });

    test('data is 16 bytes: eraseSize, numBlocks, blockSize, offset', () {
      final pkt = buildFlashBeginPacket(
        eraseSize: 0x1000,
        numBlocks: 4,
        blockSize: 0x400,
        offset: 0x10000,
      );
      final bd = ByteData.sublistView(pkt, 8); // skip header
      expect(bd.getUint32(0, Endian.little), 0x1000);  // eraseSize
      expect(bd.getUint32(4, Endian.little), 4);        // numBlocks
      expect(bd.getUint32(8, Endian.little), 0x400);   // blockSize
      expect(bd.getUint32(12, Endian.little), 0x10000); // offset
    });
  });

  group('buildFlashDataPacket', () {
    test('opcode is ESP_FLASH_DATA = 0x03', () {
      final data = Uint8List(16);
      final pkt = buildFlashDataPacket(data: data, sequence: 0);
      expect(pkt[1], 0x03);
    });

    test('payload header: dataLen, seq, 0, 0 then data', () {
      final data = Uint8List.fromList(List.generate(8, (i) => i));
      final pkt = buildFlashDataPacket(data: data, sequence: 3);
      final bd = ByteData.sublistView(pkt, 8); // skip command header
      expect(bd.getUint32(0, Endian.little), 8); // data length
      expect(bd.getUint32(4, Endian.little), 3); // sequence
    });

    test('checksum in command header matches XOR of data bytes', () {
      final data = Uint8List.fromList([0x01, 0x02]);
      final pkt = buildFlashDataPacket(data: data, sequence: 0);
      final bd = ByteData.sublistView(pkt);
      final cs = bd.getUint32(4, Endian.little);
      expect(cs, espChecksum(data));
    });
  });

  group('buildFlashEndPacket', () {
    test('opcode is ESP_FLASH_END = 0x04', () {
      final pkt = buildFlashEndPacket(reboot: true);
      expect(pkt[1], 0x04);
    });

    test('reboot=true sets flag 0x00 (reboot)', () {
      final pkt = buildFlashEndPacket(reboot: true);
      final flag = ByteData.sublistView(pkt, 8).getUint32(0, Endian.little);
      expect(flag, 0x00);
    });

    test('reboot=false sets flag 0x01 (stay in bootloader)', () {
      final pkt = buildFlashEndPacket(reboot: false);
      final flag = ByteData.sublistView(pkt, 8).getUint32(0, Endian.little);
      expect(flag, 0x01);
    });
  });

  group('parseEspResponse', () {
    test('returns null for non-response direction byte', () {
      final raw = Uint8List.fromList([0x00, 0x08, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00]);
      expect(parseEspResponse(raw), isNull);
    });

    test('parses success response', () {
      // direction=0x01, op=0x08, size=2, value=0, status=0x00, error=0x00
      final raw = Uint8List.fromList([0x01, 0x08, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
      final resp = parseEspResponse(raw)!;
      expect(resp.op, 0x08);
      expect(resp.success, isTrue);
    });

    test('parses error response', () {
      // status byte = 0x01 means error
      final raw = Uint8List.fromList([0x01, 0x08, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x05]);
      final resp = parseEspResponse(raw)!;
      expect(resp.success, isFalse);
      expect(resp.errorCode, 0x05);
    });
  });
}
