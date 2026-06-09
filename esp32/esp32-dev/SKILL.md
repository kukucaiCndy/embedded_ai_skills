---
name: "esp32-dev"
description: "ESP32 development entry point. Invoke when user mentions ESP32, esp32 dev, or wants to set up an ESP32 project. Asks user to choose IDF or Arduino framework then loads the corresponding sub-skill. Supports Windows, Linux, macOS."
---

# ESP32 Development — Framework Selection

## Platform Support

This skill supports **Windows**, **Linux (Ubuntu)**, and **macOS**.

| OS | Terminal | Shell Scripts | Port Format | Arduino CLI Install |
|----|----------|--------------|-------------|-------------------|
| Windows | PowerShell | `.ps1` | COM3 | `winget install ArduinoSA.CLI` |
| Linux | bash | `.sh` | `/dev/ttyUSB0` | `curl ... \| sh` |
| macOS | bash/zsh | `.sh` | `/dev/cu.usbserial-*` | `brew install arduino-cli` |

## Overview

ESP32 supports two mainstream development frameworks:

| Aspect | ESP-IDF (Official) | Arduino Core |
|--------|-------------------|--------------|
| Language | C (CMake) | C++ (Arduino API) |
| Learning curve | Steep — full control over hardware | Gentle — `digitalWrite()` style |
| Memory | ~300KB heap | ~200KB heap |
| Suitable for | Commercial products, complex projects | Rapid prototyping, Maker projects |
| Build tool | `idf.py` (CMake + Ninja) | `arduino-cli` (single binary) |
| Platform | Windows / Linux / macOS | Windows / Linux / macOS |

## Workflow

```
User asks for ESP32 development
  ↓
[Step 1] Detect OS → adapt terminal/port/script format
  ↓
[Step 2] Introduce both frameworks (IDF vs Arduino)
  ↓
[Step 3] Ask user: "Which framework do you prefer?"
          Option A: ESP-IDF (official, C, full control)
          Option B: Arduino (simpler, C++, rapid prototyping)
  ↓
[Step 4] Based on choice, invoke the sub-skill:
          IDF     → Skill("esp32-dev-idf")
          Arduino → Skill("esp32-dev-arduino")
  ↓
[Step 5] ⚡ RTOS Selection — list available RTOS with pros/cons,
          then ask user: "Which RTOS or bare metal?"
  ↓
[Step 6] ⚡ Ask user to connect device + power on
  ↓
[Step 7] Find serial port (platform-specific)
  ↓
[Step 8] Auto-detect chip model (esptool.py flash_id)
  ↓
[Step 9] The sub-skill handles:
          - Environment detection (check esp32_env.json)
          - Environment installation (if not already done)
          - Project initialization with detected chip + selected RTOS
          - Compile → Flash → Monitor workflow
```

## RTOS Selection

**When the user starts a new project or initializes an existing one, AI MUST present the RTOS options and ask for a decision.**

### Available RTOS for ESP32

| RTOS | License | Memory Footprint | Learning Curve | Best For |
|------|---------|-----------------|----------------|----------|
| **FreeRTOS** (默认) | MIT | ~5-10KB | Low | 通用开发，ESP-IDF 原生集成 |
| **Zephyr** | Apache 2.0 | ~10-30KB | Medium | IoT 产品，模块化设计 |
| **ThreadX** | MIT (Azure RTOS) | ~5-15KB | Low-Medium | 安全认证产品（医疗/汽车/工业） |
| **NuttX** | Apache 2.0 | ~15-40KB | Medium-High | Linux 迁移，POSIX 兼容 |
| **RT-Thread** | Apache 2.0 | ~5-15KB | Low | 国产替代，中文社区活跃 |
| **Bare Metal** | — | ~1-2KB | High | 极致性能/资源控制，无 RTOS 开销 |

### Detailed Comparison

#### FreeRTOS (ESP-IDF 默认)
| 优势 | 劣势 |
|------|------|
| ESP-IDF 原生集成，无需额外配置 | 社区版本功能有限（需 ESP-IDF 增强版） |
| 双核 SMP 支持完美 | 高级功能（Trace、MPU）需自己配置 |
| 资源占用低，启动快 | 没有完整的 POSIX 兼容层 |
| 文档丰富，社区最大 | 跨平台移植需要 IDF 抽象层 |
| 自动 Tickless Idle 省电 | 内存管理需手动（heap_4 默认） |

