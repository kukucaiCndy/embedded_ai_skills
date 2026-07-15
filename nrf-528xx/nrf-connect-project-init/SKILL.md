---
name: "nrf-connect-project-init"
description: "Initialize a new nRF528xx development project. 自动侦测芯片型号，与用户交互确认硬件资源（GPIO/SPI/I2C/UART），选择编程语言，搭建 CMake 项目框架，完成编译烧录验证。Call after nrf-connect-sdk-setup is complete and the user wants to start a new project."
---

# nRF528xx 项目初始化

引导用户通过人机交互方式完成新项目的创建、配置、编译和烧录。

---

## Step 1: 确保开发环境到位

> **⚠️ 不能仅用 `which` 检查**。west/JLinkExe 可能已安装但不在 PATH 中。必须复用 `nrf-connect-sdk-setup` 的检测脚本。

### 1.1 检查交叉编译器

```bash
which arm-none-eabi-gcc && arm-none-eabi-gcc --version | head -1
```

若缺失 → 提示用户先运行 `nrf-connect-sdk-setup` skill。

### 1.2 检查 JLinkExe（含非标准路径检测）

```bash
JLINK_PATH=""
candidates="$(
  which JLinkExe 2>/dev/null
  echo "/Applications/SEGGER/JLink/JLinkExe"
  find /Applications/SEGGER -name 'JLinkExe' -maxdepth 3 2>/dev/null
  echo "/opt/homebrew/bin/JLinkExe"
  echo "/usr/local/bin/JLinkExe"
  find "$HOME/tools" -name 'JLinkExe' -maxdepth 5 2>/dev/null
  find "$HOME/.local" -name 'JLinkExe' -maxdepth 5 2>/dev/null
)"
while IFS= read -r p; do
  if [ -n "$p" ] && [ -x "$p" ]; then JLINK_PATH="$p"; break; fi
done <<< "$candidates"
echo "JLinkExe: ${JLINK_PATH:-NOT_FOUND}"
```

若缺失 → 提示用户先安装 J-Link 驱动。**若找到但不在 PATH，记录路径供烧录使用。**

### 1.3 检查 west（含非标准路径检测）

```bash
WEST_BIN=""
for p in "$(which west 2>/dev/null)" \
         "$HOME/Library/Python/3.9/bin/west" \
         "$HOME/Library/Python/3.10/bin/west" \
         "$HOME/Library/Python/3.11/bin/west" \
         "$HOME/.local/bin/west"; do
  if [ -n "$p" ] && [ -x "$p" ]; then WEST_BIN="$p"; break; fi
done
echo "west: ${WEST_BIN:-NOT_FOUND}"
```

若缺失 → 提示先运行 `nrf-connect-sdk-setup`。**记录 WEST_BIN 路径，后续所有 west 命令需确保 PATH 包含其目录。**

### 1.4 检查 NCS workspace

```bash
test -d "$HOME/ncs/.west" && echo "NCS: $HOME/ncs" || echo "NCS: NOT_FOUND"
```

### 1.5 记录环境变量

后续所有 `west build` / `west flash` 命令前必须设置：
```bash
export PATH="<WEST_BIN_DIR>:<JLINK_BIN_DIR>:$PATH"
source "$HOME/ncs/zephyr/zephyr-env.sh"
```

---

## Step 2: 侦测芯片型号

通过 `AskUserQuestion` 工具与用户交互：

### 2.1 自动侦测芯片型号

引导用户将 J-Link 连接芯片并供电（VTref > 3.0V），然后运行：

```bash
JLinkExe -NoGui 1 -device nRF52840_xxAA -if SWD -speed 4000 -autoconnect 1 -CommanderScript /dev/stdin <<< "connect\nexit" 2>&1 | grep -E "CPUID|Device|Found"
```

如果连接成功，从 `CPUID register` 读取芯片信息：
- `0x410FC241` → nRF52840 (Cortex-M4)
- `0x412FC231` → nRF52832 (Cortex-M4)
- `0x411FC231` → nRF52810 (Cortex-M4)

> Zephyr board 名称对应：  
> `nrf52840dk_nrf52840`, `nrf52832dk_nrf52832`, `nrf52810dk_nrf52810` 等

### 2.2 手动指定（自动侦测失败时）

通过 `AskUserQuestion` 让用户选择芯片型号:
- "nRF52840 (Recommended)"
- "nRF52832"
- "nRF52810"
- "nRF52833"
- "nRF52820"
- "nRF52811"
- "nRF52805"
- "Other (请在 Other 中填写完整型号)"

---

## Step 3: 确认开发内容与硬件资源

通过 `AskUserQuestion` 与用户逐项确认：

### 3.1 编程语言

- "C (Recommended)" 
- "C++"

### 3.2 需要的功能模块（多选）

