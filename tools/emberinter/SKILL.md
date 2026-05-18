---
name: "emberinter"
description: "Use EmberInterDebugTool CLI for serial monitoring, device communication, firmware verification, and embedded debugging. Invoke when user needs serial interaction, log analysis, or AT command testing."
---

# EmberInterDebugTool (尘智串口调试工具)

嵌入式串口监控调试工具。GUI 负责串口连接管理，CLI 通过 IPC 与 GUI 联动。CLI 可随时启停，不影响串口数据采集。

## 前置条件

**CLI 所有操作都需要 GUI 已在运行**。如果 CLI 报 `GUI 服务未运行`，必须先启动 GUI。

### 安装后默认路径

安装包为 `emberInter-Setup-x.y.z.exe`，默认安装到 `Program Files (x86)\EmberInterDebugTool`，可能位于 C/D/E/F 盘中：

| 文件 | 用途 |
|------|------|
| `serial-monitor.exe` | GUI 图形界面程序 |
| `serial-monitor-cli.exe` | CLI 命令行工具 |
| `emberInter.bat` | GUI 启动脚本 (双击即可) |
| `emberInter-cli.bat` | CLI 启动脚本 |

### 启动 GUI

**使用 CLI 之前必须确保 GUI 已运行。** 先在 C/D/E/F 盘中搜索安装目录，找到后启动 GUI：

```bash
# 遍历盘符，找到第一个存在的 GUI 并启动
for DRV in C D E F; do
    GUI="$DRV:/Program Files (x86)/EmberInterDebugTool/serial-monitor.exe"
    if [ -f "$GUI" ]; then
        start "" "$GUI"
        echo "GUI started: $GUI"
        break
    fi
done
```

也可以用 `.bat` 启动脚本：

```bash
for DRV in C D E F; do
    BAT="$DRV:/Program Files (x86)/EmberInterDebugTool/emberInter.bat"
    if [ -f "$BAT" ]; then
        start "" "$BAT"
        break
    fi
done
```

> GUI 启动后无需登录或配置，系统托盘会显示图标。GUI 在后台提供 IPC 服务 (默认 `serial_monitor_ipc`)，CLI 通过该服务与之通信。

### 定位 CLI

```bash
for DRV in C D E F; do
    CLI="$DRV:/Program Files (x86)/EmberInterDebugTool/serial-monitor-cli.exe"
    if [ -f "$CLI" ]; then
        break
    fi
done
echo "CLI path: $CLI"
```

---

## 两种运行模式

### 模式一：单次命令模式（非交互）

执行单个操作后自动退出，适合脚本/AI调用。格式：

```bash
serial-monitor-cli --<command> [options]
```

### 模式二：交互模式（--cli）

进入交互式终端，持续运行直到用户输入 `quit`：

```bash
serial-monitor-cli -p <PORT> --cli
```

---

## 命令参考（按功能分类）

### 连接管理

| 命令行 (单次) | 交互模式 | 说明 |
|---------------|----------|------|
| `--connect PORT` | `connect <port> [baud]` | 连接指定串口 |
| `--baudrate RATE` | 第二个参数 | 设置波特率，配合 `--connect` 使用。默认 115200 |
| — | `disconnect` / `disc` | 断开当前串口 |
| `--list` | `list` / `ls` | 列出所有可用串口设备 |

**连接示例**：

```bash
# 命令行模式 — 连接 COM3 @ 9600baud
serial-monitor-cli --connect COM3 --baudrate 9600

# 交互模式
> connect COM3 9600
> disconnect
> list
```

---

### 数据发送（三种方式）

CLI 支持三种数据发送方式，分别对应不同场景。

#### 1. 发送文本 — `--send` / `send`

发送文本字符串，**自动追加 CRLF 换行符**。适合 AT 命令、ASCII 协议。

```bash
# 单次命令 — 发送 AT 命令后退出
serial-monitor-cli --send "AT+GMR" -p COM3
# → 串口实际发送: AT+GMR\r\n

# 交互模式
> send reboot
> send AT+RESET
```

**传输过程**：文本 → UTF-8 编码 → `send_text` IPC 命令 → GUI → 串口发出原始字节

#### 2. 发送 HEX 字节 — `--send-hex` / `sendhex`

