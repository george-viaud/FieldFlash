package com.inwmesh.field_flash

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager

/**
 * Receives USB attach/detach broadcasts and forwards them to Dart
 * via the event channel: com.inwmesh.field_flash/usb_events
 *
 * Events are Maps: { "event": "attached"|"detached", "vendorId": int, "productId": int, "deviceName": String }
 */
class UsbBroadcastReceiver(
    private val onEvent: (Map<String, Any?>) -> Unit
) : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
        val event: Map<String, Any?> = when (intent.action) {
            UsbManager.ACTION_USB_DEVICE_ATTACHED -> mapOf(
                "event" to "attached",
                "vendorId" to (device?.vendorId ?: -1),
                "productId" to (device?.productId ?: -1),
                "deviceName" to (device?.deviceName ?: ""),
            )
            UsbManager.ACTION_USB_DEVICE_DETACHED -> mapOf(
                "event" to "detached",
                "vendorId" to (device?.vendorId ?: -1),
                "productId" to (device?.productId ?: -1),
                "deviceName" to (device?.deviceName ?: ""),
            )
            else -> return
        }
        onEvent(event)
    }
}
