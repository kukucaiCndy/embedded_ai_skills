---
name: "esp32-debug"
description: "ESP32 debugging via serial log and USB-JTAG (OpenOCD + GDB). Invoke when user encounters bugs, crashes, or unexpected behavior on ESP32 and needs systematic root cause analysis."
---

# ESP32 Debug — Systematic Troubleshooting

## Overview

This skill covers the complete debug workflow for ESP32 projects:
- **Serial log debugging** (ESP_LOGI/ESP_LOGE) — lightweight, non-intrusive, preferred first approach
- **USB-JTAG debugging** (OpenOCD + GDB) — deep hardware-level debugging
- **Combined approach** (serial + JTAG) for complex issues

## Platforms

| Debug Method | ESP32 | ESP32-S3/C3/C6/C2/H2 | Hardware Required |
|--------------|:-----:|:---------------------:|-------------------|
| Serial log | ✅ | ✅ | USB cable only |
| USB-JTAG (built-in) | ❌ | ✅ | USB cable only |
| External JTAG | ✅ | ✅ | ESP-Prog / J-Link |

## Execution Flow

```
User reports a bug/crash/unexpected behavior
  ↓
[Step 1] 🔍 环境准备 — Verify dev environment, tools, connections
  ↓
[Step 2] ❓ 问题理解 — Ask clarifying questions to scope the problem
  ↓
[Step 3] 📖 代码研读 — Read ALL relevant code BEFORE making changes
  ↓
[Step 4] 🔧 调试方案选择 — Choose method A (serial), B (JTAG), or C (combined)
  ↓
[Step 5] ⚡ 方案执行 — Add diagnostics, build, flash, capture data
  ↓
[Step 6] 🧠 根因分析 — Identify direct + root cause with evidence
  ↓
[Step 7] 📋 报告输出 — Structured report with analysis + fix options
  ↓
[Step 8] ⏳ 等待用户决策 — Wait for user to choose action
```

---

## Step 1: Environment Preparation

### 1.1 Verify esp32-dev Skill

> **AI 首次执行本 Skill 时，必须先确认 `esp32-dev` skill 已加载。**

```
AI 自行判断 esp32-dev skill 是否可用：
1. 检查 esp32_env.json 是否存在（位于当前 skill 的 scripts/ 目录）
2. 检查脚本 idf_export.ps1、idf_build.ps1 等是否可用
3. 如缺少关键脚本或环境文件 → 引导用户先执行 esp32-dev skill 完成环境初始化
```

> esp32-dev skill 提供完整的 ESP-IDF 工具链路径、工程编译、烧录流程。本 Skill 的编译/烧录步骤均复用 esp32-dev 的能力。

### 1.2 检查 USB-JTAG 连接（方案 B / C 必需）

> **AI 在使用 JTAG 调试前，必须先探测设备并验证连接。**

**Step A — 检查 USB 设备是否被系统识别：**

```bash
# Windows — 用脚本检查 USB 设备列表和驱动状态
powershell -NoProfile -ExecutionPolicy Bypass -File "check_jtag_driver.ps1"
```

查看输出中是否有 `USB JTAG/serial debug unit` (VID 303A, PID 1001)，且 MI_02 接口的驱动为 `libusb0`。

| 结果 | 动作 |
|------|------|
| 设备存在 + 驱动为 `libusb0` | ✅ 继续 |
| 设备存在 + 驱动为 `WINUSB` | ❌ 引导用户使用 Zadig 替换驱动（见 `esp32-dev` skill） |
| 设备不存在 | ❌ 检查 USB 线、芯片型号是否支持 USB-JTAG（ESP32 经典版不支持） |

**Step B — 启动 OpenOCD 并验证 JTAG 连接：**

```bash
# Windows — 使用脚本启动 OpenOCD
powershell -NoProfile -ExecutionPolicy Bypass -File "idf_openocd.ps1" -project_path <project_dir>

# Linux/macOS
idf.py openocd
```

