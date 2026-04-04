package com.inwmesh.field_flash

import android.content.IntentFilter
import android.hardware.usb.UsbManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val USB_EVENTS_CHANNEL = "com.inwmesh.field_flash/usb_events"
    }

    private var usbReceiver: UsbBroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register the bulk-transfer method channel plugin
        flutterEngine.plugins.add(UsbBulkTransferPlugin())

        // Register the USB attach/detach event channel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, USB_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                    usbReceiver = UsbBroadcastReceiver { event ->
                        runOnUiThread { sink.success(event) }
                    }
                    val filter = IntentFilter().apply {
                        addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
                        addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(usbReceiver, filter, RECEIVER_NOT_EXPORTED)
                    } else {
                        registerReceiver(usbReceiver, filter)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    usbReceiver?.let { unregisterReceiver(it) }
                    usbReceiver = null
                    eventSink = null
                }
            })
    }
}
