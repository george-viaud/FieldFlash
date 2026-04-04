# FieldFlash — Project Plan

**FieldFlash** is an Android app (Flutter) that flashes firmware onto embedded radio/mesh devices over USB-C, with no PC required.

## Problem

Updating firmware on field-deployed mesh nodes (Heltec, RAK, T-Deck, etc.) currently requires a laptop. FieldFlash lets you do it from your phone — useful for nodes on towers, rooftops, or up a mountain.

## Supported Devices & Protocols

| Protocol | Chips | Example Devices |
|----------|-------|----------------|
| ESP ROM Bootloader | ESP32, ESP32-S3, ESP32-C3, ESP32-C6 | Heltec V3, T-Deck, T-Beam, TTGO LoRa |
| Nordic USB DFU | nRF52840 | RAK4631, WisBlock Core |
| UF2 | RP2040, nRF52 w/ UF2 bootloader | Some RAK, Adafruit boards |
| STM32 USB DFU | STM32 family | (future) |

## Architecture

### Protocol Adapter Pattern

Each chip family gets a `FlashProtocol` implementation:

```
FlashProtocol (abstract)
  ├── EspFlashProtocol      — SLIP framing + ESP ROM bootloader commands
  ├── NordicDfuProtocol     — adafruit-nrfutil DFU packet format over USB CDC
  └── Uf2Protocol           — write UF2 blocks to USB mass storage device
```

Each adapter receives a `UsbDeviceConnection` and a firmware `Uint8List`, returns a `Stream<FlashProgress>`.

### Device Detection

Auto-detect by USB VID/PID on connect:

| VID | PID | Device | Protocol |
|-----|-----|--------|----------|
| 0x303A | 0x1001 | ESP32-S3 (native USB) | ESP ROM |
| 0x10C4 | 0xEA60 | CP2102 (ESP32 via UART bridge) | ESP ROM |
| 0x1A86 | 0x55D4 | CH343 (ESP32 via UART bridge) | ESP ROM |
| 0x239A | — | Adafruit / nRF52 UF2 | UF2 |
| 0x2886 | 0x0044 | RAK4631 | Nordic DFU |

Fall back to manual selection if VID/PID unknown.

### USB Access

- `usb_serial` Flutter package for ESP32 CDC/UART (handles CP210x, CH34x, FTDI, CDC-ACM)
- Direct Android `UsbManager` via platform channel for raw bulk transfer (Nordic DFU, UF2)
- Android pops a permission dialog on first connect — no root needed

### Firmware Sources

1. **Local file** — file picker, loads any `.bin` / `.uf2` / `.zip` from phone storage
2. **GitHub Releases** — curated list of supported projects (MeshCore, Meshtastic, etc.); fetches latest release assets via GitHub API, lets user pick variant

### Boot Mode Handling

ESP32: user must manually hold BOOT + tap RST before connecting. App shows a clear diagram/animation for this step.

nRF52 / UF2: double-tap RST to enter bootloader. App guides the user.

---

## Screen Flow

```
Splash / Home
    ↓
Connect Device  ←→  [USB connected → auto-detect or manual select]
    ↓
Select Firmware  ←→  [Local file picker  |  GitHub Releases browser]
    ↓
Pre-Flash Checklist  (boot mode instructions, battery warning)
    ↓
Flashing  (progress bar, live log, cancel)
    ↓
Done / Error
```

---

## Key Screens

### 1. Connect Screen
- "Connect your device via USB-C" prompt
- Listens for USB attach broadcast
- Shows detected device name + chip
- Manual override dropdown if undetected

### 2. Firmware Screen
- Tab: Local (file picker for .bin/.uf2/.zip)
- Tab: Online (GitHub releases browser, shows version + release notes)
- Remembers last used firmware per device type

### 3. Pre-Flash Screen
- Device-specific boot mode instructions with diagram
- Checklist: battery OK, correct firmware for device, etc.
- "I'm ready" → starts flash

### 4. Flash Screen
- Large progress bar
- Elapsed time
- Scrollable live log (bytes written, checksums, errors)
- Cancel button (safe abort)

### 5. Settings
- Manual VID/PID overrides
- Custom firmware source URLs
- Theme (dark default — field use)

---