- "GPIO (LED/按键)"
- "UART/串口 (调试输出)"
- "SPI (显示屏/传感器)"
- "I2C (传感器)"
- "PWM"
- "ADC"
- "BLE (蓝牙低功耗)"
- "USB"
- "其他（请在 Other 中补充）"

### 3.3 硬件资源详情

引导用户填写每个模块的具体引脚和配置。例如：
- GPIO: "LED 连接到 P0.15，低电平点亮"
- UART: "TX=P0.06, RX=P0.08, 波特率 115200"
- SPI: "SCK=P0.27, MOSI=P0.26, MISO=P0.29, CS=P0.28"
- I2C: "SDA=P0.17, SCL=P0.20"

通过多次 `AskUserQuestion` 收集完整硬件配置。

---

## Step 4: 确认项目基本信息

- **项目名称**: 用户输入（默认: `nrf52_project`）
- **项目路径**: 用户指定（默认: `$HOME/projects/<项目名>`）
- **目标板**: 从 Step 2 确定的 Zephyr board 名称

---

## Step 5: 确认 bootloader 布局

通过 `AskUserQuestion` 询问用户：
- "开发板有无 bootloader？"
  - "无 bootloader，APP 从 0x0 开始 (Recommend)"
  - "有 UF2 bootloader（如 Nice!Nano），APP 从 0x26000 开始"
  - "自定义偏移（请填写 0x 地址）"

> **⚠️ 烧录偏移的影响**：
> - `CONFIG_FLASH_LOAD_OFFSET=0x26000` 只影响 hex/bin 文件的加载地址
> - 使用 `west flash` 或 `JLinkExe loadfile` 烧录 `merged.hex` 时，hex 文件内含地址信息，会自动烧录到正确偏移
> - 无需手动 `erase` 或 `loadbin` 指定偏移地址

---

## Step 6: 检查目标板卡的设备树定义（⚠️ 必须执行）

> **⚠️ 在生成 overlay 前，必须先读取目标板卡的 DTS 文件**，了解已有引脚定义，避免：
> 1. 创建冗余的 LED/按键节点（板卡已有）
> 2. 使用已废弃的 devicetree 语法（如 `tx-pin`，Zephyr 3.5+ 需用 pinctrl）

```bash
# 查找板卡 DTS 文件
find $NCS_DIR/zephyr/boards -path "*<board_name>*" -name "*.dts" | head -3
# 读取主 DTS 和 pinctrl dtsi
```

**检查要点：**
1. LED 节点：板卡已定义哪些 LED？引脚号？active-high/low？
2. 按键节点：板卡已定义哪些按键？
3. UART 引脚：是否已通过 pinctrl 配置？引脚是否匹配用户需求？
4. SPI/I2C 引脚：同上

**overlay 生成原则：**
- 如果板卡已有匹配的 LED/按键节点 → 仅修改 `aliases` 指向，不新建节点
- 如果引脚不匹配 → 在 overlay 中用 pinctrl 方式覆盖（参考板卡的 `-pinctrl.dtsi` 语法）
- **绝对不要使用 `tx-pin`/`rx-pin` 等旧语法**，必须用 `pinctrl-0`/`pinctrl-names`

---

## Step 7: 生成项目框架

在确认的目标路径创建 CMake 项目：

### 项目目录结构

```
<project>/
├── CMakeLists.txt        # 顶层 CMake
├── prj.conf              # Zephyr Kconfig 配置
├── boards/
│   └── <board>.overlay   # 设备树 overlay（引脚映射）
└── src/
    └── main.c / main.cpp # 应用入口
```

### CMakeLists.txt 模板

```cmake
cmake_minimum_required(VERSION 3.20)
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(<project_name>)

target_sources(app PRIVATE src/main.c)
```

### prj.conf 模板

```ini
# GPIO
CONFIG_GPIO=y

# UART / 串口控制台
CONFIG_SERIAL=y
CONFIG_CONSOLE=y
CONFIG_UART_CONSOLE=y

# 打印输出
CONFIG_PRINTK=y

# Bootloader 偏移（如有 UF2 bootloader）
# CONFIG_FLASH_LOAD_OFFSET=0x26000
```

### src/main.c 模板 (C，含 UART 输出)

```c
#include <zephyr/kernel.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/sys/printk.h>

/* LED 引脚 - 根据 Step 6 检查结果填充 */
#define LED_NODE DT_ALIAS(led0)
static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED_NODE, gpios);

int main(void)
{
    if (!device_is_ready(led.port)) {
        printk("LED device not ready\n");
        return -1;
    }

    gpio_pin_configure_dt(&led, GPIO_OUTPUT_ACTIVE);

    printk("<project_name> started\n");

    while (1) {
        gpio_pin_toggle_dt(&led);
        printk("tick\n");
        k_msleep(1000);
    }

    return 0;
}
```

### boards/<board>.overlay 生成规则（⚠️ 根据 Step 6 检查结果选择）

#### 情况 A：板卡已有匹配的 LED 节点（推荐，如 nrf52840dk）

