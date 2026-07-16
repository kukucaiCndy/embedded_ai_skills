---
name: "zmk-project-init"
description: "Initialize a ZMK keyboard firmware project. Invoke when user wants to create a new ZMK-based wireless/wired keyboard project, add a custom shield, or set up ZMK development environment."
---

# ZMK 键盘项目初始化

引导用户完成 ZMK (Zephyr Mechanical Keyboard) 固件项目的创建、配置、编译和烧录。

---

## 适用场景

- 创建新的 ZMK 蓝牙/有线键盘项目
- 为已有键盘 PCB 添加 ZMK shield 定义
- 搭建 ZMK 本地开发环境并编译固件

## 前置条件

- 目标 MCU 为 32 位 ARM（nRF52840/nRF52832/RP2040/STM32 等），ZMK 不支持 AVR
- 系统已安装基本工具链（cmake、ninja、dtc、gperf、python3、arm-none-eabi-gcc）
- 如需烧录：J-Link 已连接 或 板卡支持 UF2 拖拽烧录

---

## Step 1: 环境检测

> ZMK 基于 Zephyr v4.1+，要求 Python >= 3.10。系统自带 Python 3.9 可能不满足要求。

并行检测以下组件：

```bash
cmake --version | head -1
ninja --version
dtc --version | head -1
gperf --version | head -1
python3 --version
arm-none-eabi-gcc --version | head -1
```

J-Link 检测（含非标准路径）：
```bash
JLINK_PATH=""
candidates="$(
  which JLinkExe 2>/dev/null
  echo "/Applications/SEGGER/JLink/JLinkExe"
  find /Applications/SEGGER -name 'JLinkExe' -maxdepth 3 2>/dev/null
  find "$HOME/tools" -name 'JLinkExe' -maxdepth 5 2>/dev/null
)"
while IFS= read -r p; do
  [ -n "$p" ] && [ -x "$p" ] && JLINK_PATH="$p" && break
done <<< "$candidates"
echo "JLinkExe: ${JLINK_PATH:-NOT_FOUND}"
```

### Python 版本要求（⚠️ 关键）

Zephyr v4.1 要求 Python >= 3.10。如果系统 Python < 3.10：
```bash
# macOS
brew install python@3.12
# 创建 venv（⚠️ Homebrew Python 不允许全局 pip install，必须用 venv）
cd <zmk_dir>
python3.12 -m venv .venv
source .venv/bin/activate
pip install west
pip install -r zephyr/scripts/requirements-base.txt
```

> **⚠️ Homebrew Python PEP 668 限制**：Homebrew 安装的 Python 3.12 不允许直接 `pip3 install`（报错 `externally-managed-environment`）。必须创建 venv 后在 venv 内安装包。

---

## Step 2: 克隆 ZMK 仓库并初始化 Workspace

```bash
cd <project_parent_dir>
git clone https://github.com/zmkfirmware/zmk.git
cd zmk

# 初始化 Zephyr workspace（⚠️ 必须取消 ZEPHYR_BASE 环境变量）
unset ZEPHYR_BASE
west init -l app/
west update                    # 下载 Zephyr + 模块，约 4-5GB，需较长时间

# 导出 CMake 包
source .venv/bin/activate      # 如使用 venv
west zephyr-export

# 安装 Python 依赖
pip install -r zephyr/scripts/requirements-base.txt
```

> **⚠️ NCS 冲突**：如果系统已安装 nRF Connect SDK，`.zshrc` 中的 `source zephyr-env.sh` 会设置 `ZEPHYR_BASE` 指向 NCS。ZMK 需要自己的 Zephyr fork，编译前必须 `unset ZEPHYR_BASE`。

> **⚠️ west update 网络失败 — 必须重试！**：部分模块可能因网络超时失败。如果后续启用 BLE（`CONFIG_ZMK_BLE=y`），需要 **mbedtls** 模块。模块不全会导致 Kconfig 警告 `MBEDTLS has direct dependencies 0 with value n` 并中止编译。遇到此问题需重新运行 `west update` 直到所有模块下载成功。失败的模块不会自动重试，必须完整重新 `west update`。
>
> 如何判断是否需要重试：查看 `west update` 输出末尾是否有 `ERROR: update failed for projects: ...`。如果有，重新运行 `west update`。

