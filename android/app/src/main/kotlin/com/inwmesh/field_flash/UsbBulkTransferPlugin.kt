package com.inwmesh.field_flash

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Platform channel for raw USB bulk-transfer access.
 *
 * Channel name: com.inwmesh.field_flash/usb_bulk
 *
 * Methods:
 *   listDevices()                  → List<Map> [{vendorId, productId, deviceName}]
 *   requestPermission(deviceName)  → void (async — app will receive USB_DEVICE_ATTACHED broadcast)
 *   openDevice(deviceName)         → bool
 *   write(data: Uint8List)         → int  (bytes written, -1 on error)
 *   read(maxBytes: int, timeoutMs: int) → Uint8List
 *   closeDevice()                  → void
 */
class UsbBulkTransferPlugin : FlutterPlugin, MethodCallHandler {

    companion object {
        const val CHANNEL = "com.inwmesh.field_flash/usb_bulk"
        const val ACTION_USB_PERMISSION = "com.inwmesh.field_flash.USB_PERMISSION"
    }

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var usbManager: UsbManager

    private var activeConnection: UsbDeviceConnection? = null
    private var activeEndpointOut: android.hardware.usb.UsbEndpoint? = null
    private var activeEndpointIn: android.hardware.usb.UsbEndpoint? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        activeConnection?.close()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "listDevices" -> {
                val devices = usbManager.deviceList.values.map { dev ->
                    mapOf(
                        "vendorId" to dev.vendorId,
                        "productId" to dev.productId,
                        "deviceName" to dev.deviceName,
                    )
                }
                result.success(devices)
            }

            "requestPermission" -> {
                val deviceName = call.argument<String>("deviceName")
                val device = usbManager.deviceList[deviceName]
                if (device == null) {
                    result.error("NOT_FOUND", "Device not found: $deviceName", null)
                    return
                }
                val flags = PendingIntent.FLAG_IMMUTABLE
                val permIntent = PendingIntent.getBroadcast(
                    context, 0, Intent(ACTION_USB_PERMISSION), flags
                )
                usbManager.requestPermission(device, permIntent)
                result.success(null)
            }

            "openDevice" -> {
                val deviceName = call.argument<String>("deviceName")
                val device = usbManager.deviceList[deviceName]
                if (device == null) {
                    result.success(false)
                    return
                }
                if (!usbManager.hasPermission(device)) {
                    result.error("NO_PERMISSION", "USB permission not granted", null)
                    return
                }
                result.success(openDevice(device))
            }

            "resetIntoBootloader" -> {
                // ESP32-S3 USB JTAG/Serial reset sequence (matches esptool-js usbJTAGSerialReset).
                // Toggles DTR/RTS via CDC SET_CONTROL_LINE_STATE to force ROM bootloader.
                val conn = activeConnection
                if (conn == null) { result.error("NO_DEVICE", "No device open", null); return }
                val commIfaceIdx = 0
                fun setSignals(dtr: Boolean, rts: Boolean) {
                    val v = ((if (rts) 1 else 0) shl 1) or (if (dtr) 1 else 0)
                    conn.controlTransfer(0x21, 0x22, v, commIfaceIdx, null, 0, 200)
                }
                Thread {
                    setSignals(dtr = false, rts = false); Thread.sleep(100)
                    setSignals(dtr = true,  rts = false); Thread.sleep(100)
                    setSignals(dtr = false, rts = true);  Thread.sleep(100)
                    setSignals(dtr = false, rts = false); Thread.sleep(50)
                    result.success(null)
                }.start()
            }

            "write" -> {
                val data = call.argument<ByteArray>("data")
                    ?: return result.error("NULL_DATA", "data is null", null)
                val conn = activeConnection
                    ?: return result.error("NO_DEVICE", "No device open", null)
                val ep = activeEndpointOut
                    ?: return result.error("NO_ENDPOINT", "No OUT endpoint", null)
                val written = conn.bulkTransfer(ep, data, data.size, 2000)
                result.success(written)
            }

            "read" -> {
                val maxBytes = call.argument<Int>("maxBytes") ?: 256
                val timeoutMs = call.argument<Int>("timeoutMs") ?: 500
                val conn = activeConnection
                    ?: return result.error("NO_DEVICE", "No device open", null)
                val ep = activeEndpointIn
                    ?: return result.error("NO_ENDPOINT", "No IN endpoint", null)
                val buf = ByteArray(maxBytes)
                val received = conn.bulkTransfer(ep, buf, maxBytes, timeoutMs)
                result.success(if (received > 0) buf.copyOf(received) else ByteArray(0))
            }

            "closeDevice" -> {
                activeConnection?.close()
                activeConnection = null
                activeEndpointOut = null
                activeEndpointIn = null
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun openDevice(device: UsbDevice): Boolean {
        activeConnection?.close()
        val conn = usbManager.openDevice(device) ?: return false

        // Find the CDC Data interface (bulk IN + OUT endpoints).
        // CDC devices have two interfaces:
        //   0 = Communication (control/interrupt) — skip
        //   1 = Data (bulk IN + OUT)              — use this one
        // We also claim the Communication interface so the OS doesn't block us.
        var commInterface: android.hardware.usb.UsbInterface? = null
        var dataInterface: android.hardware.usb.UsbInterface? = null

        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            var hasBulkOut = false
            var hasBulkIn  = false
            for (j in 0 until iface.endpointCount) {
                val ep = iface.getEndpoint(j)
                if (ep.type == android.hardware.usb.UsbConstants.USB_ENDPOINT_XFER_BULK) {
                    if (ep.direction == android.hardware.usb.UsbConstants.USB_DIR_OUT) hasBulkOut = true
                    else hasBulkIn = true
                }
            }
            if (hasBulkOut && hasBulkIn) {
                dataInterface = iface
            } else {
                commInterface = iface
            }
        }

        if (dataInterface == null) { conn.close(); return false }

        // Claim both interfaces; ignore failures on the comm interface.
        commInterface?.let { conn.claimInterface(it, true) }
        conn.claimInterface(dataInterface, true)

        // Extract bulk endpoints from the data interface.
        for (j in 0 until dataInterface.endpointCount) {
            val ep = dataInterface.getEndpoint(j)
            if (ep.type == android.hardware.usb.UsbConstants.USB_ENDPOINT_XFER_BULK) {
                if (ep.direction == android.hardware.usb.UsbConstants.USB_DIR_OUT) activeEndpointOut = ep
                else activeEndpointIn = ep
            }
        }

        if (activeEndpointOut == null || activeEndpointIn == null) {
            conn.close(); return false
        }

        // Send CDC SET_CONTROL_LINE_STATE (DTR=1, RTS=1) to activate the port.
        // bmRequestType=0x21 (class, interface, host→device), bRequest=0x22, wValue=0x03
        val commIfaceIdx = commInterface?.id ?: 0
        conn.controlTransfer(0x21, 0x22, 0x03, commIfaceIdx, null, 0, 1000)

        activeConnection = conn
        return true
    }
}