**预期输出：**
```
Info : esp_usb_jtag: Device found.
Info : JTAG tap: esp32s3.tap0 tap/device found: 0x120034e5
Info : [esp32s3.cpu0] Examination succeed
Info : [esp32s3.cpu1] Examination succeed
Info : Listening on port 3333 for gdb connections
```

| 结果 | 动作 |
|------|------|
| CPU0/CPU1 Examination succeed | ✅ JTAG 调试通道正常 |
| `LIBUSB_ERROR_NOT_FOUND` | ❌ 驱动问题，回到 Step A 替换驱动 |
| `JTAG tap: esp32s3.tap0 found` | ✅ 芯片识别正确 |
| Only CPU0 found | 正常（部分芯片为单核） |

**Step C — 验证 OpenOCD 可读写芯片内存：**

```bash
# 通过 OpenOCD telnet 快速验证
echo -e "mdw 0x3FC9C000 4\nexit" | telnet localhost 4444
```

> 如能正常输出内存地址和对应的 hex 值，说明 JTAG 读写通道正常。

### 1.3 安装并配置串口监听工具

**指定工具 — EmberInterDebugTool（首选）：**

> **本工具为安装包形式，需安装后才能使用。** 工具配套 **GUI** 和 **CLI** 两种模式，**使用前需先启动 GUI**。

**下载地址：** `https://github.com/kukucaiCndy/EmberinterTool/releases`

| 步骤 | 操作 |
|------|------|
| 1. 下载安装包 | 从 Releases 页面下载最新安装包（`.exe` / `.dmg` / `.deb`） |
| 2. 运行安装程序 | 按安装向导完成安装，记录安装目录 |
| 3. 启动 GUI | 安装完成后先启动 GUI，确认工具正常运行 |
| 4. CLI 可用 | GUI 启动后，CLI 命令行接口才可用于脚本/自动化场景 |

**安装后默认路径：** `C/D/E/F:\Program Files (x86)\EmberInterDebugTool`

**GUI 架构：** GUI 负责串口连接管理，CLI 通过 IPC 与 GUI 联动。CLI 可随时启停，不影响串口数据采集。CLI 断连不影响串口数据持续采集。

#### 加载工具 Skill 并学习 CLI 命令

> **AI 在使用串口工具前，必须先加载工具对应的 skill，掌握其命令行参数。**

**Skill 获取来源（按优先级）：**

```
1. 本地优先：从工具安装目录获取
   常见路径:
     Windows:  C/D/E/F:\Program Files (x86)\EmberInterDebugTool\skill\

2. 线上备用：从 GitHub 仓库获取
   https://github.com/kukucaiCndy/embedded_ai_skills/tree/master/tools/emberinter
```

> **⚠️ 不要假设参数名。** 必须通过 skill 中的说明确认后再使用。

#### CLI 关键命令速查

**连接管理：**
```bash
# 列出可用串口
serial-monitor-cli --list

# 连接并清空日志
serial-monitor-cli --connect COM10 --baudrate 115200 --clear

# 交互模式（持续运行，可收发）
serial-monitor-cli -p COM10 --cli
```

**数据发送：**
```bash
# 发送文本（自动追加 CRLF）
serial-monitor-cli --send "help" -p COM10

# 发送 HEX 字节（不加换行符）
serial-monitor-cli --send-hex "FF AB 03 1A" -p COM10
```

**日志监听与诊断：**
```bash
# 持续监听并保存到文件
serial-monitor-cli -p COM10 -o esp32_log.txt

# 只显示含 ERROR 的日志
serial-monitor-cli -p COM10 -f ERROR

# 获取最近日志（JSON 格式，适合脚本解析）
serial-monitor-cli --get-logs 50 --json

# 查看连接状态
serial-monitor-cli --get-status --json
```

**交互模式命令（`--cli` 进入后）：**
| 命令 | 说明 |
|------|------|
| `connect <port> [baud]` | 连接指定串口，默认 115200 |
| `disconnect` / `disc` | 断开当前串口 |
| `send <text>` | 发送文本（自动加 CRLF） |
| `sendhex <hex>` | 发送 HEX 字节 |
| `filter <keyword>` | 过滤关键词，空字符串取消过滤 |
| `hex` / `text` | 切换 HEX 显示模式 |
| `status` / `s` | 查看当前连接状态 |
| `clear` / `c` | 清空日志缓冲区 |
| `quit` / `q` | 退出 CLI（GUI 继续运行） |

