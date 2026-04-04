import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:field_flash/protocols/flash_protocol.dart';
import 'package:field_flash/protocols/esp_flash_protocol.dart';
import 'package:field_flash/protocols/slip.dart';
import 'package:field_flash/protocols/esp_commands.dart';
import 'package:field_flash/models/flash_progress.dart';

class MockUsbConnection extends Mock implements UsbConnection {}

/// Builds a SLIP-framed success response for the given opcode.
Uint8List _successResponse(int op) {
  final payload = Uint8List.fromList([
    0x01, op, 0x02, 0x00, // direction, op, size=2
    0x00, 0x00, 0x00, 0x00, // value
    0x00, 0x00, // status=ok, error=0
  ]);
  return slipEncode(payload);
}

void main() {
  late MockUsbConnection conn;
  late EspFlashProtocol protocol;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    conn = MockUsbConnection();
    protocol = EspFlashProtocol();
    when(() => conn.close()).thenAnswer((_) async {});
  });

  group('EspFlashProtocol', () {
    test('emits progress events and completes successfully', () async {
      // Firmware: 8KB so we get 2 blocks of 4KB
      final firmware = Uint8List(8192);

      // Respond with success to every command
      when(() => conn.write(any())).thenAnswer((_) async => 0);
      when(() => conn.read(any(), timeout: any(named: 'timeout')))
          .thenAnswer((_) async => _successResponse(kEspSync));

      final events = await protocol.flash(conn, firmware).toList();

      expect(events.last.isError, isFalse);
      expect(events.last.percentage, 1.0);
    });

    test('progress percentage increases monotonically', () async {
      final firmware = Uint8List(8192);

      when(() => conn.write(any())).thenAnswer((_) async => 0);
      when(() => conn.read(any(), timeout: any(named: 'timeout')))
          .thenAnswer((_) async => _successResponse(kEspSync));

      final events = await protocol.flash(conn, firmware).toList();
      final percentages = events.map((e) => e.percentage).toList();

      for (int i = 1; i < percentages.length; i++) {
        expect(
          percentages[i],
          greaterThanOrEqualTo(percentages[i - 1]),
          reason: 'percentage should not decrease at index $i',
        );
      }
    });

    test('emits error event on sync failure', () async {
      final firmware = Uint8List(1024);

      when(() => conn.write(any())).thenAnswer((_) async => 0);
      // Return empty bytes (timeout / no response) every time
      when(() => conn.read(any(), timeout: any(named: 'timeout')))
          .thenAnswer((_) async => Uint8List(0));

      final events = await protocol.flash(conn, firmware).toList();

      expect(events.last.isError, isTrue);
      expect(events.last.message, contains('sync'));
    });

    test('sends SYNC command first', () async {
      final firmware = Uint8List(256);
      final written = <Uint8List>[];

      when(() => conn.write(any())).thenAnswer((invocation) async {
        written.add(invocation.positionalArguments[0] as Uint8List);
        return 0;
      });
      when(() => conn.read(any(), timeout: any(named: 'timeout')))
          .thenAnswer((_) async => _successResponse(kEspSync));

      await protocol.flash(conn, firmware).toList();

      // First write should be a SLIP-framed SYNC packet
      expect(written, isNotEmpty);
      final firstFrame = written.first;
      final decoded = slipDecode(firstFrame);
      // opcode at byte 1 of decoded payload
      expect(decoded[1], kEspSync);
    });

    test('close() is called after flash completes', () async {
      final firmware = Uint8List(256);

      when(() => conn.write(any())).thenAnswer((_) async => 0);
      when(() => conn.read(any(), timeout: any(named: 'timeout')))
          .thenAnswer((_) async => _successResponse(kEspSync));
      when(() => conn.close()).thenAnswer((_) async {});

      await protocol.flash(conn, firmware).toList();

      verify(() => conn.close()).called(1);
    });

    test('close() is called even after sync failure', () async {
      final firmware = Uint8List(256);

      when(() => conn.write(any())).thenAnswer((_) async => 0);
      when(() => conn.read(any(), timeout: any(named: 'timeout')))
          .thenAnswer((_) async => Uint8List(0));
      when(() => conn.close()).thenAnswer((_) async {});

      await protocol.flash(conn, firmware).toList();

      verify(() => conn.close()).called(1);
    });
  });
}