---

## Step 3: 确认硬件配置

通过 `AskUserQuestion` 与用户交互确认：

### 3.1 芯片型号
- nRF52840（最常用，USB + BLE）
- nRF52832（BLE，无 USB）
- RP2040
- STM32
- 其他

### 3.2 开发板/控制器
- nice!nano（ZMK 最流行，nRF52840 + UF2 bootloader + 锂电池充电）
- nRF52840 DK
- Pro Micro RP2040
- 自定义板

### 3.3 键盘布局
- 自定义矩阵（行列数）
- 已有布局（Corne、Sofle、Kyria 等）

### 3.4 外设功能（多选）
- 编码器
- I2C OLED/LCD 屏幕
- RGB 灯效
- 电池电量检测
- 外设电源控制（VCC shutoff）
- 状态按钮/LED
- UART 调试串口

---

## Step 4: 确定引脚分配

### Pro Micro 引脚布局（nice!nano 等）

> **⚠️ D11/D12 在 nice!nano v2 上不可用**，分配引脚时需避开。

| Pro Micro Pin | nRF52840 GPIO | 功能 |
|---|---|---|
| D0 | P0.08 | UART RX |
| D1 | P0.06 | UART TX |
| D2 | P0.17 | GPIO / I2C SDA |
| D3 | P0.20 | GPIO / I2C SCL |
| D4 | P0.22 | GPIO |
| D5 | P0.24 | GPIO |
| D6 | P1.00 | GPIO |
| D7 | P0.11 | GPIO |
| D8 | P1.04 | GPIO |
| D9 | P1.06 | GPIO |
| D10 | P0.09 | GPIO |
| D14 | P1.11 | SPI MISO |
| D15 | P1.13 | SPI SCK |
| D16 | P0.10 | SPI MOSI |
| D18 | P1.15 | GPIO / A0 |
| D19 | P0.02 | GPIO / A1 |
| D20 | P0.29 | GPIO / A2 |
| D21 | P0.31 | GPIO / A3 |

### ZMK 中的 Pro Micro 节点与总线别名

ZMK 定义了 `&pro_micro` connector 和标准总线别名：
- `&pro_micro_i2c` → `&i2c0`（I2C 总线，pinctrl 映射到 **D2/D3** 即 P0.17/P0.20）
- `&pro_micro_spi` → `&spi1`（SPI 总线，pinctrl 映射到 D14/D15/D16）
- `&pro_micro_serial` → `&uart0`（UART，pinctrl 映射到 **D0/D1** 即 P0.08/P0.06）

> **⚠️ I2C 和 UART 引脚不冲突**：`pro_micro_i2c` 使用 D2/D3，`pro_micro_serial` 使用 D0/D1。可以同时启用 I2C OLED 和 UART 调试串口。

在 shield dtsi 中引用引脚：`<&pro_micro 7 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>` 表示 D7。

---

## Step 5: 创建用户配置目录结构

```
config/
├── build.yaml                                # CI 构建配置
└── boards/
    └── shields/
        └── <keyboard_name>/
            ├── <keyboard_name>.zmk.yml       # Shield 元数据（⚠️ 必须）
            ├── <keyboard_name>.overlay       # Shield 主 overlay（⚠️ 必须，否则 shield 不被发现）
            ├── <keyboard_name>.dtsi          # 硬件定义（被 overlay include）
            ├── <keyboard_name>.conf          # ⚠️ Shield Kconfig 配置（启用 USB/BLE/UART 等）
            ├── <keyboard_name>.keymap        # 键盘映射
            ├── Kconfig.shield                # Shield 声明
            ├── Kconfig.defconfig             # Shield 默认配置
            └── boards/
                └── <board_name>.overlay      # 板级特定 overlay（⚠️ 文件名匹配不可靠，见下方说明）
```

### ⚠️ 关键文件说明