#### 固件烧录后验证工作流

```bash
# Step 1: 确保 GUI 已运行，启动 CLI 持续监听
serial-monitor-cli -p COM10 -o esp32_log.txt

# Step 2: 烧录固件（需先断开 EmberInterDebugTool 连接以释放端口）
taskkill /F /IM serial-monitor.exe   # 关闭 GUI，释放 COM 口
idf.py -p COM10 flash                 # 烧录

# Step 3: 重启 GUI + 连接 + 发送命令验证
start "" "D:/Program Files (x86)/EmberInterDebugTool/serial-monitor.exe"
serial-monitor-cli --connect COM10 --baudrate 115200 --clear
serial-monitor-cli --send "help" -p COM10
sleep 2
serial-monitor-cli --get-logs 50 --json
```

> **注意：** GUI 占用串口时 `idf.py flash` 会失败。烧录前需先关闭 GUI 释放端口。烧录完成后重启 GUI 进行交互测试。

#### 备选工具 — idf.py monitor

ESP-IDF 自带串口监听也可作为备选：
```bash
idf.py -p COM10 monitor
```
但优先使用 EmberInterDebugTool 以获得统一的调试体验。

### 1.4 准备调试工具链

**AI 在执行调试前必须确认以下工具可用：**

| 工具 | 用途 | 验证命令 | 来源 |
|------|------|---------|------|
| `esptool` | 芯片检测、Flash 读写 | `esptool --version` | ESP-IDF 工具链 |
| `idf.py monitor` | 串口监听 | `idf.py monitor --help` | ESP-IDF |
| `openocd` | JTAG 调试服务器 | 通过 `idf_openocd.ps1` 脚本启动 | ESP-IDF 工具链 |
| `xtensa-esp32s3-elf-gdb` | GDB 调试客户端 | `xtensa-esp32s3-elf-gdb --version` | ESP-IDF 工具链 |
| `xtensa-esp32s3-elf-objdump` | 反汇编 | `xtensa-esp32s3-elf-objdump --version` | ESP-IDF 工具链 |
| `xtensa-esp32s3-elf-nm` | 符号表 | `xtensa-esp32s3-elf-nm --version` | ESP-IDF 工具链 |
| `xtensa-esp32s3-elf-addr2line` | 地址到源码行 | `xtensa-esp32s3-elf-addr2line --help` | ESP-IDF 工具链 |

> **⚠️ 所有工具路径通过 `esp32_env.json` 自动获取，AI 使用脚本封装后调用。** 不要硬编码工具路径，始终通过脚本或 `esp32_env.json` 中的路径。

**芯片前缀速查表：**

| 芯片 | GDB 前缀 | objdump/nm/addr2line 前缀 |
|------|---------|--------------------------|
| ESP32 | `xtensa-esp32-elf-` | `xtensa-esp32-elf-` |
| ESP32-S2 | `xtensa-esp32s2-elf-` | `xtensa-esp32s2-elf-` |
| ESP32-S3 | `xtensa-esp32s3-elf-` | `xtensa-esp32s3-elf-` |
| ESP32-C3/C6/H2 | `riscv32-esp-elf-` | `riscv32-esp-elf-` |

---

## Step 2: Problem Understanding

**AI MUST ask the user these 4 questions before proceeding:**

### Q1: Problem symptoms
> "请详细描述问题现象。例如：程序卡死在某处、重启循环、输出异常值、外设不工作、Wi-Fi/BLE连接失败等。"

### Q2: Reproducibility
> "问题是稳定复现还是偶发？如果是稳定复现，触发条件是什么？"

### Q3: Recent changes
> "最近修改了哪些代码？有没有新增功能、修改配置、更换硬件？"

### Q4: Device state
> "设备当前状态是什么？串口有什么输出？有没有 panic 信息、backtrace 或错误日志？"

