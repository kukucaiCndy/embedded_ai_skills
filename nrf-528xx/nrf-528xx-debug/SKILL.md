---
name: "nrf-528xx-debug"
description: "nRF528xx debugging via serial/RTT log and J-Link. 系统化调试流程：环境准备→问题理解→代码研读→调试方案选择→串口日志/J-Link调试→根因分析→报告输出。Invoke when user encounters bugs, crashes, or unexpected behavior on nRF52 series chips."
---

# nRF528xx 调试技能（串口/RTT 日志 + J-Link）
> 跨平台支持：**macOS** / **Linux** / **Windows**。
> 调试手段：**串口/RTT 日志**（首选） + **J-Link 寄存器/堆栈/外设**（备选/联用）。

---

## 一、执行流程总览

```
环境准备 → 问题理解 → 代码研读 → [串口/RTT 日志 | J-Link 方式 | 二者联用] → 根因分析 → 报告输出 → 等待用户决策
```

---

## 二、第一步：环境准备

### 2.1 检查 nRF Connect SDK 环境

确保以下工具链就绪，缺失则引导用户运行 `nrf-connect-sdk-setup`：

```bash
which arm-none-eabi-gcc   # 交叉编译器
which JLinkExe            # J-Link 工具
which west                # Zephyr 构建工具
```

### 2.2 检查 J-Link 连接

```bash
JLinkExe -NoGui 0 -CommandFile /dev/null -ExitOnError 0 2>&1 | grep -E "Firmware|VTref|Serial"
```

| 结果 | 动作 |
|------|------|
| 显示 `Firmware: J-Link Vxxx` + `VTref=X.XXXV` | ✅ J-Link 正常连接 |
| `VTref=0.000V` | ❌ 目标板未供电，告知用户检查 |
| `Cannot connect to J-Link` | ❌ 告知用户检查 USB 连接 |

### 2.3 检查串口连接（如使用串口日志方案）

```bash
# macOS
ls /dev/tty.usbmodem* /dev/tty.SLAB_USBtoUART* 2>/dev/null
# Linux
ls /dev/ttyACM* /dev/ttyUSB* 2>/dev/null
```

若无串口设备但 J-Link 连接正常，可改用 **RTT（Real-Time Transfer）** 方案，通过 J-Link 获取日志。

### 2.4 确认编译产物存在

```bash
ls build/zephyr/zephyr.elf
```

---

## 三、第二步：问题理解

> **AI 必须先理解问题全貌，再动手。核心理念：先诊断，后开药。**

```
AI 向用户询问:
1. "请描述你遇到的问题现象（crash、输出异常、外设不工作等）？"
2. "问题是否稳定复现？还是偶发？"
3. "最近做了哪些代码修改？"
4. "设备当前状态：串口/RTT 是否接入？J-Link 连接是否正常？"
```

**nRF52 常见问题速查**：

| 现象 | 常见原因方向 |
|------|-------------|
| 代码不运行 / 无响应 | 时钟未初始化、bootloader 启动地址错误、SoftDevice 冲突 |
| 外设不工作 | `prj.conf` 未启用模块、设备树引脚配置错误、时钟未使能 |
| 串口无输出 | UART 模块未启用 (`CONFIG_SERIAL`, `CONFIG_UART_CONSOLE`)、引脚配置错误 |
| crash / HardFault | 空指针、栈溢出、外设未初始化即使用、中断优先级冲突 |
| 蓝牙无法广播 | SoftDevice 未启用、`CONFIG_BT` 未配置、DC/DC 调节器配置 |
| 功耗异常 | 未进入休眠、外设未关闭、GPIO 浮空 |

---

## 四、第三步：代码研读

> **AI 先阅读所有相关代码，建立完整调用链理解，再决定如何插入日志。**

### 研读范围

1. **prj.conf** — Kconfig 模块开关 (GPIO / SPI / I2C / BLE / UART 等)
2. **boards/<board>.overlay** — 设备树引脚映射
3. **src/main.c** / 应用代码 — 主循环、初始化
4. **设备树绑定文件** — 确认 compatible 字符串正确
5. **build/zephyr/.config** — 最终生效的 Kconfig 合并结果（如需要）

### 分析要点

- 哪些模块在 `prj.conf` 中启用了？是否有遗漏？
- `.overlay` 中的引脚映射是否与实际硬件一致？
- 初始化顺序是否正确（外设 init → 驱动 init → 应用逻辑）？
- DeviceTree 别名（`DT_ALIAS`）是否在 `.overlay` 中定义？
- `CONFIG_FLASH_LOAD_OFFSET` 是否正确（如有 bootloader）？
- 中断优先级是否冲突？