| 文件 | 必须？ | 作用 | 常见错误 |
|------|--------|------|----------|
| `.zmk.yml` | ✅ | Shield 元数据，声明 type/requires/features | 遗漏导致 shield 不被识别 |
| `.overlay`（同名） | ✅ | Zephyr 通过此文件发现 shield | 只有 `.dtsi` 没有 `.overlay` 导致 shield 列表中找不到 |
| `.conf` | ✅ | 启用 USB/BLE/UART 等功能 | **ZMK 默认不启用 USB 和 BLE！必须在此显式启用** |
| `Kconfig.shield` | ✅ | 注册 shield 到 Kconfig | `def_bool y` 写法错误，必须用 `def_bool $(shields_list_contains,<name>)` |
| `Kconfig.defconfig` | ✅ | Shield 默认 Kconfig 值 | 在此重新定义 ZMK 内部 Kconfig 符号的 type 会导致警告 |
| `.keymap` | ✅ | 键盘按键映射 | 缺少 `#include <behaviors.dtsi>` 导致 `&kp` 等未定义 |
| `.dtsi` | 可选 | 硬件定义（可合并到 .overlay 中） | — |

---

## Step 6: 编写 Shield 定义文件

### 6.1 `<keyboard_name>.zmk.yml`

```yaml
file_format: "1"
id: <keyboard_name>
name: <Display Name>
type: shield
url: ""
requires: [pro_micro]        # 或其他 interconnect
exposes: [i2c_oled]          # 可选
features:
  - keys
  - display                  # 如有屏幕
  - encoder                  # 如有编码器
```

### 6.2 `Kconfig.shield`

```kconfig
# SPDX-License-Identifier: MIT

config SHIELD_<KEYBOARD_NAME_UPPER>
    def_bool $(shields_list_contains,<keyboard_name>)
```

### 6.3 `Kconfig.defconfig`

```kconfig
# SPDX-License-Identifier: MIT

if SHIELD_<KEYBOARD_NAME_UPPER>

config ZMK_KEYBOARD_NAME
    default "<Keyboard Name>"

# ⚠️ 不要在此定义 ZMK 内部符号的 type（如 ZMK_ENCODER），
# 只设置 default 值。ZMK_ENCODER 通过 DTS 自动启用。

if ZMK_DISPLAY
config I2C
    default y
config SSD1306
    default y
endif

endif
```

### 6.4 `<keyboard_name>.conf`（⚠️ 关键 — 启用 USB/BLE/UART）

> **⚠️ ZMK 新版 board defconfig 不自动加载 `ZMK_USB`/`ZMK_BLE`！**
>
> ZMK 存在两套 board 定义：`app/module/boards/`（新格式，defconfig 中**没有** `ZMK_USB`/`ZMK_BLE`）和 `app/boards/`（旧格式，defconfig 中**有**）。Zephyr v4.1 优先加载 module 目录的 defconfig，导致 USB 和 BLE 未启用。
>
> **必须在 `<keyboard_name>.conf` 中显式启用！**

```ini
# <keyboard_name>.conf - Shield 配置

# USB HID（⚠️ 必须！不启用则 USB 无法识别设备）
CONFIG_ZMK_USB=y

# 蓝牙 BLE（⚠️ 必须！不启用则蓝牙不可见）
# 注意：BLE 依赖 mbedtls 模块，west update 必须完整成功
CONFIG_ZMK_BLE=y

# UART 调试串口（可选，TX=P0.06/D1, RX=P0.08/D0, 115200 baud）
CONFIG_SERIAL=y
CONFIG_NRFX_UARTE0=y
CONFIG_CONSOLE=y
CONFIG_UART_CONSOLE=y
CONFIG_PRINTK=y

# 日志
CONFIG_LOG=y
CONFIG_LOG_DEFAULT_LEVEL=4
```

> **⚠️ UART 驱动配置**：仅设置 `CONFIG_SERIAL=y` 和 `CONFIG_UART_CONSOLE=y` 不够。nRF 平台还需要 `CONFIG_NRFX_UARTE0=y` 启用底层 UART 驱动，否则 `SERIAL_HAS_DRIVER` 为 `n`，`UART_CONSOLE` 依赖不满足会被静默禁用。

### 6.5 `<keyboard_name>.overlay` / `.dtsi`