发送十六进制字节序列，**不加任何换行符**。空格分隔，不区分大小写。适合发送二进制协议报文、配置指令等。

```bash
# 单次命令 — 发送 HEX 字节后退出
serial-monitor-cli --send-hex "FF AB 03 1A 55" -p COM3
# → 串口实际发送: 0xFF 0xAB 0x03 0x1A 0x55 (5字节原始二进制)

# 不带空格也可以
serial-monitor-cli --send-hex "FFAB031A55" -p COM3

# 配合 connect 先连接再发送
serial-monitor-cli --connect COM3 --baudrate 115200 --send-hex "01 02 03 FF"
```

```bash
# 交互模式
> sendhex FF AB 03
> sendhex 1A2B3C4D
```

**传输过程**：HEX字符串 → `send_hex` IPC 命令 → GUI 解析为 QByteArray → 串口发出原始字节

#### 3. 发送二进制文件 — `--send-file` / `sendfile`

发送 `.bin` / `.hex` 等任意二进制文件到串口。常用于固件升级 (OTA/bootloader)、设备配置写入。

```bash
# 单次命令 — 发送文件后退出
serial-monitor-cli --send-file firmware.bin -p COM3

# 交互模式 — 发送后继续操作，可观察设备回复
serial-monitor-cli -p COM3 --cli
> sendfile firmware_v2.1.bin
>>> 发送文件: firmware_v2.1.bin (65536 字节)
```

**传输过程**：文件读取 → Base64编码 → `send_file` IPC 命令 → GUI Base64解码 → 串口发出原始字节

> Base64 是因为 IPC 使用 JSON 文本协议（`\n` 帧分隔），任意二进制字节会破坏 JSON 和消息边界。最终发到串口的仍是原始字节。

#### 发送方式对比

| 方式 | 命令 | 加换行 | 典型场景 | 数据流 |
|------|------|--------|----------|--------|
| 文本 | `--send` / `send` | 是 (CRLF) | AT命令、文本协议 | UTF-8编码后发送 |
| HEX | `--send-hex` / `sendhex` | 否 | 二进制报文、寄存器配置 | HEX解析为原始字节后发送 |
| 文件 | `--send-file` / `sendfile` | 否 | 固件OTA、配置写入 | Base64传输，解码后发送原始字节 |

---

### 日志监听与过滤

| 命令行 (单次) | 交互模式 | 说明 |
|---------------|----------|------|
| `-p PORT` / `--port PORT` | *(启动参数)* | 指定目标串口，实时监听日志 |
| `-f KW` / `--filter KW` | `filter <keyword>` | 过滤关键词，只显示包含该词的日志。空字符串取消过滤 |
| `-o FILE` / `--output FILE` | — | 同时保存日志到文件 |
| `--hex` | `hex` / `text` | HEX 显示模式 / 切换 |
| `--no-timestamp` | `timestamp` / `ts` | 不显示时间戳 / 切换 |
| `--json` | — | JSON 输出模式 (每行一个JSON对象) |
| `--clear` | `clear` / `c` | 启动时清空日志 / 清空日志缓冲区 |

**监听示例**：

```bash
# 持续监听 COM3 日志 (Ctrl+C 停止)
serial-monitor-cli -p COM3

# 只显示 ERROR，保存到文件
serial-monitor-cli -p COM3 -f ERROR -o error.log

# JSON 输出，方便脚本解析
serial-monitor-cli -p COM3 --json

# 交互模式 — 动态切换过滤和显示
serial-monitor-cli -p COM3 --cli
> filter ERROR        # 只看错误
> hex                 # 切换 HEX 显示
> clear               # 清空
> filter              # 取消过滤
```

---

### 查询命令

| 命令行 (单次) | 交互模式 | 说明 |
|---------------|----------|------|
| `--get-status` | `status` / `s` | 查看当前连接状态 |
| `--get-logs N` | — | 获取最近 N 条历史日志 |
| `--list` | `list` / `ls` | 列出可用串口设备 |

```bash
# 查看连接状态
serial-monitor-cli --get-status
# → [系统] 串口: COM3 | 连接: 是 | 缓冲: 1024 | RX: 12.5K | TX: 256B

# JSON 输出，适合脚本
serial-monitor-cli --get-status --json
# → {"port":"COM3","connected":true,"buffer_size":1024,"rx_bytes":12500,"tx_bytes":256}

# 获取最近 50 条日志
serial-monitor-cli --get-logs 50 --json > history.json
```