#### Zephyr
| 优势 | 劣势 |
|------|------|
| 完善的设备驱动模型（Device Tree） | 学习曲线陡峭，概念多（Kconfig + DTS + CMake） |
| 内置网络协议栈（TCP/IP、BLE、Thread、Zigbee） | 编译慢，配置复杂 |
| 安全认证（IEC 61508、ISO 26262 进行中） | ESP32 支持不如 FreeRTOS 成熟 |
| 跨平台，同一套代码跑多种芯片 | 社区相对较小 |
| 原生支持 OTA、电源管理 | Flash/RAM 占用较大 |

#### ThreadX (Azure RTOS)
| 优势 | 劣势 |
|------|------|
| 高可靠性，通过多项安全认证 | 原为商业产品，开源历史短 |
| 确定性强，中断延迟可控 | 需要 NetX/USBX/FileX 学习额外 API |
| 完善的文件系统（FileX）、网络栈（NetX）、USB（USBX） | ESP32 适配不如 FreeRTOS 完善 |
| 支持内存保护（MPU/MMU） | 社区较小，中文资料少 |
| Picokernel 设计，内核精简 | Event Flags 等特性使用门槛高 |

#### NuttX
| 优势 | 劣势 |
|------|------|
| POSIX 兼容（/dev、VFS、pthread、socket） | ESP32 移植由小米维护，更新较慢 |
| 类 Linux 环境，容易移植 Linux 程序 | Flash/RAM 占用最大（需要 MMU 模拟） |
| 内置 Shell（NSH）、文件系统 | 启动慢，配置复杂 |
| 支持 ELF 动态加载 | 社区小，调试工具少 |
| 小米 Vela 物联网平台基于 NuttX | 实时性不如 FreeRTOS 和 ThreadX |

#### RT-Thread
| 优势 | 劣势 |
|------|------|
| 国产 RTOS，中文文档/社区丰富 | 国际社区较小 |
| 丰富的软件包生态（env 工具 + pkgs） | ESP32 移植为社区维护 |
| 内置文件系统（DFS）、网络协议栈（SAL） | 部分包质量参差不齐 |
| 组件化设计，按需裁剪 | IDE 支持不如 ESP-IDF |
| 支持 Python 脚本（MicroPython 绑定） | 多核支持不完善 |

#### Bare Metal (无 RTOS)
| 优势 | 劣势 |
|------|------|
| 最小 Flash/RAM 占用 | 无任务调度，需手动实现状态机 |
| 零上下文切换开销 | 复杂逻辑难以维护 |
| 完全确定性的执行时序 | 无网络协议栈、文件系统等中间件 |
| 适合极简应用（LED 控制、传感器读取） | 无法利用多核 |
| 适合学习底层硬件 | 电源管理需手动实现 |

### Selection Guide

```
AI 根据用户需求推荐 RTOS：

用户场景                                    推荐
─────────────────────────────────────────────────
快速原型 / 通用开发 / 学习 ESP32    →  FreeRTOS (默认，ESP-IDF 内置)
IoT 产品 / 多协议连接 / 安全认证     →  Zephyr
医疗 / 汽车 / 工业安全认证产品       →  ThreadX
移植 Linux 程序 / POSIX 兼容         →  NuttX
国产化要求 / 中文社区 / 组件丰富     →  RT-Thread
极致资源控制 / 简单传感器采集       →  Bare Metal
```

### AI Action Pattern for RTOS Selection

1. **When the user asks to create/initialize a project**, AI MUST present the RTOS options table above BEFORE creating the project.
2. Ask the user: "Which RTOS do you want to use? (or bare metal)"
3. Based on choice:
   - **FreeRTOS**: Create a standard ESP-IDF `app_main()` project (default template)
   - **Zephyr / ThreadX / NuttX / RT-Thread**: Flag that this requires additional setup and ask user to confirm
   - **Bare Metal**: Create a minimal project without FreeRTOS (use `app_main()` only, no task creation)
4. Record the choice and proceed with project creation

## Environment Detection

**ALL path information is stored in `esp32_env.json`, located alongside the scripts in this skill's `scripts/` directory.**

When any sub-skill loads:
1. First check if `esp32_env.json` exists
2. If it exists, read `idf_path`, `idf_tools_path`, `platform` from it
3. If it does NOT exist, run the platform-appropriate env scanner
4. Use the recorded paths in all subsequent operations