**After gathering answers, AI should classify the problem type:**
- **Crash/Panic** → Priority: JTAG + backtrace analysis
- **Logic error** (wrong behavior) → Priority: Serial log + code review
- **Performance** (slow, timing issue) → Priority: Serial log with timestamps
- **Connectivity** (Wi-Fi/BLE) → Priority: ESP_LOG + protocol analysis

---

## Step 3: Code Reading

**AI MUST read all relevant code BEFORE suggesting any changes.**

### Reading scope:
1. `main.c` — app_main() and main logic
2. All ISRs (interrupt service routines) in the project
3. FreeRTOS task creation and callback functions
4. Initialization code (GPIO, peripherals, Wi-Fi, BLE)
5. `sdkconfig` — check relevant Kconfig settings
6. Custom components in `components/`
7. IDF framework configs if relevant (e.g., `CONFIG_FREERTOS_*`, `CONFIG_ESP_WIFI_*`)

### Analysis checklist:
- [ ] Variable initialization — are all variables properly initialized?
- [ ] Function call chain — trace the execution path
- [ ] Timing/delay — are `vTaskDelay()` values sensible?
- [ ] Buffer sizes — are buffers large enough? No overflows?
- [ ] Stack sizes — are FreeRTOS task stacks sufficient?
- [ ] ISR timing — are ISRs short enough? No blocking calls?
- [ ] Interrupt priority — are priorities correct? (higher number = lower priority on ESP32)
- [ ] Shared data — are critical sections/mutexes used for shared resources?
- [ ] Error handling — are `ESP_ERROR_CHECK()` return values checked?
- [ ] Memory — any null pointer dereferences? Memory leaks?

---

## Step 4: Debug Method Selection

### Method A: Serial Log (首选 — Preferred)
- **When**: Stable repro, device responsive, logic/peripheral issues
- **Pros**: No extra hardware, real-time, low intrusion, keeps CPU running
- **Cons**: Limited to what you log, can miss transient states
- **Tools**: `ESP_LOGI()` / `ESP_LOGE()` macros + `idf.py monitor`

### Method B: USB-JTAG (备选 — Backup)
- **When**: Crash/panic, device unresponsive, need CPU register/stack dump
- **Pros**: Full CPU control, breakpoints, watchpoints, register dump
- **Cons**: Halts CPU, needs driver setup (Zadig on Windows)
- **Tools**: OpenOCD + GDB (`idf.py openocd` + `idf.py gdb`)

### Method C: Serial + JTAG Combined (联用)
- **When**: Complex issue — serial shows anomaly, JTAG provides context
- **Pros**: Best of both worlds, cross-validation
- **Workflow**: Serial log triggers → JTAG breakpoint to confirm
- **Example**: ESP_LOGI reports bad value → GDB `watch` to find writer

### Decision Flow
```
Can the device output serial logs?
  ├── YES → Method A (add ESP_LOGI diagnostics)
  └── NO  → Does the device have USB-JTAG?
              ├── YES → Method B (OpenOCD + GDB)
              └── NO  → Method A with minimalist logging (UART0 always works)
```

---

## Step 5: Method A — Serial Log Debugging

### 5.1 Add diagnostic logs

**AI should insert ESP_LOG calls at key points:**

```c
// Function entry/exit
ESP_LOGI(TAG, "function_name: entry, param=%d", param);

// Variable state
ESP_LOGI(TAG, "state: var1=%d, var2=0x%08x, ptr=%p", var1, var2, ptr);

// Error paths
ESP_LOGE(TAG, "error: esp_err=%s (0x%x)", esp_err_to_name(err), err);

// FreeRTOS task info
ESP_LOGI(TAG, "task: %s, stack_free=%lu", pcTaskGetName(NULL), 
         uxTaskGetStackHighWaterMark(NULL));

// Heap info
ESP_LOGI(TAG, "heap: free=%lu, min_free=%lu", 
         esp_get_free_heap_size(), esp_get_minimum_free_heap_size());

// Wi-Fi state
ESP_LOGI(TAG, "wifi: state=%d, rssi=%d", wifi_state, rssi);

// Timing
int64_t t_start = esp_timer_get_time();
// ... operation ...
ESP_LOGI(TAG, "operation took %lld us", esp_timer_get_time() - t_start);
```