仅修改 alias 指向已有节点，不新建节点：

```dts
/ {
    aliases {
        /* 将 led0 指向板卡已有的 LED 节点（如 led2 = P0.15） */
        led0 = &led2;
    };
};
```

#### 情况 B：板卡没有用户所需的 LED 引脚

新建 LED 节点：

```dts
/ {
    aliases {
        led0 = &user_led;
    };

    user_led: led {
        compatible = "gpio-leds";
        user_led_0: led_0 {
            gpios = <&gpio0 15 GPIO_ACTIVE_LOW>;
            label = "User LED";
        };
    };
};
```

#### 情况 C：需要修改 UART 引脚（⚠️ 必须用 pinctrl，不能用 tx-pin）

> **Zephyr 3.5+ 已废弃 `tx-pin`/`rx-pin` 属性，必须使用 pinctrl 方式。**

```dts
&pinctrl {
    uart0_custom: uart0_custom {
        group1 {
            psels = <NRF_PSEL(UART_TX, 0, 6)>;
        };
        group2 {
            psels = <NRF_PSEL(UART_RX, 0, 8)>;
            bias-pull-up;
        };
    };
};

&uart0 {
    status = "okay";
    current-speed = <115200>;
    pinctrl-0 = <&uart0_custom>;
    pinctrl-1 = <&uart0_sleep>;
    pinctrl-names = "default", "sleep";
};
```

> **参考板卡的 `-pinctrl.dtsi` 文件了解正确的 pinctrl 语法。**

---

## Step 8: 编译项目

> **⚠️ 编译前必须设置环境变量**：

```bash
export PATH="<WEST_BIN_DIR>:<JLINK_BIN_DIR>:$PATH"
source "$HOME/ncs/zephyr/zephyr-env.sh"
```

```bash
cd <project_path>
west build -b <board_name> . --pristine
```

### 编译失败常见问题

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| `'tx-pin' appears in ... but is not declared in 'properties:'` | Zephyr 3.5+ 废弃旧 UART 语法 | 改用 pinctrl 方式（见 Step 7 情况 C） |
| `DT_ALIAS(led0)` 找不到节点 | overlay alias 未正确指向 | 检查 overlay 中 `led0 = &xxx` 是否对应已有节点 |
| `undefined reference to gpio_pin_configure_dt` | prj.conf 未启用 GPIO | 确认 `CONFIG_GPIO=y` |
| `Deprecated BOARD=xxx specified` | 旧板卡名称格式 | 警告不影响编译，可忽略 |
| `FATAL ERROR: Python dependencies missing` | Python 依赖不完整 | 运行 `pip3 install --user -r $NCS_DIR/zephyr/scripts/requirements-base.txt` |

---

## Step 9: 烧录验证

### 9.1 烧录方式选择

通过 `AskUserQuestion` 询问：
- "JLink 烧录（west flash）(Recommended)"
- "JLink 手动烧录（JLinkExe + CommandFile）"
- "生成 UF2 文件拖拽烧录"

### 9.2 方式 A：west flash（推荐）

```bash
west flash --runner jlink
```

> **⚠️ 若 west flash 报 `FATAL ERROR: Python dependencies missing`**：
> ```bash
> pip3 install --user -r "$HOME/ncs/zephyr/scripts/requirements-base.txt"
> ```
> **若 west flash 执行后无输出或静默退出**：可能是 JLinkExe 需要 USB 权限但被 sandbox 限制。改用方式 B。

### 9.3 方式 B：JLinkExe 手动烧录（west flash 失败时使用）

```bash
# 生成 JLink 命令脚本
cat > /tmp/flash.jlink << 'EOF'
device <CHIP>_xxAA
if SWD
speed 4000
connect
loadfile <project_path>/build/merged.hex
r
g
exit
EOF

# 执行烧录（使用 Step 1.2 记录的 JLINK_PATH）
<JLINK_PATH> -NoGui 1 -CommandFile /tmp/flash.jlink
```

> **芯片型号映射**：
> - nRF52840 → `nRF52840_xxAA`
> - nRF52832 → `nRF52832_xxAA`
> - nRF52810 → `nRF52810_xxAA`

### 9.4 烧录后验证

观察 LED 是否按预期闪烁，或通过串口查看 printf 输出：

```bash
# macOS
screen /dev/tty.usbmodem* 115200
# 或
screen /dev/tty.SLAB_USBtoUART* 115200

# Linux
screen /dev/ttyACM* 115200
```

> 按 `Ctrl+A` 然后 `K` 然后 `Y` 退出 screen。

---

## 完成标志

- [x] 项目目录创建完成
- [x] `west build` 编译成功
- [x] 固件烧录到芯片并运行（LED 闪烁 / 串口输出正常）
- [x] 用户确认开发环境可以开始调试

完成后提示用户：后续开发中遇到问题可使用 `nrf-528xx-debug` skill 协助排错。
