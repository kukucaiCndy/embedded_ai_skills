---
name: "stm32-debug"
description: "STM32 debugging via serial log and ST-Link. Invoke when user encounters bugs, crashes, or unexpected behavior on STM32 and needs root cause analysis."
---

# STM32 调试技能（串口日志 + ST-Link）

> 跨平台支持：**Windows** / **macOS** / **Linux**。
> 调试手段：**串口日志**（首选） + **ST-Link 寄存器/堆栈**（备选/联用）。

---

## 一、执行流程总览

```
环境准备 → 问题理解 → 代码研读 → [串口日志方式 | ST-Link 方式 | 二者联用] → 根因分析 → 报告输出 → 等待用户决策
```

---

## 二、第一步：环境准备

### 2.1 安装 stm32-dev Skill

> **AI 首次执行本 Skill 时，必须先检查 stm32-dev skill 是否已存在。**

```bash
# 检测 stm32-dev 是否已安装
ls .trae/skills/stm32-dev/SKILL.md 2>/dev/null && echo "INSTALLED" || echo "NOT_INSTALLED"
```

**如果未安装：**

```
AI 执行:
git clone https://github.com/kukucaiCndy/embedded_ai_skills.git /tmp/embedded_ai_skills
cp -r /tmp/embedded_ai_skills/stm32_dev/* .trae/skills/stm32-dev/
```

> stm32-dev skill 提供完整的工具链安装、工程编译、烧录流程。本 Skill 的编译/烧录步骤均复用 stm32-dev 的能力。

### 2.2 检查 ST-Link 连接

```bash
# 探测 ST-Link 并读取芯片信息
export PATH="/mingw64/bin:$PATH"
st-info --probe
```

| 结果 | 动作 |
|------|------|
| `Found 1 stlink programmers` + 芯片信息 | ✅ 继续 |
| `Couldn't find any ST-Link` | ❌ 告知用户检查连接 |

**验证 ST-Link 可读写芯片：**

```bash
openocd -f interface/stlink.cfg -f target/stm32f1x.cfg \
    -c "init" -c "halt" -c "reg" -c "resume" -c "shutdown" 2>&1
```

> 如能正常输出 `r0`~`r15`、`pc`、`msp`、`psp`、`xPSR` 等寄存器，说明 ST-Link 调试通道正常。

### 2.3 安装串口调试工具

**下载地址：** `https://github.com/kukucaiCndy/serial-monitor/releases`

| 平台 | 安装方式 |
|------|---------|
| **Windows** | 从 Releases 页面下载最新 `.exe`，直接运行即可，无需安装 |
| **macOS** | 需自行下载源码编译：`git clone` → 按 README 编译 |
| **Linux** | 需自行下载源码编译：`git clone` → 按 README 编译 |

**Windows 自动安装：**

```bash
# AI 自动获取最新 release 下载地址并下载
LATEST_URL=$(curl -s https://api.github.com/repos/kukucaiCndy/serial-monitor/releases/latest | grep "browser_download_url.*\.exe" | cut -d '"' -f 4)
curl -L -o ~/stm32-tools/serial-monitor.exe "$LATEST_URL"
```

**macOS / Linux 源码编译：**

```bash
git clone https://github.com/kukucaiCndy/serial-monitor.git ~/stm32-tools/serial-monitor-src
# 进入目录后按项目 README 中的编译说明操作
```

### 2.4 学习串口工具 CLI 命令

> **AI 在使用串口工具前，必须先掌握其命令行参数。**

```
AI 学习流程:
1. 下载工具后，先执行 --help 获取完整参数列表

   Windows:
   ~/stm32-tools/serial-monitor.exe --help

   macOS / Linux:
   cd ~/stm32-tools/serial-monitor-src
   python serial_monitor.py --help

2. 根据 --help 输出，AI 记录以下关键参数（如存在）:
   --port       串口设备路径 (Windows: COM3, Linux: /dev/ttyUSB0)
   --baudrate   波特率 (常用: 115200, 921600)
   --log-file   日志输出文件路径
   --timeout    读取超时时间
   --filter     日志过滤规则

3. 如果 --help 输出不够详细或参数有差异，AI 阅读项目 README 或源码顶部的 argparse 定义补充

4. AI 根据实际支持的参数组合出正确的启动命令
```