---

## 五、第四步：调试方案选择

```
AI 根据问题类型选择调试方案:
┌──────────────────────────────────────────────────────────────┐
│ 方案 A：串口 / RTT 日志调试（首选）                          │
│   适用：设备能正常运行，串口或 J-Link RTT 可用               │
│   优势：不暂停 CPU，适合时序敏感问题                         │
│                                                              │
│ 方案 B：J-Link 调试                                          │
│   适用：设备崩溃/死机/串口不可用                             │
│   优势：可读取崩溃瞬间的 CPU 状态、外设寄存器                 │
│                                                              │
│ 方案 C：二者联用                                             │
│   适用：复杂问题，需要日志 + 寄存器快照                      │
│   优势：双重证据交叉验证                                     │
└──────────────────────────────────────────────────────────────┘
```

> **AI 向用户报告选择的方案及理由，获得确认后继续。**

---

## 六、方案 A：串口 / RTT 日志调试

### 6.1 确认日志通道

询问用户：

- "使用什么日志输出方式？"
  - "UART 串口 (Recommended)"  — 需要指定端口号和波特率
  - "J-Link RTT" — 通过 J-Link 实时传输，不占用额外引脚

### 6.2 确保日志模块启用

```bash
# prj.conf 中必须包含：
CONFIG_PRINTK=y
CONFIG_CONSOLE=y
CONFIG_UART_CONSOLE=y        # 串口
CONFIG_SERIAL=y
CONFIG_UART_NRFX=y

# 或使用 RTT:
CONFIG_USE_SEGGER_RTT=y
CONFIG_RTT_CONSOLE=y
```

### 6.3 RTT 日志监听（如使用 RTT）

```bash
# 连接目标并启动 RTT Client
JLinkRTTClient -device nRF52840_xxAA -if SWD -speed 4000
```

### 6.4 串口日志监听（如使用串口）

询问用户串口设备名和波特率，然后启动监听：

```bash
# macOS
screen /dev/tty.usbmodem* 115200
# Linux
minicom -D /dev/ttyACM0 -b 115200
```

### 6.5 添加诊断日志

> **AI 根据代码研读结果，在关键位置添加日志。日志格式要求：**

```c
printk("[DEBUG] [标签] 变量名 = %d\n", value);
// LOG_DBG("[标签] 变量名 = %d", value);  // 也可以使用 Zephyr logging
```

**日志插入原则：**

| 位置 | 日志内容 |
|------|---------|
| 函数入口 | 函数名 + 关键参数值 |
| 函数出口 | 返回值 |
| 状态变化 | 旧值 → 新值 |
| 错误分支 | 错误码 + 上下文变量 |
| 回调/ISR | 函数名 + 关键外设状态寄存器 |
| 关键循环 | 循环计数 + 关键变量 |

> ⚠️ **日志必须短小精悍。** ISR 中尤其不能打印过多字符，可用一个计数变量事后打印。使用 `printk` 而非 `printf`（更轻量）。

### 6.6 编译 + 烧录

```bash
west build -b <board> . --pristine
# 有 bootloader 时用 JLinkExe loadbin 偏移烧录
# 无 bootloader 时 west flash
```

### 6.7 分析日志

1. 过滤出烧录时间戳之后的日志行
2. 根据日志中的标签和变量值，还原程序执行路径
3. 对比预期行为与实际行为，定位偏差点
4. 从偏差点向前追溯调用链，寻找根因

---

## 七、方案 B：J-Link 调试

### 7.1 触发条件

```
当以下情况时使用 J-Link 调试:
- 设备启动后立即 crash，无日志输出
- 设备运行一段时间后死机
- HardFault / MemManage / BusFault
- 需要检查外设寄存器状态
- 需要验证 flash 内容（bootloader 是否被意外覆盖）
```

### 7.2 读取 CPU 寄存器

```bash
cat > /tmp/dump_regs.jlink << 'EOF'
device <CHIP_MODEL>
if SWD
speed 4000
connect
regs
exit
EOF
JLinkExe -NoGui 1 -CommandFile /tmp/dump_regs.jlink 2>&1
```

### 7.3 解析调用栈

**根据 `PC`、`LR`、`SP` 重建调用链：**

