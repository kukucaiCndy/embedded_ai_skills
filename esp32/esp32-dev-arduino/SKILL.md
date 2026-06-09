---
name: "esp32-dev-arduino"
description: "ESP32 Arduino CLI development on Windows/Linux/macOS. Invoke when user chooses Arduino framework for ESP32. Handles arduino-cli install, ESP32 core setup, compile/upload/monitor via CLI."
---

# ESP32 Development with Arduino CLI

## Platform Support

| OS | Terminal | Install Method | Port Format |
|----|----------|---------------|-------------|
| Windows | PowerShell | `winget install ArduinoSA.CLI -e` | COM3 |
| Linux | bash | `curl ... \| sh` | `/dev/ttyUSB0` |
| macOS | bash/zsh | `brew install arduino-cli` | `/dev/cu.usbserial-*` |

## Overview

Arduino CLI is a **single Go binary** — no IDE, no Java. Completely independent from ESP-IDF.

## Environment Setup

### Step 1: Install arduino-cli

**Check if already installed:**
```bash
arduino-cli version
```

If not found:

**Windows:**
```powershell
winget install --id=ArduinoSA.CLI -e
# Or download: https://downloads.arduino.cc/arduino-cli/arduino-cli_latest_Windows_64bit.zip
```

**Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh
# Binary installs to ~/bin/arduino-cli, add to PATH
```

**macOS:**
```bash
brew install arduino-cli
```

### Step 2: Configure ESP32 Support (All Platforms)

```bash
arduino-cli config init
arduino-cli config set board_manager.additional_urls "https://espressif.github.io/arduino-esp32/package_esp32_index.json"
arduino-cli core update-index
```

### Step 3: Install ESP32 Core (~500MB)

```bash
arduino-cli config set network.connection_timeout 600s
arduino-cli core install esp32:esp32
```

Downloads: platform core, xtensa/riscv GDB, esptool, openocd, mkspiffs, mklittlefs.

### Step 4: Verify

```bash
arduino-cli board listall | grep esp32
```

## Chip Selection (FQBN)

FQBN = Fully Qualified Board Name. Format: `esp32:<family>:<board>`

| Chip | FQBN | Notes |
|------|------|-------|
| ESP32 (WROOM) | `esp32:esp32:esp32` | Default |
| ESP32-S3 | `esp32:esp32:esp32s3` | AI, USB OTG |
| ESP32-C3 | `esp32:esp32:esp32c3` | RISC-V, BLE |
| ESP32-C6 | `esp32:esp32:esp32c6` | Wi-Fi 6, Zigbee |
| ESP32-H2 | `esp32:esp32:esp32h2` | Thread/Zigbee |
| ESP32-P4 | `esp32:esp32:esp32p4` | No wireless |

## Before Creating a Project

**Ask the user to:**
1. Connect ESP32 to computer via USB
2. Ensure the board is powered on
3. Find the port:
   - Windows: Device Manager → COMx
   - Linux: `ls /dev/ttyUSB*`
   - macOS: `ls /dev/cu.usbserial*`
4. Auto-detect:
   ```bash
   arduino-cli board list
   ```

## Project Lifecycle

### Create a Sketch
```cpp
// sketch.ino
#include <Arduino.h>

void setup() {
    Serial.begin(115200);
    pinMode(LED_BUILTIN, OUTPUT);
    Serial.println("Hello ESP32 Arduino!");
}

void loop() {
    digitalWrite(LED_BUILTIN, !digitalRead(LED_BUILTIN));
    delay(500);
}
```

### Compile
```bash
arduino-cli compile --fqbn esp32:esp32:esp32 <sketch_dir>
```

### Upload

```bash
# Windows
arduino-cli upload -p COM3 --fqbn esp32:esp32:esp32 <sketch_dir>

# Linux
arduino-cli upload -p /dev/ttyUSB0 --fqbn esp32:esp32:esp32 <sketch_dir>

# macOS
arduino-cli upload -p /dev/cu.usbserial-1234 --fqbn esp32:esp32:esp32 <sketch_dir>
```

### Serial Monitor
```bash
arduino-cli monitor -p <PORT> -c baudrate=115200   # Ctrl+C to exit
```

## Library Management

| Command | Purpose |
|---------|---------|
| `arduino-cli lib search "mqtt"` | Search |
| `arduino-cli lib install "ESP32Servo"` | Install (NOT "Servo"!) |
| `arduino-cli lib list` | List installed |

## Common ESP32 Libraries

| Library | Install Name | Purpose |
|---------|-------------|---------|
| WiFi | Built-in `#include <WiFi.h>` | Wi-Fi |
| BLE | Built-in `#include <BLEDevice.h>` | Bluetooth |
| Servo | `ESP32Servo` | Servo (NOT `Servo`) |
| MQTT | `PubSubClient` | MQTT |
| OLED | `Adafruit SSD1306` | I²C Display |

## Arduino vs ESP-IDF API

| Aspect | ESP-IDF | Arduino |
|--------|---------|---------|
| PWM | `ledcSetup`/`ledcWrite` | `analogWrite` |
| Servo | N/A | `ESP32Servo` |
| Wi-Fi | `esp_wifi_*()` C API | `WiFi.begin()` |
| GPIO | `gpio_set_level()` | `digitalWrite()` |

### Mix Arduino + IDF APIs
```cpp
extern "C" {
    #include "esp_wifi.h"
    #include "esp_sleep.h"
}
```

## Platform-Specific Troubleshooting

### Windows
- Board detection: Check Device Manager for COM port
- Upload fails: Hold BOOT + tap EN

### Linux
- **Serial permission**: `sudo usermod -a -G dialout $USER` (re-login)
- **Port busy**: `sudo chmod 666 /dev/ttyUSB0`

### macOS
- CP210x/CH340 may need driver: https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers
- Port format: `/dev/cu.usbserial-*`

### All Platforms
- **Core download timeout**: `arduino-cli config set network.connection_timeout 600s`
- **"Servo.h not found"**: Use `ESP32Servo`, not `Servo`

## Full CLI Reference

| Command | Purpose |
|---------|---------|
| `arduino-cli version` | Show version |
| `arduino-cli config init` | Init config |
| `arduino-cli core update-index` | Refresh index |
| `arduino-cli core install esp32:esp32` | Install ESP32 core |
| `arduino-cli board list` | List connected boards |
| `arduino-cli compile --fqbn esp32:esp32:esp32 <sketch>` | Compile |
| `arduino-cli upload -p <PORT> --fqbn esp32:esp32:esp32 <sketch>` | Flash |
| `arduino-cli monitor -p <PORT>` | Serial monitor |
| `arduino-cli lib install <name>` | Install library |
