# FieldFlash

Flash firmware onto MeshCore radio nodes over USB-C — no laptop required.

FieldFlash is an Android app that lets you select, download, and flash firmware directly from your phone. Point it at a MeshCore GitHub release, pick your device, and flash — all in the field.

## Features

- **Browse MeshCore releases** — fetches the latest firmware from GitHub with search/filter
- **Local firmware library** — downloaded files are cached on-device for offline use
- **One-tap flash** — ESP32-S3 devices flashed over USB-C via the ROM bootloader
- **Auto device detection** — identifies connected devices by USB VID/PID

## Supported Hardware

| Device | Protocol |
|---|---|
| Heltec V3, T-Deck (ESP32-S3) | ESP ROM (USB CDC) |
| RAK4631 | Nordic DFU |
| Adafruit/nRF52 UF2 boards | UF2 mass storage |

## Getting Started

### Requirements

- Android 8.0+ (API 26+)
- USB-C OTG cable or adapter
- Flutter 3.x (to build from source)

### Build & Run

```bash
flutter pub get
flutter run                    # connected Android device
flutter build apk              # release APK
flutter test                   # full test suite
flutter test test/path/file.dart  # single test file
flutter analyze                # lint
```

## How It Works

1. **Connect** — plug the radio node into your phone via USB-C OTG
2. **Select Firmware** — choose from your local library or download from the Online tab
3. **Boot mode** — follow the on-screen instructions to put the device in flash mode
4. **Flash** — the app sends firmware over USB using the appropriate protocol

### ESP ROM Bootloader (ESP32-S3)

SLIP-framed protocol: `SYNC → FLASH_BEGIN → FLASH_DATA × N → FLASH_END`. No drivers needed — Android USB Host handles it natively.

### Firmware Library

Downloaded `.bin`, `.uf2`, and `.zip` files are stored in the app's documents directory under `firmware_library/`. They appear in the Local tab and persist between sessions.

## Project Structure

```
lib/
  screens/      connect, firmware, preflash, flash, settings
  protocols/    FlashProtocol + ESP/Nordic/UF2 implementations
  services/     USB detection, GitHub releases, firmware library cache
  models/       DeviceProfile, FirmwareSource, FirmwareAsset, FlashProgress
android/
  UsbBulkTransferPlugin.kt   raw USB bulk transfer platform channel
  UsbBroadcastReceiver.kt    USB attach/detach events
```

## License

MIT
