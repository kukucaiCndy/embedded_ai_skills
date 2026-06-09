---
name: "esp32-dev-idf"
description: "ESP-IDF (official) development on Windows/Linux/macOS. Invoke when user chooses IDF framework for ESP32. Handles env setup, project creation, compile/flash/monitor, and JTAG debugging."
---

# ESP32 Development with ESP-IDF (Official)

## Platform Detection

**AI must first detect the OS, then adapt commands:**

| OS | Terminal | Shell Scripts | Port Format | Install Script |
|----|----------|--------------|-------------|---------------|
| **Windows** | **PowerShell only** | `.ps1` | `COM3` | `install.ps1` / `export.ps1` |
| **Linux** | bash | `.sh` | `/dev/ttyUSB0` | `install.sh` / `export.sh` |
| **macOS** | bash / zsh | `.sh` | `/dev/cu.usbserial-*` | `install.sh` / `export.sh` |

## Environment Detection

**ALL paths come from `esp32_env.json` located alongside the scripts in this skill's `scripts/` directory.** If this file does not exist, run `esp32_env_scan.ps1` (Windows) or the bash equivalent (Linux/macOS).

The JSON contains:
```json
{
  "idf_path": "<detected IDF path>",
  "idf_tools_path": "<detected or chosen toolchain path>",
  "idf_python": "<python executable path>",
  "idf_python_version": "Python x.y.z",
  "idf_version": "<detected IDF version>",
  "platform": "windows|linux|macos"
}
```

Common installation paths (check these first):
- Windows: `$USERPROFILE\esp\esp-idf`, `D:\esp32\esp-idf`
- Linux: `~/esp/esp-idf`, `/opt/esp-idf`
- macOS: `~/esp/esp-idf`, `/opt/esp-idf`

## CRITICAL: Windows Terminal Restrictions

**ESP-IDF on Windows does NOT support MSYS2 / Git Bash / MINGW64.**

```python
if 'MSYSTEM' in os.environ:  # MSYSTEM=MINGW64 set by Git Bash
    fatal('MSys/Mingw is not supported.')
```

Root causes: MSYS2 path translation (`C:\path` → `/c/path`) breaks native Windows tools.

**Windows**: Always use PowerShell. From Git Bash, execute via `.ps1` script files:
```bash
powershell -NoProfile -ExecutionPolicy Bypass -File "script.ps1"
```
Every `.ps1` script must clear MSYSTEM:
```powershell
[Environment]::SetEnvironmentVariable("MSYSTEM", $null, "Process")
[Environment]::SetEnvironmentVariable("MSYS2_PATH", $null, "Process")
```

**Linux/macOS**: Use bash/sh directly — no restrictions.

## Environment Setup

### Linux (Ubuntu) — System Prerequisites
```bash
sudo apt-get update
sudo apt-get install -y git wget flex bison gperf python3 python3-pip python3-venv \
    cmake ninja-build ccache libffi-dev libssl-dev dfu-util libusb-1.0-0
sudo usermod -a -G dialout $USER   # serial port access (re-login required)
```

### macOS — System Prerequisites
```bash
brew install cmake ninja ccache dfu-util python3
```

### Windows — No system prerequisites (install.ps1 handles everything)

### All Platforms — Clone ESP-IDF
```bash
git clone --recursive https://github.com/espressif/esp-idf.git <idf_path>
cd <idf_path>
```

> **If cloned without `--recursive`**, the `.gitmodules` are initialized but files are NOT checked out.
> You MUST run both commands:
> ```bash
> git submodule update --init --recursive
> git submodule update --force --checkout --recursive   # if files still missing
> ```
> Symptoms of missing submodule files: CMake errors like `Include directory '.../lwip/lwip/src/include' is not a directory`.

### Install Toolchain

| Platform | Command |
|----------|---------|
| Windows | `.\install.ps1` (PowerShell, from within `idf_path`) |
| Linux | `./install.sh` |
| macOS | `./install.sh` |

**Windows install wrapper script pattern** (for running from Git Bash):
```powershell
# install_wrapper.ps1
[Environment]::SetEnvironmentVariable("MSYSTEM", $null, "Process")
$env:MSYSTEM = $null
& "D:\esp32\esp-idf\install.ps1"
```
Then: `powershell -NoProfile -ExecutionPolicy Bypass -File "install_wrapper.ps1"`

### Python Version Compatibility

- ESP-IDF v5.x: Python 3.8–3.12
- ESP-IDF v6.x: Python 3.8+ (tested with 3.14)
- If Python is too new, install an older version or check `detect_python.sh` for the supported range

### Export Environment (every terminal session)

| Platform | Command |
|----------|---------|
| Windows | `.\export.ps1` (PowerShell) |
| Linux | `source ./export.sh` |
| macOS | `source ./export.sh` |

### Record Environment
After installation, run `esp32_env_scan` (platform-specific script in `scripts/`) to record paths to `esp32_env.json`.

## AI Action Pattern