```bash
# 将 PC / LR 地址反汇编，定位到具体函数
arm-none-eabi-objdump -d build/zephyr/zephyr.elf | grep -B2 -A10 "<PC_VALUE>"

# 查看符号表确认函数名
arm-none-eabi-nm build/zephyr/zephyr.elf | sort | grep <ADDRESS>

# 从 SP 处 dump 栈内容
# 先在 JLinkExe 中: savebin /tmp/stack_dump.bin <SP_ADDRESS> 1024
xxd /tmp/stack_dump.bin | head -40
```

### 7.4 读取 nRF52 外设寄存器

nRF52840 关键外设基址：

```
GPIO0:        0x50000000
GPIO1:        0x50000300
UARTE0:       0x40002000
SPIM0:        0x40003000
TWIM0:        0x40003000 (I2C)
CLOCK:        0x40000000
POWER:        0x40000000
RADIO (BLE):  0x40001000
NVMC:         0x4001E000
UICR:         0x10001000
FICR:         0x10000000 (只读信息页)
NVIC:         0xE000E100
SCB:          0xE000ED00
```

```bash
# 读取 GPIO0 方向寄存器
JLinkExe -NoGui 1 -device <CHIP> -if SWD -speed 4000 -autoconnect 1 \
  -CommanderScript /dev/stdin <<< "mem32 0x50000514 1\nexit" | grep "50000514"

# 读取 GPIO0 输出寄存器
JLinkExe ... <<< "mem32 0x50000504 1\nexit"

# 读取复位原因 (POWER.RESETREAS)
JLinkExe ... <<< "mem32 0x40000400 1\nexit"
# 0: 引脚复位, 1: 看门狗, 2: 软复位, 4: CPU lockup

# 批量 dump 关键外设
for addr in 0x40000400 0x50000514 0x50000504; do
  JLinkExe ... <<< "mem32 $addr 1\nexit" | grep "$addr"
done
```

### 7.5 读取 Flash 内容

```bash
# Dump 指定区域（验证烧录是否正确）
cat > /tmp/dump_flash.jlink << 'EOF'
device <CHIP_MODEL>
if SWD
speed 4000
connect
savebin /tmp/flash_dump.bin <START_ADDR> <SIZE>
exit
EOF
JLinkExe -NoGui 1 -CommandFile /tmp/dump_flash.jlink
xxd /tmp/flash_dump.bin | head -20
```

### 7.6 结合源码分析

1. 将 `PC` 所在函数作为出发点
2. 检查 `LR` 确认调用来源
3. 遍历栈内存寻找更多返回地址，重建完整调用链
4. 检查复位原因寄存器排除意外 Reset
5. 结合源码检查：参数是否正确传递？初始化是否正确？

---

## 八、方案 C：日志 + J-Link 联用

```
串口/RTT 日志发现问题 → J-Link 暂停确认状态 → 交叉验证

具体步骤:
1. 先通过日志观察异常出现的时机和模式
2. 在异常出现前后通过 J-Link halt 获取 CPU 快照
3. 对比日志记录值和寄存器/内存实际值
4. 双源交叉验证，排除单源误导
```

---

## 九、根因分析

> **AI 必须深入分析，不能停留在表象。**

### 核心分析原则

```
⚠️ crash 点 ≠ 根因

crash 发生在 Zephyr 内核、驱动层（如 k_sleep、gpio_pin_set、bt_enable），
这往往是问题的最终表现，而不是根因。

真正的根因通常在用户代码侧:
  - 调用参数不正确（NULL 指针、越界索引）
  - 调用时序错误（设备未初始化 / 未 ready 即使用）
  - prj.conf 配置遗漏（CONFIG_xxx 未启用）
  - 设备树错误（.overlay 引脚号写错、aliases 缺失）
  - 栈溢出（线程栈配置过小）
  - 中断优先级冲突
  - 时钟/电源配置错误
  - 内存对齐问题
```

### zephyr/nRF52 分析检查清单