### 5.2 Log format convention
```
[timestamp] [TAG] [LEVEL] message
Example: I (12345) main: state: var1=42, var2=0x3FFC0000
```

**AI must use structured log patterns:**
- Use `[DEBUG]` prefix in messages for AI-added diagnostic logs
- Log variable names AND values: `var_name=value`
- Log return/error codes in both hex and name: `esp_err=ESP_ERR_TIMEOUT (0x107)`

### 5.3 Build, flash, capture
```bash
idf.py build
idf.py -p <PORT> flash monitor
```
Let the device run until the issue occurs. Save the full log output.

### 5.4 Analyze logs
- Identify the first anomaly in the log sequence
- Trace the execution path from the last normal log to the first abnormal log
- Compare expected vs actual values
- Check timing gaps between log entries

---

## Step 6: Method B — USB-JTAG Debugging (OpenOCD + GDB)

### 6.1 Trigger conditions

```
When to use USB-JTAG debugging:
- Device crashes immediately on boot, serial has no output
- Device hangs after running for a while, serial output stops
- Guru Meditation Error / panic handler triggered
- Need to inspect CPU registers at exact crash moment
- Need to read peripheral register state without modifying code
- Stack overflow or heap corruption suspected
```

### 6.2 Prepare JTAG connection

**On Windows:** Verify driver is `libusb0` (not WINUSB) for the JTAG interface.
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "check_jtag_driver.ps1"
```

### 6.3 Start OpenOCD and probe chip

```bash
# Terminal 1 — Keep running
idf.py openocd
```

**Verify connection with expected output:**
```
Info : esp_usb_jtag: Device found.
Info : JTAG tap: esp32s3.tap0 tap/device found: 0x120034e5
Info : [esp32s3.cpu0] Examination succeed
Info : [esp32s3.cpu1] Examination succeed
Info : Listening on port 3333 for gdb connections
```

### 6.4 Connect GDB and halt

```bash
# Terminal 2 — Interactive session
xtensa-esp32s3-elf-gdb build/<project>.elf
```

```gdb
# Inside GDB:
target remote :3333
mon reset halt
```

### 6.5 Read CPU registers

```gdb
info registers              # All CPU registers
print/x $a0                 # Specific register (a0-a15 for Xtensa)
print/x $pc                 # Program counter
print/x $sp                 # Stack pointer
print/x $a0                 # Return address (caller)
```

### 6.6 Parse crash call stack

**According to PC/LR/SP, reconstruct the call chain:**

```bash
# Disassemble PC address to locate the crash function
xtensa-esp32s3-elf-objdump -d build/<project>.elf | grep -A10 "<PC_VALUE>"

# Check symbol table for function name
xtensa-esp32s3-elf-nm build/<project>.elf | sort | grep <ADDRESS>

# Map address to source file and line number
xtensa-esp32s3-elf-addr2line -e build/<project>.elf <PC_ADDRESS>

# Dump stack contents from SP (512 bytes)
x/128x $sp
```

### 6.7 Dump memory regions (OpenOCD telnet)

> **使用 `telnet localhost 4444` 连接 OpenOCD 命令行，执行内存 dump。**

**Dump SRAM (DRAM) — 等效于 stm32-debug 的 `st-flash read`:**
```
# 读取从 0x3FC9C000 开始的 256 words (1024 bytes)
mdw 0x3FC9C000 256
# 或保存为文件
save_image /tmp/dram_dump.bin 0x3FC9C000 0x10000
```

**Dump Flash 内容:**
```
# 读取 Flash 从 0x0000 开始的 256 words
flash read_bank 0 /tmp/flash_dump.bin 0x0000 256
```

**Dump 外设寄存器:**
```
# GPIO 寄存器
mdw 0x60004000 16

# RCC 时钟寄存器
mdw 0x60008000 32

# NVIC 中断寄存器
mdw 0x600C2000 64

