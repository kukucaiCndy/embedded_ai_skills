---
name: "nrf-connect-project-init"
description: "Initialize a new nRF528xx development project. 自动侦测芯片型号，与用户交互确认硬件资源（GPIO/SPI/I2C/UART），选择编程语言，搭建 CMake 项目框架，完成编译烧录验证。Call after nrf-connect-sdk-setup is complete and the user wants to start a new project."
---

# nRF528xx 项目初始化

引导用户通过人机交互方式完成新项目的创建、配置、编译和烧录。

---

## Step 1: 确保开发环境到位

检查以下关键工具是否可用：

```bash
which arm-none-eabi-gcc   # 交叉编译器
which JLinkExe            # J-Link 烧录工具
which west                # Zephyr 元构建工具
```

| 检查项 | 缺失时的操作 |
|--------|-------------|
| `arm-none-eabi-gcc` 缺失 | 提示用户先运行 `nrf-connect-sdk-setup` skill |
| `JLinkExe` 缺失 | 提示用户先安装 J-Link 驱动（见 `nrf-connect-sdk-setup`） |
| `west` 缺失 | `pip3 install --user west`，配置 PATH |

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

## Step 5: 验证 bootloader 布局（如适用）

如果用户使用的开发板有 bootloader（如 Nice!Nano、Adafruit bootloader），需要确认应用程序烧录偏移地址：

```bash
# 读取 UICR 确认 bootloader 布局
JLinkExe -NoGui 1 -device <CHIP> -if SWD -speed 4000 -autoconnect 1 \
  -CommanderScript /dev/stdin <<< "mem32 0x10001014 1\nexit" | grep "10001014"
```

或直接询问用户：
- "开发板有无 bootloader？"
  - "无 bootloader，APP 从 0x0 开始 (Recommend)"
  - "有 UF2 bootloader（如 Nice!Nano），APP 从 0x26000 开始"
  - "自定义偏移（请填写 0x 地址）"

---

## Step 6: 生成项目框架

在确认的目标路径创建 CMake 项目：

### 项目目录结构

```
<project>/
├── CMakeLists.txt        # 顶层 CMake
├── prj.conf              # Zephyr Kconfig 配置
├── boards/
│   └── <board>.overlay   # 设备树 overlay（引脚映射）
├── src/
│   └── main.c / main.cpp # 应用入口
└── README.md             # 项目说明（如有多个模块）
```

### CMakeLists.txt 模板

```cmake
cmake_minimum_required(VERSION 3.20)
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(my_project)

target_sources(app PRIVATE src/main.c)
```

### src/main.c 模板 (C)

```c
#include <zephyr/kernel.h>
#include <zephyr/drivers/gpio.h>

/* LED 引脚 - 根据 Step 3 收集的信息填充 */
#define LED_NODE DT_ALIAS(led0)
static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED_NODE, gpios);

void main(void)
{
    if (!device_is_ready(led.port)) { return; }
    gpio_pin_configure_dt(&led, GPIO_OUTPUT_ACTIVE);

    while (1) {
        gpio_pin_toggle_dt(&led);
        k_msleep(1000);
    }
}
```

### boards/<board>.overlay 示例（根据 Step 3 引脚生成）

```dts
/ {
    aliases {
        led0 = &my_led;
    };

    my_led: led {
        compatible = "gpio-leds";
        led_0: led_0 {
            gpios = <&gpio0 15 GPIO_ACTIVE_LOW>;
            label = "Blue LED";
        };
    };
};
```

---

## Step 7: 编译项目

```bash
cd <project_path>
west build -b <board_name> . --pristine
```

如果编译失败，分析错误信息并通知用户修复。常见问题：
- 引脚配置错误 → 检查 `.overlay` 文件
- 模块未启用 → 检查 `prj.conf`

---

## Step 8: 烧录验证

### 无 bootloader（标准开发板）

```bash
west flash
```

### 有 bootloader（如 Nice!Nano，APP 偏移 0x26000）

```bash
# 生成二进制
arm-none-eabi-objcopy -O binary build/zephyr/zephyr.elf /tmp/app.bin

# J-Link 烧录到正确偏移
cat > /tmp/flash.jlink << 'FLASHEOF'
device <CHIP>
if SWD
speed 4000
connect
erase <APP_OFFSET> <APP_SIZE>
loadbin /tmp/app.bin <APP_OFFSET>
r
g
exit
FLASHEOF

JLinkExe -NoGui 1 -CommandFile /tmp/flash.jlink
```

### 烧录后验证

观察 LED 是否按预期闪烁，或通过串口查看 printf 输出：

```bash
screen /dev/tty.usbmodem* 115200
```

---

## 完成标志

- [x] 项目目录创建完成
- [x] `west build` 编译成功
- [x] 固件烧录到芯片并运行（LED 闪烁 / 串口输出正常）
- [x] 用户确认开发环境可以开始调试

完成后提示用户：后续开发中遇到问题可使用 `nrf-528xx-debug` skill 协助排错。