```dts
#include <dt-bindings/zmk/matrix_transform.h>

/ {
    chosen {
        zmk,kscan = &kscan0;
        zmk,matrix_transform = &default_transform;
        zephyr,display = &oled;          /* 如有显示屏 */
    };

    default_transform: keymap_transform_0 {
        compatible = "zmk,matrix-transform";
        columns = <3>;
        rows = <2>;
        map = <
            RC(0,0) RC(0,1) RC(0,2)
            RC(1,0) RC(1,1) RC(1,2)
        >;
    };

    kscan0: kscan {
        compatible = "zmk,kscan-gpio-matrix";
        wakeup-source;
        debounce-press-ms = <5>;          /* ⚠️ 不是 debounce-period-ms（已废弃） */
        debounce-release-ms = <5>;
        diode-direction = "col2row";      /* 或 "row2col" */

        row-gpios
            = <&pro_micro 7 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>
            , <&pro_micro 8 (GPIO_ACTIVE_HIGH | GPIO_PULL_DOWN)>;

        col-gpios
            = <&pro_micro 9 GPIO_ACTIVE_HIGH>
            , <&pro_micro 10 GPIO_ACTIVE_HIGH>
            , <&pro_micro 5 GPIO_ACTIVE_HIGH>;
    };

    /* 编码器 */
    sensors: sensors {
        compatible = "zmk,keymap-sensors";
        sensors = <&encoder_0>;
        triggers-per-rotation = <2>;
    };

    encoder_0: encoder_0 {
        compatible = "alps,ec11";         /* ⚠️ 必须声明 compatible */
        a-gpios = <&pro_micro 15 (GPIO_ACTIVE_LOW | GPIO_PULL_UP)>;
        b-gpios = <&pro_micro 14 (GPIO_ACTIVE_LOW | GPIO_PULL_UP)>;
        steps = <80>;
        status = "okay";
    };

    /* 状态按钮（gpio-keys 必须是容器+子节点结构） */
    buttons: buttons {
        compatible = "gpio-keys";
        status_button: status_button {
            gpios = <&pro_micro 4 GPIO_ACTIVE_LOW>;
            zephyr,code = <0x0c>;
        };
    };
};

/* I2C OLED（使用 Pro Micro 标准 I2C 节点） */
&pro_micro_i2c {
    status = "okay";

    oled: ssd1306@3c {
        compatible = "solomon,ssd1306fb";
        reg = <0x3c>;
        width = <128>;
        height = <32>;
        segment-offset = <0>;
        page-offset = <0>;
        display-offset = <0>;
        multiplex-ratio = <31>;
        segment-remap;                    /* ⚠️ 不带值，不是 = <1> */
        com-invdir;
        com-sequential;
        inversion-on;
        prechargep = <0x22>;              /* ⚠️ 属性名是 prechargep，不是 precharge-period */
    };
};

/* UART 调试串口（⚠️ 放在 shield 主 .overlay 中，不要放在 boards/<board>.overlay 中） */
&uart0 {
    status = "okay";                       /* 板卡 DTS 默认 disabled，必须启用 */
};

/ {
    chosen {
        zephyr,console = &uart0;           /* ⚠️ 必须设置 console 指向 */
        zephyr,shell-uart = &uart0;
    };
};
```

> **⚠️ UART 启用必须放在 shield 主 `.overlay` 中**：board-specific overlay（`boards/<board_name>.overlay`）的文件名匹配在 Zephyr v4.1 新 board 模型下不可靠（board 名从 `nice_nano_nrf52840_zmk` 变为 `nice_nano` + qualifier `nrf52840`），导致 overlay 不被加载。将 `&uart0 { status = "okay"; }` 和 `chosen` 放在 shield 主 `.overlay` 中可确保生效。

### 6.6 `<keyboard_name>.keymap`

```dts
#include <behaviors.dtsi>                 /* ⚠️ 必须！定义 &kp &bt &out 等行为 */
#include <dt-bindings/zmk/keys.h>
#include <dt-bindings/zmk/bt.h>
#include <dt-bindings/zmk/outputs.h>

/* 启用编码器 */
&encoder_0 {
    status = "okay";
};

&sensors {
    sensors = <&encoder_0>;
};

/ {
    keymap {
        compatible = "zmk,keymap";

        default_layer {
            display-name = "Default";
            bindings = <
                &kp Q    &kp W    &kp E
                &kp A    &kp S    &kp D
            >;
            /* ⚠️ 用 &inc_dec_kp（不是 &inc_kp） */
            sensor-bindings = <&inc_dec_kp C_VOLUME_UP C_VOLUME_DOWN>;
        };
    };
};
```

