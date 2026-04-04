# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This App Does

**FieldFlash** is an Android app (Flutter) that flashes firmware onto embedded radio/mesh nodes (Heltec, RAK, T-Deck, etc.) over USB-C — no laptop required. See `PLAN.md` for the full design specification.

## Commands

```bash
# Run on connected Android device
flutter run

# Build APK
flutter build apk

# Analyze (lint)
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart
```

## Target Architecture (from PLAN.md)

The app is currently a scaffold. Implement according to `PLAN.md`. Key structure:

```
lib/
  main.dart
  screens/          # connect, firmware, preflash, flash, settings
  protocols/        # FlashProtocol abstract + ESP/Nordic/UF2 impls
  services/         # USB device detection, firmware sources, GitHub API
  models/           # DeviceProfile, FirmwareSource, FlashProgress
  widgets/          # boot mode diagrams, progress bar, device card
android/app/src/main/kotlin/
                    # UsbBulkTransferPlugin.kt, UsbBroadcastReceiver.kt
```

### Protocol Adapter Pattern

Each chip family implements `FlashProtocol`, receiving a `UsbDeviceConnection` and firmware `Uint8List`, returning `Stream<FlashProgress>`:

- `EspFlashProtocol` — SLIP framing + ESP ROM bootloader (sync → flash_begin → flash_data × N → flash_end)
- `NordicDfuProtocol` — Nordic DFU over USB CDC (firmware as `.zip` DFU package)
- `Uf2Protocol` — write UF2 blocks to USB mass storage

### USB Access Strategy

- `usb_serial` Flutter package handles ESP32 CDC/UART (CP210x, CH34x, CDC-ACM)
- Raw USB bulk transfer (Nordic DFU, UF2) requires a Kotlin platform channel (`UsbBulkTransferPlugin`)
- USB device attach/detach requires `UsbBroadcastReceiver` platform channel

### Device Auto-Detection (VID/PID)

| VID    | PID    | Device              | Protocol |
|--------|--------|---------------------|----------|
| 0x303A | 0x1001 | ESP32-S3 native USB | ESP ROM  |
| 0x10C4 | 0xEA60 | CP2102 (ESP32)      | ESP ROM  |
| 0x1A86 | 0x55D4 | CH343 (ESP32)       | ESP ROM  |
| 0x239A | —      | Adafruit/nRF52 UF2  | UF2      |
| 0x2886 | 0x0044 | RAK4631             | Nordic DFU |

### State Management

Use `flutter_riverpod` (per PLAN.md).

## MVP Scope

First working version targets only:
1. ESP32-S3 via native USB CDC (Heltec V3, T-Deck)
2. Local `.bin` file (no GitHub releases browser yet)
3. Single combined binary flashed at offset `0x0000`

## ESP ROM Bootloader Notes

SLIP framing: `0xC0 [escaped payload] 0xC0` (escape `0xC0` → `0xDB 0xDC`, `0xDB` → `0xDB 0xDD`).

Command sequence: `ESP_SYNC (0x08)` → `ESP_FLASH_BEGIN (0x02)` → N × `ESP_FLASH_DATA (0x03)` (4KB blocks) → `ESP_FLASH_END (0x04)`.

## Android Requirements

- Minimum API 26+, USB Host feature required
- No root needed — Android pops USB permission dialog on first connect
- `AndroidManifest.xml` needs `<uses-feature android:name="android.hardware.usb.host"/>`