The JSON structure:
```json
{
  "idf_path": "D:\\esp32\\esp-idf",
  "idf_tools_path": "C:\\Users\\Administrator\\.espressif",
  "idf_python": "C:\\Python314\\python.exe",
  "idf_python_version": "Python 3.14.2",
  "idf_version": "v6.2",
  "platform": "windows",
  "timestamp": "2026-06-09"
}
```

**Common paths to check:**
- Windows: `$USERPROFILE\esp\esp-idf`, `D:\esp32\esp-idf`
- Linux: `~/esp/esp-idf`, `/opt/esp-idf`
- macOS: `~/esp/esp-idf`, `/opt/esp-idf`
- Toolchain default: `$HOME/.espressif` (all platforms)

## Reusable Scripts

All scripts are in the `scripts/` directory of this skill. Read and execute directly — do NOT regenerate.

| Script (Windows) | Script (Linux/macOS) | Purpose |
|------------------|---------------------|---------|
| `esp32_env_scan.ps1` | `esp32_env_scan.sh` | Auto-detect paths, record to esp32_env.json |
| `idf_export.ps1` | `idf_export.sh` | Export IDF environment (clears MSYSTEM) |
| `idf_build.ps1` | `idf_build.sh` | Build a project |
| `idf_flash_monitor.ps1` | `idf_flash_monitor.sh` | Flash + monitor |
| `esp32_chip_detect.ps1` | — | Auto-detect chip model via esptool |
| `idf_openocd.ps1` | — | Launch OpenOCD for built-in USB-JTAG |
| `idf_gdb.ps1` | — | Launch GDB via USB-JTAG |
| `check_jtag_driver.ps1` | — | Check USB device/driver status |
| `check_usb_devices.ps1` | — | List all USB and COM ports |
| `arduino_config.ps1` | `arduino_config.sh` | Arduino CLI setup |

## Chip Auto-Detection

**AI must use the `esp32_chip_detect.ps1` script to auto-detect the chip model.** Never guess.

```bash
# Find serial port first, then:
powershell -NoProfile -ExecutionPolicy Bypass -File "esp32_chip_detect.ps1" -port COMx
```

**Detection failure troubleshooting (in order):**
1. Ensure the device is in download mode (hold BOOT + tap EN on ESP32 boards)
2. For ESP32-S3 with built-in USB-JTAG, the port may change when entering download mode (e.g. COM11 → COM12)
3. Check USB cable is a data cable (not charge-only)
4. On Windows, check Device Manager → Ports for the correct COM number
5. Try lowering baud rate: `--baud 115200`
6. If auto-detect fails after multiple attempts — ask the user for the chip model directly
7. If the user provides the chip model, specify it with `--chip esp32s3` to speed up detection

## Chip Selection Guide

| Chip | Core | Wi-Fi | BLE | USB | Flash (PICO) | Best For |
|------|------|-------|-----|-----|--------------|----------|
| ESP32 | Xtensa dual | 4.x | Classic+BLE | No | 4MB | General purpose |
| ESP32-S2 | Xtensa | 4.x | No | OTG | 4MB | USB peripheral |
| ESP32-S3 | Xtensa dual | 4.x | BLE 5 | OTG | 8MB+ | AI, LCD, camera |
| ESP32-C3 | RISC-V | 4.x | BLE 5 | Serial | 4MB | Low cost, BLE |
| ESP32-C5 | RISC-V | 6 | BLE 5 | Serial | 4MB | Wi-Fi 6, cost-sensitive |
| ESP32-C6 | RISC-V | 6 | BLE 5/Zigbee/Thread | Serial | 8MB | Matter, Wi-Fi 6 |
| ESP32-H2 | RISC-V | No | BLE 5/Thread/Zigbee | No | 4MB | Thread/Zigbee only |
| ESP32-P4 | RISC-V dual | No | No | Yes | 16MB | High perf, no wireless |

## USB-JTAG Debugging (ESP32-S3/C3/C6/C2/H2)

### Hardware

ESP32-S3/C3/C6/C2/H2 have **built-in USB-JTAG** via GPIO19 (USB_D-) + GPIO20 (USB_D+). No external hardware required. The same USB cable used for flashing also provides JTAG debugging.

The USB composite device enumerates with multiple interfaces:
- **MI_00** → USB Serial (COM port for flashing/logging), uses `usbser` driver
- **MI_02** → USB JTAG (debug interface), needs `libusb-win32` driver on Windows