---

### 其他交互命令

| 交互命令 | 别名 | 说明 |
|----------|------|------|
| `help` | `h`, `?` | 显示帮助 |
| `quit` | `q`, `exit` | 退出 CLI (GUI 继续运行) |
| `export <file>` | | 导出所有日志为 JSON 文件 |

> **注意**：交互模式下，任何未识别的命令会被当作文本数据直接发送到串口。

---

## 输出格式

| 模式 | 格式 | 示例 |
|------|------|------|
| 默认 | `[HH:MM:SS.mmm] [LEVEL] text` | `[10:23:45.123] [INFO] Device initialized` |
| HEX | 标准 hexdump | `00000000  48 65 6C 6C 6F 0D 0A   \|Hello..\|` |
| JSON | 每行一个 JSON 对象 | `{"type":"log","port":"COM5","ts":"10:23:45.123","level":"INFO","text":"Device initialized"}` |

---

## 退出码

| 码 | 含义 | 处理建议 |
|----|------|----------|
| 0 | 正常退出 | — |
| 1 | 参数错误 | 检查命令参数 |
| 2 | GUI 服务未运行 | 提示用户启动 GUI |
| 3 | 文件操作失败 | 检查文件路径 |

---

## 典型工作流

### 1. 固件升级 (OTA / bootloader)

```bash
# Step 1: 连接设备串口，确认波特率
serial-monitor-cli --connect COM3 --baudrate 115200

# Step 2: 发送固件文件
serial-monitor-cli --send-file firmware_v2.1.bin -p COM3

# Step 3: 等待设备重启，监听启动日志
sleep 3
serial-monitor-cli -p COM3 -f "boot" --json
```

### 2. 固件烧录后验证

```bash
# Step 1: 确认串口可用
serial-monitor-cli --list

# Step 2: 连接 + 清空旧日志 + 发送重启命令
serial-monitor-cli --connect COM3 --baudrate 115200 --clear
serial-monitor-cli --send "reboot" -p COM3

# Step 3: 等待后获取日志分析
sleep 3
serial-monitor-cli --get-logs 50 --json > output.json
```

### 3. 交互式设备调试

```bash
# 进入交互模式
serial-monitor-cli -p COM3 --cli

# 在交互模式中:
> send AT+GMR           # 发送 AT 命令
> sendhex FF AB 03 1A   # 发送 HEX 字节
> sendfile firmware.bin # 发送二进制文件
> status                # 查看连接状态
> filter ERROR          # 只看错误日志
> export debug.json     # 导出所有日志
> quit                  # 退出
```

### 4. 持续监控并过滤

```bash
# 只显示含 ERROR 的日志，同时保存到文件
serial-monitor-cli -p COM3 -f ERROR -o error.log

# Ctrl+C 停止
```

### 5. 检查设备状态（脚本/AI用）

```bash
# JSON 输出，方便程序解析
serial-monitor-cli --get-status --json
```

### 6. 多串口监控

```bash
# 终端 1
serial-monitor-cli -p COM3 --cli

# 终端 2 (同时运行)
serial-monitor-cli -p COM5 --cli
```

---

## 日志级别与颜色

| 级别 | 颜色 | 典型场景 |
|------|------|----------|
| TX (发送) | 绿色 | 用户/脚本/CLI发出的数据 |
| INFO (接收) | 绿色 | 正常设备日志 |
| WARN | 黄色 | 警告信息 |
| ERROR | 红色 | 错误/异常 |
| DEBUG | 青色 | 调试信息 |
| TRACE | 灰色 | 详细跟踪 |

---

## 注意事项

- CLI 不直接操作串口，所有串口操作委托给 GUI
- CLI 断连不影响串口数据持续采集
- 多个 CLI 可同时连接到同一个 GUI
- `--cli` 交互模式必须配合 `-p PORT` 使用
- `--send` / `--send-hex` / `--send-file` 需要 `-p PORT` 指定目标串口
- HEX 数据支持空格分隔（`FF AB 03`）或无空格（`FFAB03`）