> **⚠️ 不要假设参数名。** 必须通过 `--help` 或源码确认后再使用。

---

## 三、第二步：问题理解

> **AI 必须先理解问题全貌，再动手。核心理念：先诊断，后开药。**

```
AI 向用户询问:
1. "请描述你遇到的问题现象（crash、输出异常、外设不工作等）？"
2. "问题是否稳定复现？还是偶发？"
3. "最近做了哪些代码修改？"
4. "设备当前状态：串口是否接入？硬件连接是否正常？"
```

---

## 四、第三步：代码研读

> **AI 先阅读所有相关代码，建立完整调用链理解，再决定如何插入日志。**

### 研读范围

1. **用户应用代码** — `code/src/main.c` 及主循环
2. **中断服务例程** — `SysTick_Handler`、各外设 ISR
3. **HAL 回调** — `HAL_UART_MspInit`、`HAL_GPIO_EXTI_Callback` 等
4. **初始化代码** — `SystemClock_Config`、各 `MX_xxx_Init`

### 分析要点

- 哪些变量的值变化可能导致问题？
- 哪些函数调用路径可能出问题？
- 调用时序是否正确（先初始化 A 再初始化 B）？
- 参数传递是否正确（指针、长度、缓冲区大小）？
- 中断优先级是否冲突？

---

## 五、第四步：调试方案选择

```
AI 根据问题类型选择调试方案:

┌──────────────────────────────────────────────────────────────┐
│ 方案 A：串口日志调试（首选）                                │
│   适用：设备能正常运行，串口可用                            │
│   优势：不暂停 CPU，适合时序敏感问题                        │
│                                                             │
│ 方案 B：ST-Link 调试                                        │
│   适用：设备崩溃/死机/串口不可用                            │
│   优势：可读取崩溃瞬间的 CPU 状态                           │
│                                                             │
│ 方案 C：二者联用                                            │
│   适用：复杂问题，需要日志 + 寄存器快照                     │
│   优势：双重证据交叉验证                                    │
└──────────────────────────────────────────────────────────────┘
```

> **AI 向用户报告选择的方案及理由，获得确认后继续。**

---

## 六、方案 A：串口日志调试

### 6.1 配置串口工具

```
AI 询问用户:
"请确认串口信息：COM 口号？（如 COM3）波特率？（如 115200）"
```

**配置并启动监听：**

```bash
# Windows：直接运行下载的 exe
~/stm32-tools/serial-monitor.exe --port COM3 --baudrate 115200 --log-file /tmp/serial_debug.log &

# macOS / Linux：运行编译后的脚本
cd ~/stm32-tools/serial-monitor-src
python serial_monitor.py --port /dev/ttyUSB0 --baudrate 115200 --log-file /tmp/serial_debug.log &
```

> **⚠️ 实际参数名以 `--help` 输出为准。** 上述命令为示例格式，AI 需先执行 2.4 节的学习流程确认实际参数后再组装命令。

### 6.2 添加诊断日志

> **AI 根据代码研读结果，在关键位置添加日志。日志格式要求：**

```c
printf("[DEBUG] [标签] 变量名 = 值\r\n");
// 例如:
printf("[DEBUG] [UART_TX] tx_count = %lu, tx_state = %d\r\n", tx_count, huart1.gState);
```

**日志插入原则：**

| 位置 | 日志内容 |
|------|---------|
| 函数入口 | 函数名 + 关键参数值 |
| 函数出口 | 返回值 |
| 状态变化 | 旧值 → 新值 |
| 错误分支 | 错误码 + 上下文变量 |
| ISR 入口 | ISR 名 + 关键外设状态寄存器 |
| 关键循环 | 循环计数 + 关键变量 |