### 6.7 `boards/<board_name>.overlay`

> **⚠️ board-specific overlay 文件名匹配不可靠**：Zephyr v4.1 新 board 模型将 `nice_nano_v2` 改为 `nice_nano` + qualifier。board-specific overlay 文件名 `nice_nano_nrf52840_zmk.overlay` 可能不被加载。**建议将所有配置放在 shield 主 `.overlay` 中，不依赖 board-specific overlay。**

```dts
/* 板级 overlay，通常只需 include shield 主 dtsi */
#include "<keyboard_name>.dtsi"
```

### 6.8 `build.yaml`

```yaml
build:
  - board: nice_nano             # ⚠️ 不是 nice_nano_v2
    shield: <keyboard_name>
    artifact-name: <keyboard_name>-nice_nano
```

---

## Step 7: 编译

> **⚠️ 编译命令使用 board qualifier 格式**：`-b nice_nano/nrf52840`，不要用 `-b nice_nano -DBOARD_REV=2.0.0`。旧格式会导致 board defconfig 中的 `ZMK_USB`/`ZMK_BLE` 不被加载。

```bash
cd <zmk_dir>
source .venv/bin/activate        # 如使用 venv
unset ZEPHYR_BASE                # ⚠️ 必须！避免使用 NCS 的 Zephyr

cd app
west build -b nice_nano/nrf52840 -- \
  -DSHIELD=<keyboard_name> \
  -DZMK_CONFIG=<absolute_path_to_config>
```

### ⚠️ 验证关键配置（编译后必须检查）

编译成功后，检查 `.config` 确认 USB/BLE/UART 已启用：

```bash
grep -E "CONFIG_ZMK_USB|CONFIG_ZMK_BLE|CONFIG_BT[^_]|CONFIG_USB_DEVICE_HID|CONFIG_NRFX_UARTE0|CONFIG_UART_CONSOLE" build/zephyr/.config
```

期望输出：
```
CONFIG_ZMK_USB=y
CONFIG_ZMK_BLE=y
CONFIG_BT=y
CONFIG_USB_DEVICE_HID=y
CONFIG_NRFX_UARTE0=y          # 如启用 UART
CONFIG_UART_CONSOLE=y          # 如启用 UART
```

如果看到 `# CONFIG_ZMK_USB is not set`，说明 `.conf` 文件未被加载或配置有误。

### 编译常见错误与解决方案

| 错误 | 原因 | 解决方案 |
|------|------|----------|
| `Could NOT find Python3: unsuitable version "3.9"` | Python < 3.10 | 安装 Python 3.12 + 创建 venv |
| `No shield named 'xxx' found` | 缺少同名 `.overlay` 文件 | 在 shield 目录创建 `<name>.overlay` |
| `already initialized in .../ncs` | ZEPHYR_BASE 指向 NCS | `unset ZEPHYR_BASE` |
| `undefined node label 'kp'` | keymap 缺少 behaviors include | 添加 `#include <behaviors.dtsi>` |
| `expected number or parenthesized expression` | 宏名错误 | 检查 keys.h 中的宏名（如 `C_BRI_UP` 不是 `C_BRIGHTNESS_UP`） |
| `'debounce-period-ms' is not declared` | 属性已废弃 | 改为 `debounce-press-ms` + `debounce-release-ms` |
| `'gpios' appears in ... but is not declared` | gpio-keys 节点结构错误 | 使用容器+子节点结构 |
| `ZMK_ENCODER defined without a type` | defconfig 重新定义了 type | 从 Kconfig.defconfig 中移除 ZMK_ENCODER 定义 |
| `parse error: expected label reference (&foo)` | 独立节点不在根节点内 | 将节点放入 `/ { ... }` 块中 |
| `MBEDTLS has direct dependencies 0` | BLE 依赖 mbedtls 但模块未下载 | 重新 `west update` 直到所有模块成功 |
| `UART_CONSOLE assigned 'y' but got 'n'` | nRF UART 驱动未启用 | 添加 `CONFIG_NRFX_UARTE0=y` |
| `No SOURCES given to Zephyr library: drivers__serial` | serial 驱动未编译 | 确认 `CONFIG_NRFX_UARTE0=y` 在 .conf 中 |
| USB 设备不识别 / 蓝牙不可见 | ZMK_USB/ZMK_BLE 未启用 | 在 `.conf` 中添加 `CONFIG_ZMK_USB=y` 和 `CONFIG_ZMK_BLE=y` |
| 串口无输出 | uart0 status=disabled 或 console 未设置 | 在 `.overlay` 中 `&uart0 { status = "okay"; }` + `chosen { zephyr,console = &uart0; }` |

