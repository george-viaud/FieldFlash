import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:field_flash/protocols/flash_protocol.dart';

const _channel = MethodChannel('com.inwmesh.field_flash/usb_bulk');

/// [UsbConnection] implementation backed by the Android UsbBulkTransferPlugin.
class UsbBulkConnection implements UsbConnection {
  final String deviceName;

  UsbBulkConnection(this.deviceName);

  @override
  Future<int> write(Uint8List data) async {
    final result = await _channel.invokeMethod<int>('write', {'data': data});
    return result ?? -1;
  }

  @override
  Future<Uint8List> read(int maxBytes, {Duration timeout = const Duration(milliseconds: 500)}) async {
    final result = await _channel.invokeMethod<Uint8List>('read', {
      'maxBytes': maxBytes,
      'timeoutMs': timeout.inMilliseconds,
    });
    return result ?? Uint8List(0);
  }

  @override
  Future<void> close() => _channel.invokeMethod('closeDevice');

  /// Opens the device connection. Call before [flash].
  static Future<bool> open(String deviceName) async {
    final ok = await _channel.invokeMethod<bool>(
        'openDevice', {'deviceName': deviceName});
    return ok ?? false;
  }
}

/// Streams USB attach/detach events from Android.
///
/// Each event is a Map with keys: event ('attached'|'detached'), vendorId, productId, deviceName.
const usbEventsChannel = EventChannel('com.inwmesh.field_flash/usb_events');

Stream<Map<String, dynamic>> get usbDeviceEvents =>
    usbEventsChannel.receiveBroadcastStream().cast<Map<Object?, Object?>>().map(
          (raw) => raw.map((k, v) => MapEntry(k.toString(), v)),
        );

/// Returns a list of currently connected USB devices.
Future<List<Map<String, dynamic>>> listUsbDevices() async {
  final list = await _channel.invokeListMethod<Map>('listDevices') ?? [];
  return list
      .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
      .toList();
}

/// Requests OS permission for [deviceName]. Android will show a system dialog.
Future<void> requestUsbPermission(String deviceName) =>
    _channel.invokeMethod('requestPermission', {'deviceName': deviceName});
