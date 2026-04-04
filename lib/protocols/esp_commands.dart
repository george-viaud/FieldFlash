import 'dart:typed_data';

// ESP ROM bootloader opcodes
const int kEspSync = 0x08;
const int kEspFlashBegin = 0x02;
const int kEspFlashData = 0x03;
const int kEspFlashEnd = 0x04;

/// XOR checksum of [data] seeded with 0xEF (ESP ROM convention).
int espChecksum(Uint8List data) {
  int cs = 0xEF;
  for (final b in data) {
    cs ^= b;
  }
  return cs;
}

/// Builds an 8-byte ESP ROM command header + [data].
///
/// Header layout (little-endian):
///   [0]   direction  0x00 = host→device
///   [1]   opcode
///   [2:3] data length (uint16 LE)
///   [4:7] checksum (uint32 LE)
Uint8List buildEspCommand({
  required int op,
  required Uint8List data,
  required int checksum,
}) {
  final buf = ByteData(8 + data.length);
  buf.setUint8(0, 0x00); // direction
  buf.setUint8(1, op);
  buf.setUint16(2, data.length, Endian.little);
  buf.setUint32(4, checksum, Endian.little);
  final result = buf.buffer.asUint8List();
  result.setRange(8, 8 + data.length, data);
  return result;
}

/// ESP_SYNC packet: 8-byte header + [0x07, 0x07, 0x12, 0x20] + 32×0x55
Uint8List buildSyncPacket() {
  final payload = Uint8List(36);
  payload[0] = 0x07;
  payload[1] = 0x07;
  payload[2] = 0x12;
  payload[3] = 0x20;
  payload.fillRange(4, 36, 0x55);
  return buildEspCommand(op: kEspSync, data: payload, checksum: 0);
}

/// ESP_FLASH_BEGIN: erases flash region and declares transfer parameters.
Uint8List buildFlashBeginPacket({
  required int eraseSize,
  required int numBlocks,
  required int blockSize,
  required int offset,
}) {
  final data = ByteData(16);
  data.setUint32(0, eraseSize, Endian.little);
  data.setUint32(4, numBlocks, Endian.little);
  data.setUint32(8, blockSize, Endian.little);
  data.setUint32(12, offset, Endian.little);
  return buildEspCommand(
    op: kEspFlashBegin,
    data: data.buffer.asUint8List(),
    checksum: 0,
  );
}

/// ESP_FLASH_DATA: sends one block of firmware data.
/// Payload: [dataLen(4), seq(4), 0(4), 0(4)] + data bytes
Uint8List buildFlashDataPacket({
  required Uint8List data,
  required int sequence,
}) {
  final header = ByteData(16);
  header.setUint32(0, data.length, Endian.little);
  header.setUint32(4, sequence, Endian.little);
  header.setUint32(8, 0, Endian.little);
  header.setUint32(12, 0, Endian.little);

  final payload = Uint8List(16 + data.length);
  payload.setRange(0, 16, header.buffer.asUint8List());
  payload.setRange(16, 16 + data.length, data);

  return buildEspCommand(
    op: kEspFlashData,
    data: payload,
    checksum: espChecksum(data),
  );
}

/// ESP_FLASH_END: signals end of transfer. [reboot]=true reboots device.
Uint8List buildFlashEndPacket({required bool reboot}) {
  final data = ByteData(4);
  data.setUint32(0, reboot ? 0x00 : 0x01, Endian.little);
  return buildEspCommand(
    op: kEspFlashEnd,
    data: data.buffer.asUint8List(),
    checksum: 0,
  );
}

/// Parsed ESP ROM response.
class EspResponse {
  final int op;
  final bool success;
  final int errorCode;

  const EspResponse({
    required this.op,
    required this.success,
    required this.errorCode,
  });
}

/// Parses a raw ESP ROM response packet. Returns null if not a device→host response.
/// Response layout: [0x01, op, size(2), value(4), status, error, ...]
EspResponse? parseEspResponse(Uint8List raw) {
  if (raw.isEmpty || raw[0] != 0x01) return null;
  if (raw.length < 10) return null;
  final op = raw[1];
  final status = raw[8];
  final errorCode = raw[9];
  return EspResponse(
    op: op,
    success: status == 0x00,
    errorCode: errorCode,
  );
}