> **⚠️ 日志必须短小精悍。** 在 ISR 中尤其不能打印过多字符，会影响时序。

### 6.3 编译 + 烧录 + 记录时间戳

```bash
# 记录烧录时间戳
echo "FLASH TIMESTAMP: $(date -Iseconds)" >> /tmp/serial_debug.log

# 编译 + 转换 + 烧录
export PATH="/mingw64/bin:$PATH"
cmake --build build
arm-none-eabi-objcopy -O binary build/${PROJECT_NAME}.elf build/${PROJECT_NAME}.bin
st-flash --reset write build/${PROJECT_NAME}.bin 0x08000000
```

### 6.4 分析日志

> **复位设备后，串口工具持续监听。AI 分析烧录时间戳之后的日志：**

1. 过滤出时间戳之后的日志行
2. 根据日志中的标签和变量值，还原程序执行路径
3. 对比预期行为与实际行为，定位偏差点
4. 从偏差点向前追溯调用链，寻找根因

---

## 七、方案 B：ST-Link 调试

### 7.1 触发条件

```
当以下情况时使用 ST-Link 调试:
- 设备启动后立即 crash，串口无输出
- 设备运行一段时间后死机，串口停止输出
- HardFault 等内核异常
- 需要检查外设寄存器状态
```

### 7.2 读取 CPU 寄存器

```bash
export PATH="/mingw64/bin:$PATH"
openocd -f interface/stlink.cfg -f target/stm32f1x.cfg \
    -c "init" -c "halt" -c "reg" -c "resume" -c "shutdown" 2>&1
```

### 7.3 解析调用栈

**根据 `PC`、`LR`、`MSP` 重建调用链：**

```bash
# 将 PC/LR 地址反汇编，定位到具体函数
arm-none-eabi-objdump -d build/${PROJECT_NAME}.elf | grep -A5 "<PC_VALUE>"

# 查看符号表确认函数名
arm-none-eabi-nm build/${PROJECT_NAME}.elf | sort | grep <ADDRESS>

# 从 MSP 处 dump 栈内容
st-flash read /tmp/stack_dump.bin <MSP_ADDRESS> 1024
xxd /tmp/stack_dump.bin
```

### 7.4 读取外设寄存器

```bash
# 读取 GPIO 寄存器
st-flash read /tmp/gpioc_regs.bin 0x40011000 16
xxd /tmp/gpioc_regs.bin

# 读取 RCC 寄存器
st-flash read /tmp/rcc_regs.bin 0x40021000 64
xxd /tmp/rcc_regs.bin

# 读取 NVIC 寄存器
st-flash read /tmp/nvic_regs.bin 0xE000E100 256
xxd /tmp/nvic_regs.bin
```

> 外设寄存器基址参考芯片参考手册。常见 F103 寄存器：
> ```
> RCC:   0x40021000
> GPIOA: 0x40010800  GPIOB: 0x40010C00  GPIOC: 0x40011000
> USART1:0x40013800
> NVIC:  0xE000E100
> SCB:   0xE000ED00
> ```

### 7.5 结合源码分析

1. 将 `PC` 所在函数作为出发点
2. 检查 `LR` 确认调用来源
3. 遍历栈内存寻找更多返回地址，重建完整调用链
4. 结合源码检查：参数是否正确传递？初始化是否正确？中断是否冲突？

---

## 八、方案 C：串口 + ST-Link 联用

```
串口日志发现问题 → ST-Link 暂停确认状态 → 交叉验证

具体步骤:
1. 先通过串口日志观察异常出现的时间点和模式
2. 在异常出现前后通过 ST-Link halt 获取 CPU 快照
3. 对比日志记录值和寄存器/内存实际值
4. 双源交叉验证，排除单源误导
```

---

## 九、根因分析

> **AI 必须深入分析，不能停留在表象。**

### 核心分析原则