### 编译成功标志

```
Wrote 544768 bytes to zmk.uf2
```

输出文件：
- `build/zephyr/zmk.uf2` — UF2 格式（拖拽烧录用）
- `build/zephyr/zmk.hex` — Intel HEX 格式（J-Link 烧录用，内含 0x26000 偏移地址）
- `build/zephyr/zmk.elf` — ELF 格式（调试用）

---

## Step 8: 烧录

### ⚠️ 烧录前：备份全片 Flash（强烈建议）

> **J-Link 全片擦除 (`erase`) 会删除 bootloader（0x0-0x26000）！**
> 烧录前先用 J-Link 备份完整 flash，以便误操作后恢复：

```bash
cat > /tmp/backup.jlink << 'EOF'
device nRF52840_xxAA
if SWD
speed 4000
connect
savebin <backup_path>/nrf52840_flash_backup.bin, 0, 0x100000
exit
EOF
"$JLINK_PATH" -NoGui 1 -CommanderScript /tmp/backup.jlink
```

### 方式 A: UF2 拖拽烧录（需要 bootloader 完好）

1. 双击 RESET 按钮进入 bootloader
2. 设备显示为 USB 存储设备
3. 复制 `build/zephyr/zmk.uf2` 到该存储设备
4. 设备自动重启

### 方式 B: J-Link 安全烧录（保留 bootloader，推荐）

> **hex 文件内含地址信息（0x26000 起），J-Link `loadfile` 会自动处理偏移，无需手动指定地址。**
>
> **⚠️ 必须使用范围擦除 `erase 0x26000, 0xDA000`，不要用全片 `erase`！**

```bash
JLINK_PATH="<JLinkExe 路径>"
cat > /tmp/flash.jlink << 'EOF'
device nRF52840_xxAA
if SWD
speed 4000
connect
erase 0x26000, 0xDA000
loadfile <path>/build/zephyr/zmk.hex
r
g
exit
EOF
"$JLINK_PATH" -NoGui 1 -CommanderScript /tmp/flash.jlink
```

> **分区布局（nice!nano v2 / nRF52840）**：
> | 地址范围 | 内容 | 大小 |
> |---|---|---|
> | 0x000000 - 0x025FFF | UF2 Bootloader | 152KB |
> | 0x026000 - 0x0D9FFF | ZMK 应用固件 | ~728KB |
> | 0x0DA000 - 0x0EBFFF | 应用保留区 | ~72KB |
> | 0x0EC000 - 0x0F3FFF | Storage (NVS) | 32KB |
> | 0x0F4000 - 0x0FFFFF | Boot partition | 48KB |

### 方式 C: J-Link 全片擦录（⚠️ 会删除 bootloader）

> 仅在需要完全重刷时使用。**烧录后需单独恢复 bootloader。**

```bash
cat > /tmp/flash.jlink << 'EOF'
device nRF52840_xxAA
if SWD
speed 4000
connect
erase
loadfile <path>/build/zephyr/zmk.hex
r
g
exit
EOF
```

### Bootloader 恢复（误删后修复）

如果 bootloader 被误删，从备份恢复：

```bash
cat > /tmp/restore.jlink << 'EOF'
device nRF52840_xxAA
if SWD
speed 4000
connect
erase
loadbin <backup_path>/nrf52840_flash_backup.bin, 0
r
g
exit
EOF
"$JLINK_PATH" -NoGui 1 -CommanderScript /tmp/restore.jlink
```

恢复后再用安全烧录方式烧录 ZMK 固件。

### 方式 D: west flash

```bash
cd <zmk_dir>/app
west flash --runner jlink
```

---

## Step 9: 验证

### 9.1 基本验证