| 检查项 | 排查方法 |
|--------|---------|
| 模块是否在 prj.conf 启用 | `grep CONFIG_ build/zephyr/.config` |
| 设备树 aliases 是否定义 | `grep -A5 aliases build/zephyr/zephyr.dts` |
| GPIO 引脚是否正确 | 对照原理图确认 Px.yy → GPIO_x + pin yy |
| device_is_ready() 检查 | 所有外设使用前调用 `device_is_ready()` |
| 线程栈大小是否足够 | `CONFIG_MAIN_STACK_SIZE`、`CONFIG_BT_RX_STACK_SIZE` 等 |
| 中断优先级 | `CONFIG_BT_CTLR_RX_PRIO` 等蓝牙相关优先级 |
| CONFIG_FLASH_LOAD_OFFSET | 确认与 bootloader 占用范围匹配 |
| NFC 引脚是否释放 | `CONFIG_NFCT_PINS_AS_GPIOS=y` |
| REG0/REG1 电源配置 | `CONFIG_SOC_DCDC_NRF52X` 等 DC/DC 配置 |
| 蓝牙 SoftDevice 是否初始化 | `bt_enable()` 调用顺序和返回值检查 |
| 外设时钟 | Zephyr 自动管理，一般不需要手动配置 |
| RAM 布局是否冲突 | 蓝牙 SoftDevice 占用低地址 RAM |

---

## 十、报告输出

```markdown
## 问题分析报告

### 1. 问题现象
- [用户描述的原始问题]

### 2. 调试方案
- 采用方案：[A / B / C]
- 理由：[说明为什么选择该方案]

### 3. 代码研读
- 相关文件：[列出文件路径]
- 关键函数调用链：[从 main → 问题点]
- prj.conf 关键配置：[列出启用的模块]
- .overlay 引脚映射：[列出涉及的引脚]

### 4. 调试数据

#### 日志分析（方案 A）
[粘贴关键日志，标注行号和异常点]

#### 寄存器快照（方案 B）
| 寄存器 | 值 | 解析 |
|--------|-----|------|
| PC | 0x... | 当前停在 xxx 函数 |
| LR | 0x... | 由 xxx 调用 |
| SP | 0x... | 栈使用量约 N KB |
| POWER.RESETREAS | 0x... | 复位原因: xxx |

### 5. 根因分析
- **直接原因**：[导致 crash/异常的代码行或条件]
- **根本原因**：[为什么出现了这个直接原因]
- **证据链**：[日志数据 + 寄存器 + 源码 → 结论]

### 6. 解决方案
- 方案 1: [修改 xxx，因为 yyy]
- 方案 2: [备选方案]
- 推荐：[方案 X，理由]

请确认是否按推荐方案执行修改？
```

---

## 十一、等待用户决策

```
AI 输出报告后，等待用户指示:
- "按方案 X 修改代码"   → AI 执行修改、编译、烧录、验证
- "补充 xxx 信息"        → AI 按照用户要求补充调试
- "自己手动修改"          → AI 结束调试，由用户操作
- "不是这个问题"          → AI 重新分析
```

---

## 十二、调试命令速查

### J-Link 命令（JLinkExe）

```bash
# 设备连接测试
JLinkExe -NoGui 0 -CommandFile /dev/null -ExitOnError 0

# 读取内存 (mem32 一次读 4 字节)
cat > /tmp/cmd.jlink << 'EOF'
device <CHIP_MODEL>
if SWD
speed 4000
connect
mem32 <ADDR> <COUNT>
exit
EOF
JLinkExe -NoGui 1 -CommandFile /tmp/cmd.jlink

# 读取 CPU 寄存器
# 在 jlink 脚本中使用: regs

# 保存 Flash/RAM 到文件
# 在 jlink 脚本中使用: savebin <filename> <addr> <bytes>

# Flash 烧录
# 在 jlink 脚本中使用: loadbin <filename> <addr>
# 或: loadfile <filename.hex>
# 擦除: erase <start> <end>
# 复位: r
# 运行: g
```

### 反汇编/符号表

```bash
# 符号表
arm-none-eabi-nm build/zephyr/zephyr.elf | sort

# 反汇编指定地址
arm-none-eabi-objdump -d build/zephyr/zephyr.elf | grep -B2 -A10 "<0xADDR>"

# 完整反汇编输出
arm-none-eabi-objdump -d build/zephyr/zephyr.elf > disasm.txt

# 查看段信息
arm-none-eabi-size build/zephyr/zephyr.elf

# 查看 section headers
arm-none-eabi-objdump -h build/zephyr/zephyr.elf
```

### Zephyr 构建分析

```bash
# 查看最终 Kconfig 配置
grep "CONFIG_.*=y" build/zephyr/.config

# 查看最终设备树
cat build/zephyr/zephyr.dts

# menuconfig 图形配置
west build -t menuconfig

# 查看内存布局
west build -t ram_report
west build -t rom_report
```

### 十六进制查看

```bash
xxd <file>                 # 标准格式
xxd <file> | head -20      # 前 20 行
hexdump -C <file> | head   # 另一种格式
```