# UART0 寄存器
mdw 0x60000000 16
```

### 6.8 Read peripheral registers

**ESP32-S3 关键外设寄存器基址：**

| Peripheral | Base Address | Key Registers / Offset |
|------------|-------------|----------------------|
| GPIO | 0x60004000 | OUT(+0x04), IN(+0x3C), ENABLE(+0x20) |
| IO MUX | 0x60009000 | Pin config per GPIO (+0x04*n) |
| GPIO Matrix | 0x6000D000 | Signal routing |
| UART0 | 0x60000000 | FIFO(+0x00), INT_RAW(+0x04), STATUS(+0x1C) |
| UART1 | 0x60010000 | 同上 |
| UART2 | 0x6002E000 | 同上 |
| RTC | 0x60008000 | Clock config, sleep control |
| SYSTIMER | 0x60023000 | 52-bit system timer |
| INTERRUPT | 0x600C2000 | Interrupt matrix |
| RTC_CNTL | 0x60008000 | Brownout, RTC GPIO, wakeup |
| SPI0 | 0x60002000 | Cache access SPI |
| SPI1 | 0x60003000 | Flash SPI |
| SPI2 | 0x60024000 | GPSPI2 (user SPI) |
| SPI3 | 0x60025000 | GPSPI3 (user SPI) |
| I2C0 | 0x60013000 | I2C controller 0 |
| I2C1 | 0x60027000 | I2C controller 1 |

**通过 OpenOCD telnet 读写寄存器 (`localhost:4444`):**
```
mdw 0x60004000 10           # 读 GPIO 基址 10 words
mdw 0x60004004              # 读 GPIO OUT 寄存器
mww 0x60004008 0x01         # 写 GPIO OUT1 置高
```

### 6.9 CPU crash analysis commands

```gdb
bt                          # 当前任务调用栈
thread apply all bt         # 所有 FreeRTOS 任务调用栈
info threads                # 列出所有 FreeRTOS 任务
thread 3                    # 切换到任务 3
```

**Breakpoints:**
```gdb
break main                  # main() 入口
break app_main              # app_main() 入口
break main.c:42             # 指定行断点
info breakpoints            # 列出断点
delete 1                    # 删除断点 1
```

**Watchpoints (hardware):**
```gdb
watch variable_name         # 写监视
rwatch variable_name        # 读监视
awatch variable_name        # 读写监视
```

**Continue/Step:**
```gdb
continue                    # 继续运行
step                        # 单步进入
next                        # 单步跳过
finish                      # 运行到当前函数返回
```

### 6.10 Panic/Crash analysis

When ESP32 panics, the chip halts and OpenOCD captures the state:

```gdb
bt                          # 获取崩溃调用栈
info registers              # 获取全部寄存器
x/20x $sp                   # 栈内容
```

**Xtensa 关键 panic 寄存器:**
- `PC` (Program Counter) — 崩溃指令地址
- `EXCCAUSE` (exception cause) — 异常原因码
  - `0` IllegalInstruction
  - `28` LoadProhibited (访问非法地址读)
  - `29` StoreProhibited (访问非法地址写)
- `EXCVADDR` — 导致异常的地址
- `A0` — 返回地址（调用者）
- `A1` (SP) — 栈指针

**将 PC 映射到源码行:**
```bash
xtensa-esp32s3-elf-addr2line -e build/<project>.elf <PC_ADDRESS>
```

---

## Step 7: Method C — Serial + JTAG Combined

### 7.1 Setup
- Terminal 1: `idf.py openocd` (background)
- Terminal 2: `idf.py monitor` (serial monitor)
- Terminal 3: GDB session (connect when needed)

### 7.2 Workflow
1. Serial log shows anomaly → note exact timestamp/variable value
2. Pause in GDB: `Ctrl+C` then `mon reset halt` or set breakpoint
3. Inspect CPU state at the point of interest
4. Resume with `continue`
5. Cross-reference serial log values with GDB register/memory readings

---

## Step 8: Root Cause Analysis

### Core principle
**crash点不等于根因** — the crash point is often a symptom, not the cause.
Example: Null pointer dereference at line 200 → root cause was missing init at line 50.

### Analysis checklist (ESP32-specific)

1. **Peripheral clock/config** — Is the peripheral clock enabled? Check `periph_module_enable()` or `sdkconfig`.
2. **GPIO configuration** — Correct pin number? Correct mode (INPUT/OUTPUT)? Pull-up/down?
3. **Kconfig settings** — Are required features enabled in `sdkconfig`?
   - `CONFIG_LOG_DEFAULT_LEVEL_*` — log verbosity
   - `CONFIG_FREERTOS_*` — task stack sizes, tick rate
   - `CONFIG_ESP_WIFI_*` — Wi-Fi mode, power save
4. **CMakeLists / component registration** — Are all source files listed? Components registered?
5. **ISR naming convention** — IRAM_ATTR on ISR functions? Correct interrupt allocation?
6. **FreeRTOS task stack** — Check with `uxTaskGetStackHighWaterMark(NULL)`. Add if < 512 bytes.
7. **Buffer sizes** — Are buffers large enough? Check memory boundaries.
8. **DMA alignment** — DMA buffers must be aligned and in internal RAM (DRAM).
9. **Wi-Fi/BLE coexistence** — Check `esp_wifi_set_ps(WIFI_PS_NONE)` for debugging.
10. **Heap corruption** — Enable `CONFIG_HEAP_POISONING_*` and `CONFIG_HEAP_TRACING`.
11. **Watchdog** — Is the task watchdog triggering? Check `CONFIG_ESP_TASK_WDT_*`.
12. **Power/brownout** — Check power supply stability. Enable `CONFIG_ESP_BROWNOUT_DET`.

### Common ESP32 crash patterns

| Symptom | Likely Cause | Debug Approach |
|---------|-------------|----------------|
| `Guru Meditation Error: StoreProhibited` | Writing to invalid address | JTAG: check EXCVADDR, trace the store instruction |
| `Guru Meditation Error: LoadProhibited` | Reading from invalid address | JTAG: check EXCVADDR, null pointer? |
| `Guru Meditation Error: IllegalInstruction` | Corrupted code / jump to data | Check flash integrity, stack overflow |
| `assert failed: ...` | Assertion violation | Read assertion file:line, check condition |
| `abort() called` | ESP_ERROR_CHECK failed | Check the esp_err_t return value |
| `WDT timeout` | Task hung or infinite loop | Check task stack, add ESP_LOGI to detect hang location |
| `Brownout detector triggered` | Power supply issue | Check USB cable, power supply current rating |
| `Heap corruption detected` | Buffer overflow, double free | Enable heap poisoning, use JTAG watchpoint |
| Wi-Fi disconnect loop | Auth failure, signal weak | Check RSSI, password, channel, `WIFI_PS_NONE` |

---

## Step 9: Report Output

AI should produce a **structured Markdown report**:

```markdown
## Debug Report: [brief issue description]