## ESP ROM Bootloader Protocol (Core Implementation)

The heart of ESP flashing. SLIP-framed binary protocol over serial.

### SLIP Framing
```
0xC0  [escaped payload]  0xC0
Escape: 0xDB 0xDC = 0xC0, 0xDB 0xDD = 0xDB
```

### Command Sequence
1. `ESP_SYNC` (0x08) — send 36-byte sync pattern, retry until response
2. `ESP_FLASH_BEGIN` (0x02) — erase target region, declare size + offset
3. N × `ESP_FLASH_DATA` (0x03) — 4KB blocks, sequence number, MD5 per block
4. `ESP_FLASH_END` (0x04) — reboot flag

### Offsets (typical)
```
0x0000  bootloader.bin
0x8000  partitions.bin
0x10000 firmware.bin        ← usually what you're updating
```

Single combined `.bin` from esptool merge: flash at 0x0000.

---

## Nordic DFU Protocol (nRF52)

RAK4631 and similar nRF52840 boards use the Nordic DFU protocol.

- Firmware packaged as `.zip` (DFU package: app + bootloader + softdevice)
- Protocol: DFU control point (CCCD notify) + DFU packet characteristic over USB CDC or BLE
- Reference: `adafruit-nrfutil` Python tool (open source, good protocol reference)
- On Android: can be done over BLE (Nordic DFU library exists for Android) or USB CDC

BLE DFU is actually easier on Android than USB for nRF52 — the [Nordic Android DFU Library](https://github.com/NordicSemiconductor/Android-DFU-Library) is open source and well-maintained. We could wrap it via a platform channel.

---

## UF2 Protocol (RP2040, some nRF52)

When the device enumerates as a USB Mass Storage device (after double-tap RST):

- Mount the drive, delete `CURRENT.UF2`, copy new `.uf2` file
- On Android: USB mass storage access via `StorageManager` / `UsbDeviceConnection` bulk transfer
- UF2 format: 512-byte blocks, each containing 256 bytes of firmware data

This is the simplest protocol — it's literally a file copy.

---

## Flutter Package Dependencies

| Package | Purpose |
|---------|---------|
| `usb_serial` | USB serial for ESP32 (CP210x, CH34x, CDC-ACM) |
| `file_picker` | Load local firmware files |
| `http` / `dio` | GitHub Releases API |
| `path_provider` | Cache downloaded firmware |
| `permission_handler` | Storage permissions |
| `flutter_riverpod` | State management |

Platform channel (Kotlin) needed for:
- Raw USB bulk transfer (Nordic DFU, UF2 mass storage)
- USB device attach/detach broadcast receiver

---

## Project Structure

```
lib/
  main.dart
  screens/
    connect_screen.dart
    firmware_screen.dart
    preflash_screen.dart
    flash_screen.dart
    settings_screen.dart
  protocols/
    flash_protocol.dart          ← abstract base
    esp_flash_protocol.dart
    nordic_dfu_protocol.dart
    uf2_protocol.dart
  services/
    usb_device_service.dart      ← device detection, VID/PID map
    firmware_service.dart        ← local + GitHub firmware sources
    github_releases_service.dart
  models/
    device_profile.dart
    firmware_source.dart
    flash_progress.dart
  widgets/
    boot_mode_diagram.dart
    flash_progress_bar.dart
    device_card.dart
android/
  app/src/main/kotlin/.../
    UsbBulkTransferPlugin.kt     ← platform channel for raw USB
    UsbBroadcastReceiver.kt
```

---

## MVP Scope

For a first working version, target only:

1. **ESP32-S3 via native USB CDC** (covers Heltec V3, T-Deck)
2. **Local `.bin` file only** (no GitHub releases browser yet)
3. **Single combined binary** flashed at `0x0000`

That's the minimum to solve the original problem (hike up, flash node). Add other protocols iteratively.

---

## Open Questions

- Should FieldFlash be a standalone app or integrated into MeshCore Wardrive?
  - Standalone is cleaner and more reusable
  - Integrated means one less app to install when you're in the field
- Minimum Android API level? (USB Host requires API 12+, but realistically target API 26+)
- Should we support BLE DFU for nRF52 as well as USB? (BLE DFU is easier to implement on Android)