```
⚠️ crash 点 ≠ 根因

crash 发生在核心库/内核/驱动（如 HAL_Delay、SysTick_Handler、HardFault_Handler），
这往往是问题的最终表现，而不是根因。

真正的根因通常在用户代码侧:
  - 对核心库的调用参数不正确
  - 调用时序错误（如外设未初始化即使用）
  - 配置遗漏（如缺少 __HAL_RCC_xxx_CLK_ENABLE）
  - 缓冲区溢出（栈/堆越界破坏关键数据）
  - 中断嵌套/优先级问题
  - 超时设置不合理
```

### 分析检查清单

| 检查项 | 排查方法 |
|--------|---------|
| 外设时钟是否使能 | 查 `HAL_MspInit` / `MX_xxx_Init` 中 `__HAL_RCC_xxx_CLK_ENABLE()` |
| GPIO 引脚配置是否正确 | 查 `Mode`、`Pull`、`Alternate` 配置 |
| hal_conf.h 模块是否启用 | 查对应 `#define HAL_xxx_MODULE_ENABLED` 是否去注释 |
| CMakeLists 是否链接 HAL 模块 | 查 `target_link_libraries` 中 `HAL::STM32::{F}::xxx` |
| ISR 是否存在 / 命名正确 | 查 ISR 函数名匹配启动文件中的向量表名 |
| SysTick 是否正确配置 | `SysTick_Handler` 中调用 `HAL_IncTick()` |
| 缓冲区大小是否足够 | `snprintf` / `HAL_UART_Transmit` 的 buffer 大小 |
| 栈是否溢出 | 检查 MSP 是否接近 SRAM 底部 |
| DMA 是否启用（UART/SPI 依赖） | hal_conf.h 启用 + CMakeLists 链接 |
| 外设初始化在 SystemClock_Config 之后 | 确保 `MX_xxx_Init` 在 `SystemClock_Config()` 之后调用 |

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
- 关键函数调用链：[从 main → 问题点列出]

### 4. 调试数据

#### 串口日志（方案 A）
[粘贴关键日志片段并标注行号]
[标注异常数据点]

#### 寄存器快照（方案 B）
| 寄存器 | 值 | 解析 |
|--------|-----|------|
| PC | 0x... | 当前停在 xxx 函数 |
| LR | 0x... | 由 xxx 调用 |
| MSP | 0x... | 栈使用量约 N KB |

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
- "补充 xxx 信息"       → AI 按照用户要求补充调试
- "自己手动修改"         → AI 结束调试，由用户操作
- "不是这个问题"         → AI 重新分析
```

---

## 十二、调试命令速查

### ST-Link 命令

```bash
# 设备探测
st-info --probe

# 读取内存（Flash/SRAM/外设寄存器）
st-flash read <output.bin> <address> <size>

# CPU 寄存器 dump（需 halt）
openocd -f interface/stlink.cfg -f target/stm32f1x.cfg \
    -c "init" -c "halt" -c "reg" -c "resume" -c "shutdown"

# 完整 SRAM dump
openocd -f interface/stlink.cfg -f target/stm32f1x.cfg \
    -c "init" -c "dump_image <output.bin> 0x20000000 <size>" -c "shutdown"
```

### 串口监听工具

```bash
# 启动监听（参数以 --help 输出为准）
~/stm32-tools/serial-monitor.exe --port COM3 --baudrate 115200 --log-file /tmp/serial_debug.log
```

### 反汇编/符号表

```bash
export PATH="/mingw64/bin:$PATH"

# 符号表查看
arm-none-eabi-nm build/<project>.elf | sort

# 反汇编指定地址
arm-none-eabi-objdump -d build/<project>.elf | grep -A10 "<address>"

# 反汇编全部
arm-none-eabi-objdump -d build/<project>.elf > disasm.txt
```

### 十六进制查看

```bash
xxd <file>             # 标准格式
xxd <file> | head -20  # 只看前 20 行
```