### 1. Problem Summary
- **Phenomenon**: [what happens]
- **Reproducibility**: [stable / intermittent / triggered by ...]
- **Recent changes**: [code changes or events]

### 2. Debug Method
- **Method used**: [Serial / JTAG / Combined]
- **Tools**: [list tools and commands used]

### 3. Code Analysis
- **Files reviewed**: [list]
- **Suspicious areas**: [specific lines/functions with reasoning]

### 4. Debug Data

[Paste sanitized serial logs, GDB output, register dumps]

| Variable | Expected | Actual | Location |
|----------|----------|--------|----------|
| xxx      | xxx      | xxx    | main.c:42 |

### 5. Root Cause Analysis
- **Direct cause**: [proximate reason for the failure]
- **Root cause**: [underlying reason the direct cause happened]
- **Evidence chain**: 
  1. [Observation 1]
  2. [Observation 2] → leads to root cause

### 6. Solution
- **Recommended fix**: [code changes with rationale]
- **Alternative approach**: [if applicable]
- **Affected files**: [list files to modify]

### 7. Verification
- [Steps to verify the fix works]
```

---

## Step 10: Wait for User Decision

After presenting the report, **AI must wait for user response.** Do NOT apply fixes automatically.

Present options:
1. **按推荐的方案修改代码** → AI implements the recommended fix
2. **我想自己手动修改** → User makes changes, AI assists with review
3. **需要更多信息** → AI gathers more debug data
4. **重新分析** → AI revisits with different approach

---

## Quick Reference: ESP32 Debug Commands

### Serial Monitor
```bash
idf.py -p COMx monitor                              # Start monitor (Ctrl+] to exit)
idf.py -p COMx monitor | tee serial_log.txt         # Save log to file