### Windows Driver Setup (CRITICAL)

**On Windows, the JTAG interface MUST use `libusb-win32` driver, NOT WinUSB.**

Use **Zadig** (https://zadig.akeo.ie/) to replace the driver:

1. Open Zadig → **Options → List All Devices** (must be checked!)
2. In the dropdown, find entries with USB ID **`303A:1001`**
3. Select **Interface 2** (MI_02) — the one with current driver "WINUSB"
4. Replace with **`libusb-win32`** (not WinUSB, not libusbK)
5. Click **Replace Driver**

> **IMPORTANT:** Only replace the driver for MI_02 (JTAG interface). Do NOT touch MI_00 (COM port, `usbser` driver) or the parent composite device (`usbccgp` driver).

**Verification:** After replacement, the device service should show `libusb0`:
```powershell
Get-PnpDevice | Where-Object { $_.FriendlyName -like '*JTAG*' }
```

### Launch OpenOCD + GDB

```bash
# Terminal 1 — OpenOCD (stays running)
idf.py openocd
# or:
powershell -NoProfile -ExecutionPolicy Bypass -File "idf_openocd.ps1" -project_path <path>

# Terminal 2 — GDB (interactive)
idf.py gdb
# or:
xtensa-esp32s3-elf-gdb build/<project>.elf
(gdb) target remote :3333
(gdb) mon reset halt
```

### Debugger Compatibility

| Debugger | ESP32 | ESP32-S3/C3/C6/C2/H2 | Notes |
|----------|:-----:|:---------------------:|-------|
| **Built-in USB-JTAG** | ❌ | ✅ | GPIO19+20, no extra hardware |
| **ESP-Prog** | ✅ | ✅ | Espressif official |
| **J-Link** | ✅ | ✅ | Segger universal |
| **FT2232H** | ✅ | ✅ | Low-cost, OpenOCD native |
| **STLink** | ❌ | ❌ | ARM Cortex-M only |

## Common Pitfalls

### Windows
1. **MSYSTEM Detection**: Must use PowerShell via script files, NOT Git Bash directly
2. **ESP32-S3 USB-JTAG driver**: Must replace WinUSB with libusb-win32 via Zadig
3. **Port changes in download mode**: ESP32-S3 may enumerate as different COM port when entering download mode
4. **Cross-drive create-project bug**: `idf.py create-project -path` fails when IDF is on a different drive than project. Create project structure manually instead.
5. **Proxy Duplicate Keys**: Clear `*proxy*` vars before `.ps1`

### Linux
1. **Serial permission**: `sudo usermod -a -G dialout $USER` (re-login required)
2. **Port busy**: `sudo chmod 666 /dev/ttyUSB0` if permission denied
3. **Missing libs**: `sudo apt install libusb-1.0-0`

### macOS
1. **Serial driver**: CP210x/CH340 may need driver install
2. **Port format**: `/dev/cu.usbserial-*`, not `/dev/tty.*`

### All Platforms
1. **Python version**: ESP-IDF v5.x/v6.x requires Python 3.8+ (tested up to 3.14)
2. **Missing submodules**: `git submodule update --init --recursive` (required after `git clone` without `--recursive`)
3. **Data cable**: Some USB cables are charge-only — use a proper data cable
4. **Submodule checkout**: After `git submodule update --init`, may need `--force --checkout` for full file checkout
5. **Build directory conflicts**: If `set-target` fails, manually delete `build/` and `sdkconfig` before retrying
6. **idf.py openocd requires project dir**: Must run from project directory, not IDF root

## Skill Hierarchy

```
esp32-dev (entry point — this file)
├── esp32-dev-idf    → ESP-IDF framework setup + project lifecycle
├── esp32-dev-arduino → Arduino framework setup + project lifecycle
└── esp32-debug      → Debug workflow (serial log + JTAG/GDB)
```

**Division of responsibility:**
- `esp32-dev`: Framework selection, OS detection, shared knowledge (chip detection, USB-JTAG, scripts reference)
- `esp32-dev-idf`: IDF-specific installation, project creation, compile/flash/monitor
- `esp32-dev-arduino`: Arduino-specific installation, project creation, compile/flash
- `esp32-debug`: Systematic debug workflow — problem understanding → code analysis → debug method selection → root cause analysis → report