1. 烧录后设备自动复位运行
2. 通过 USB 连接电脑，应识别为 HID 键盘（名称为 `ZMK_KEYBOARD_NAME` 设置的值）
3. 蓝牙搜索应能发现设备
4. 按键测试：矩阵中的按键应输出对应字符
5. 编码器测试：旋转应触发音量增减
6. OLED 测试：屏幕应显示 ZMK 默认状态画面

### 9.2 串口调试验证

如启用了 UART 调试串口：
- 连接 USB-TTL 适配器：TX→P0.08 (D0), RX→P0.06 (D1), GND→GND
- 波特率 115200，8N1
- 上电后应看到 ZMK 日志输出

```bash
# macOS
screen /dev/tty.usbserial* 115200
# Linux
screen /dev/ttyUSB* 115200
```

### 9.3 无输出排查

如果 USB 不识别 / 蓝牙不可见 / 串口无输出，按以下顺序排查：

1. **检查 .config**：`grep -E "CONFIG_ZMK_USB|CONFIG_ZMK_BLE|CONFIG_NRFX_UARTE0|CONFIG_UART_CONSOLE" build/zephyr/.config`
2. **检查设备树**：`grep "status" build/zephyr/zephyr.dts | grep -E "uart|usb"` — uart0 应为 `okay`
3. **检查 chosen**：`grep "console" build/zephyr/zephyr.dts` — 应有 `zephyr,console = &uart0`
4. **确认固件在芯片中**：J-Link 读 0x26000 处向量表，第一个 word 应为有效栈指针（0x2000xxxx）

---

## 完成标志

- [x] ZMK 仓库克隆 + `west update` 完整成功（所有模块）
- [x] Shield 定义文件全部创建且格式正确
- [x] `<keyboard_name>.conf` 中启用 `CONFIG_ZMK_USB=y` + `CONFIG_ZMK_BLE=y`
- [x] `west build` 编译成功，生成 `zmk.uf2` / `zmk.hex`
- [x] `.config` 中确认 `ZMK_USB`/`ZMK_BLE`/`BT`/`USB_DEVICE_HID` 均为 `=y`
- [x] 固件烧录到设备并运行（安全擦录，保留 bootloader）
- [x] 设备识别为 HID 键盘 / BLE 可发现

---

## 速查：ZMK 新版关键变更（vs 旧版/文档）

| 项目 | 旧版 | 新版 (2025+) |
|------|------|-------------|
| 板卡名 | `nice_nano_v2` | `nice_nano` + qualifier `nrf52840` |
| 编译命令 | `-b nice_nano -DBOARD_REV=2.0.0` | `-b nice_nano/nrf52840`（⚠️ 旧格式导致 defconfig 不加载） |
| Python 要求 | >= 3.8 | >= 3.10 |
| Zephyr 版本 | v3.x | v4.1.0+zmk-fixes |
| USB/BLE 启用 | board defconfig 自动加载 | ⚠️ **不自动加载！** 必须在 `.conf` 中显式 `CONFIG_ZMK_USB=y` / `CONFIG_ZMK_BLE=y` |
| UART 驱动 | `CONFIG_SERIAL=y` 即可 | 额外需要 `CONFIG_NRFX_UARTE0=y` |
| board-specific overlay | 文件名匹配可靠 | ⚠️ 文件名匹配不可靠，配置放 shield 主 `.overlay` |
| 消抖属性 | `debounce-period-ms` | `debounce-press-ms` + `debounce-release-ms` |
| OLED 属性 | `precharge-period = <0x22>` | `prechargep = <0x22>` |
| OLED remap | `segment-remap = <1>` | `segment-remap`（无值） |
| Shield 元数据 | 无 | `.zmk.yml` 文件（必须） |
| Shield overlay | 仅 `.dtsi` | 同名 `.overlay` 文件（必须） |
| 传感器绑定 | `&inc_kp` | `&inc_dec_kp` |
| 亮度宏 | `C_BRIGHTNESS_UP` | `C_BRI_UP` |
| config/boards | 支持 | 已废弃警告（仍可用，建议迁移到 module） |
| I2C 引脚 | D0/D1 (P0.08/P0.06) | D2/D3 (P0.17/P0.20)（⚠️ pinctrl 已改） |
| J-Link 烧录 | 全片 erase 可接受 | ⚠️ 必须范围擦除 `erase 0x26000, 0xDA000` 保留 bootloader |