1. Detect OS from context (uname, $OSTYPE, etc.)
2. Read `esp32_env.json` → get `idf_path`, `idf_tools_path`, `idf_version`
3. Read the relevant script from `scripts/` folder (`.ps1` for Windows, `.sh` for Linux/macOS)
4. Customize paths and execute using the platform-appropriate method
5. On Windows: always route commands through `.ps1` scripts that clear `MSYSTEM` first

## Project Lifecycle

### Before Creating a Project

**Ask the user to:**
1. Connect ESP32 to computer via USB cable
2. Ensure the board is powered on
3. Find the serial port:
   - Windows: `powershell -NoProfile -Command "[System.IO.Ports.SerialPort]::GetPortNames()"`
   - Linux: `ls /dev/ttyUSB*` or `ls /dev/ttyACM*`
   - macOS: `ls /dev/cu.usbserial*` or `ls /dev/cu.wchusbserial*`

### Auto-Detect Chip Model

```bash
# Via the reusable script (Windows):
powershell -NoProfile -ExecutionPolicy Bypass -File "esp32_chip_detect.ps1" -port COMx

# Or manually:
esptool --port <PORT> flash-id
```

Typical output:
```
Detecting chip type... ESP32-S3
Chip is ESP32-S3 (revision v0.2)
```

**Never guess the chip model** — always auto-detect. If detection fails:
- Check USB cable (some are charge-only)
- Try different port (ESP32-S3 may enumerate differently in download mode)
- Hold BOOT + tap EN, then retry
- Try lower baud rate: `--baud 115200 --before no-reset`
- If all else fails — ask the user directly

### Create Project

**WARNING: `idf.py create-project -path` may fail when IDF and the project are on different drives** (Windows `os.rename` cross-drive error). In that case, create the project structure manually:

**Manual project creation:**
```
project_root/
├── CMakeLists.txt           # Top-level build file
├── main/
│   ├── CMakeLists.txt
│   └── main.c
└── .gitignore
```

**`CMakeLists.txt` (root):**
```cmake
cmake_minimum_required(VERSION 3.16)
include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(my_project)
```

**`main/CMakeLists.txt`:**
```cmake
idf_component_register(SRCS "main.c"
                    INCLUDE_DIRS ".")
```

**`main/main.c`:**
```c
#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_system.h"
#include "esp_log.h"

static const char *TAG = "main";

void app_main(void)
{
    ESP_LOGI(TAG, "ESP32 initialized!");
    ESP_LOGI(TAG, "IDF version: %s", esp_get_idf_version());
    ESP_LOGI(TAG, "Chip: %s with %d cores", CONFIG_IDF_TARGET, portNUM_PROCESSORS);

    while (1) {
        ESP_LOGI(TAG, "Hello, ESP32! Tick: %lu", xTaskGetTickCount());
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
```

**`.gitignore`:**
```
build/
sdkconfig
sdkconfig.old
*.pyc
__pycache__/
```

### Set Chip Target
```bash
idf.py set-target esp32s3    # esp32, esp32s3, esp32c3, esp32c6, etc.
```

> **If `set-target` fails**, check for stale build state:
> ```bash
> rm -rf build/          # or: powershell Remove-Item -Recurse -Force build/
> rm -f sdkconfig.old     # remove old sdkconfig backups
> ```

### Build
```bash
idf.py build
```

### Flash
```bash
# Windows
idf.py -p COM3 flash

# Linux
idf.py -p /dev/ttyUSB0 flash

# macOS
idf.py -p /dev/cu.usbserial-1234 flash
```

### Monitor
```bash
idf.py -p <PORT> monitor     # Ctrl+] to exit on all platforms
```

### All-in-One
```bash
idf.py -p <PORT> build flash monitor
```

## Key IDF Commands

| Command | Purpose |
|---------|---------|
| `idf.py set-target <chip>` | Set chip target (esp32/esp32s3/esp32c3/esp32c6/esp32h2/esp32p4) |
| `idf.py menuconfig` | Graphical configuration (Kconfig) |
| `idf.py build` | Compile |
| `idf.py -p <PORT> flash` | Flash firmware |
| `idf.py -p <PORT> monitor` | Serial monitor (115200 baud) |
| `idf.py -p <PORT> flash monitor` | Flash then monitor |
| `idf.py clean` | Clean build artifacts (keeps config) |
| `idf.py fullclean` | Clean ALL build artifacts including config |
| `idf.py create-project <name>` | Create new project from template |
| `idf.py create-project -path <path>` | Create project at specific path |
| `idf.py size` | Binary size breakdown |
| `idf.py size-components` | Per-component size analysis |
| `idf.py openocd` | Start OpenOCD debug server |
| `idf.py gdb` | Start GDB debug session |
| `idf.py reconfigure` | Re-run CMake without fullclean |

## Project Structure
```
my_project/
├── CMakeLists.txt          # Top-level build file
├── sdkconfig               # Generated by set-target / menuconfig
├── main/
│   ├── CMakeLists.txt
│   └── main.c
├── components/             # Custom components (optional)
├── build/                  # Build artifacts (gitignored)
│   ├── my_project.bin      # Flashable binary
│   ├── my_project.elf      # ELF with debug symbols
│   ├── bootloader/         # Second-stage bootloader
│   └── partition_table/    # Partition table binary
└── .gitignore
```