# In-monitor shortcuts:
# Ctrl+T Ctrl+H → Help
# Ctrl+T Ctrl+F → Toggle timestamps
# Ctrl+T Ctrl+L → Clear screen
```

### Chip Detection
```bash
# Via script (Windows)
powershell -NoProfile -ExecutionPolicy Bypass -File "esp32_chip_detect.ps1" -port COMx

# Manual
esptool --port COMx flash-id
```

### OpenOCD (JTAG server — runs once, stays running)
```bash
# Windows via script
powershell -NoProfile -ExecutionPolicy Bypass -File "idf_openocd.ps1" -project_path <path>

# Direct
idf.py openocd
```

### GDB (connect to running OpenOCD)
```bash
xtensa-esp32s3-elf-gdb build/project.elf
(gdb) target remote :3333
(gdb) mon reset halt
```

### GDB Commands Quick Reference
| Command | Purpose |
|---------|---------|
| `target remote :3333` | Connect GDB to OpenOCD |
| `mon reset halt` | Reset chip + halt at boot ROM |
| `break func` / `break file.c:42` | Breakpoint at function / line |
| `watch var` / `rwatch var` | Hardware watchpoint (write / read) |
| `continue` / `c` | Continue execution |
| `step` / `s` | Step into |
| `next` / `n` | Step over |
| `finish` | Run to return of current function |
| `bt` / `backtrace` | Call stack |
| `thread apply all bt` | All FreeRTOS task call stacks |
| `info threads` | List FreeRTOS tasks |
| `info registers` | CPU registers (Xtensa: PC, A0-A15, SP, etc.) |
| `print var` / `print/x $pc` | Print variable / register |
| `x/128x $sp` | Hex dump 128 words from stack pointer |
| `delete 1` | Delete breakpoint 1 |
| `quit` | Exit GDB |

### OpenOCD Telnet (port 4444) — Memory & Register Dump
```
telnet localhost 4444

# System info
> targets                     # List JTAG targets (CPU0/CPU1)
> flash banks                 # List flash banks

# Memory read
> mdw 0x3FC9C000 256          # Read 256 words from DRAM (1024 bytes)
> mdw 0x60004000 16           # Read GPIO registers
> mdw 0x60008000 32           # Read RTC registers
> mdw 0x600C2000 64           # Read interrupt matrix

# Memory write
> mww 0x60004008 0x01         # Write GPIO OUT1 = HIGH

# Flash dump to file
> flash read_bank 0 /tmp/flash_dump.bin 0x0000 256

# Save memory region to file
> save_image /tmp/dram_dump.bin 0x3FC9C000 0x10000

# Chip control
> reset halt                  # Reset and halt
> resume                      # Resume execution
> reg                         # Dump all CPU registers
> exit                        # Exit telnet
```

### ELF Analysis (offline)
```bash
# Disassemble full binary
xtensa-esp32s3-elf-objdump -d build/project.elf > disasm.txt

# Disassemble specific address
xtensa-esp32s3-elf-objdump -d build/project.elf | grep -A10 "<0x40001234>"

# Symbol table
xtensa-esp32s3-elf-nm build/project.elf | sort

# Section headers (memory layout)
xtensa-esp32s3-elf-objdump -h build/project.elf

# Address → source file + line number
xtensa-esp32s3-elf-addr2line -e build/project.elf 0x40001234

# Binary size breakdown
xtensa-esp32s3-elf-size build/project.elf
```