## Chip Selection Guide

| Chip | Core | Wi-Fi | BLE | USB | Best For |
|------|------|-------|-----|-----|----------|
| ESP32 | Xtensa dual | 4.x | Classic+BLE | No | General purpose |
| ESP32-S3 | Xtensa dual | 4.x | BLE 5 | OTG | AI, LCD, camera |
| ESP32-C3 | RISC-V | 4.x | BLE 5 | Serial | Low cost, BLE |
| ESP32-C6 | RISC-V | 6 | BLE 5/Zigbee/Thread | Serial | Matter, Wi-Fi 6 |
| ESP32-H2 | RISC-V | No | BLE 5/Thread/Zigbee | No | Thread/Zigbee only |
| ESP32-P4 | RISC-V dual | No | No | Yes | High perf, no wireless |

## JTAG Debugging

### Debugger Compatibility

| Debugger | ESP32 Support | Notes |
|----------|:---:|-------|
| **ESP-Prog** | ✅ | Espressif official, best compatibility |
| **J-Link** | ✅ | Segger universal JTAG |
| **FT2232H** | ✅ | Low-cost, OpenOCD native |
| **USB-JTAG (built-in)** | ✅ | ESP32-S3/C3/C6/C2/H2 — no extra hardware! |
| **STLink** | ❌ | ARM Cortex-M only, incompatible |

**ESP32-S3/C3/C6/C2 do NOT need an external debugger** — built-in USB-Serial-JTAG works over the same USB cable used for flashing.

### USB-JTAG Windows Driver Setup

On Windows, the JTAG interface (MI_02) must use `libusb-win32` driver via **Zadig** (https://zadig.akeo.ie/). See the parent `esp32-dev` skill for detailed steps.

### JTAG Pinout (External)

| Signal | ESP32 | ESP32-S2 | ESP32-S3/C3 | USB-JTAG |
|--------|-------|----------|-------------|----------|
| TCK | GPIO13 | GPIO13 | GPIO4 | Built-in USB (GPIO19/20) |
| TMS | GPIO14 | GPIO14 | GPIO5 | Built-in USB |
| TDI | GPIO12 | GPIO12 | GPIO6 | Built-in USB |
| TDO | GPIO15 | GPIO15 | GPIO7 | Built-in USB |

### Launch Debug (All Platforms)

```bash
# Terminal 1: Start OpenOCD
idf.py openocd
# Note: must be run from a project directory, NOT IDF root

# Terminal 2: Start GDB
idf.py gdb
```

### GDB Commands

| Command | Purpose |
|---------|---------|
| `target remote :3333` | Connect GDB to OpenOCD |
| `mon reset halt` | Reset chip + halt at boot ROM |
| `break main` | Breakpoint at main() |
| `continue` / `c` | Continue execution |
| `step` / `s` | Step into |
| `next` / `n` | Step over |
| `print var` | Print variable value |
| `backtrace` / `bt` | Call stack |
| `info threads` | List FreeRTOS tasks |
| `thread N` | Switch to task N |
| `watch var` | Hardware watchpoint |
| `info registers` | Dump all CPU registers |
| `x/10x $sp` | Examine 10 words from stack pointer |
| `mon reset` | Reset chip |
| `mon targets` | List JTAG targets |
| `quit` | Exit GDB |

### Quick Debug (ESP32-S3/C3/C6 USB-JTAG)
```bash
idf.py openocd                    # Terminal 1
idf.py gdb                        # Terminal 2
```

## Common Pitfalls

### Windows
1. **MSYSTEM Detection**: Must use PowerShell via script files
2. **USB-JTAG driver**: Replace WinUSB with libusb-win32 via Zadig for MI_02 interface
3. **COM Port**: Use PowerShell `[System.IO.Ports.SerialPort]::GetPortNames()` to list
4. **BOOT+EN**: Hold BOOT, tap EN to enter download mode for flashing
5. **ESP32-S3 port switching**: The COM port number may change when the chip enters download mode
6. **Cross-drive create-project**: `idf.py create-project -path` fails when IDF is on different drive — create manually

### Linux
1. **Serial permission**: `sudo usermod -a -G dialout $USER` (re-login)
2. **Port busy**: `sudo chmod 666 /dev/ttyUSB0` if permission denied
3. **Missing libs**: `sudo apt install libusb-1.0-0`

### macOS
1. **Serial driver**: CP210x/CH340 may need driver install
2. **Port format**: `/dev/cu.usbserial-*`, not `/dev/tty.*`

### All Platforms
1. **Python**: ESP-IDF v5.x/v6.x requires Python 3.8+ (tested up to 3.14 on v6.2)
2. **Missing venv**: "module 'rich' not found" → re-run install script
3. **Cable**: Use data cable (some are charge-only)
4. **Submodule fail**: `git submodule update --init --recursive` then `--force --checkout`
5. **Stale build dir**: Delete `build/` and `sdkconfig` before re-running `set-target`
6. **idf.py openocd location**: Must run from a project directory, NOT from IDF root
