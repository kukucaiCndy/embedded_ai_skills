---
name: "stm32-dev"
description: "STM32 embedded development guide - cross-platform (Windows/macOS/Linux), supports both CubeIDE and pure CLI paths. No CubeMX required."
---

# STM32 开发指南

> 跨平台支持：**Windows** / **macOS** / **Linux**。
> 两条路径任选：**路径 A**（CubeIDE 已安装）或 **路径 B**（纯 CLI，全部开源）。

## SKILL 加载后的执行流程

### ⚠️ 重要声明：经验 ≠ 标准 SOP

> 本 SKILL 中所有烧录命令、驱动选择、接线方式、BOOT0 操作等**均来自特定硬件的实测经验**。不同开发板的硬件配置各不相同（有无 NRST、晶振类型、LED 引脚极性等），**AI 必须在执行任何操作前先向用户确认硬件情况，不能盲目照搬 SKILL 中的任何步骤。**

### 第零步：检测平台与 Shell

> 🔥 **推荐所有平台使用 MSYS2 作为统一 Shell。** Windows 上通过 MSYS2 安装工具链并获得 bash 环境；macOS 和 Linux 本身就有 bash，但同样推荐沿用本文档的 MSYS2+pacman 流程以保证一致性（Linux 上 pacman 可用系统自带的，macOS 上用 Homebrew 替代）。Zadig 驱动修复仅 Windows 需要。

```bash
# 检测操作系统
uname -s    # Linux / Darwin (macOS) / MINGW64_NT (Windows MSYS2) / MSYS_NT

# MSYS2 是首选 Shell（Windows 必装）
# 如果不是 MSYS2 环境，引导用户安装：
# Windows: 安装 MSYS2 (https://www.msys2.org/) → 启动 MSYS2 UCRT64 → 继续
# macOS: 安装 Homebrew → brew install ... → 继续
# Linux: 直接用系统包管理器 → 继续
```

**工具链安装（按平台）：**

| 平台 | 推荐 Shell | 安装命令 |
|------|-----------|---------|
| **Windows** | **MSYS2 UCRT64**（必装） | `pacman -S --needed mingw-w64-x86_64-arm-none-eabi-gcc mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja mingw-w64-x86_64-stlink` |
| **macOS** | Terminal + Homebrew | `brew install --cask gcc-arm-embedded && brew install cmake ninja stlink` |
| **Linux** | 系统 Terminal | `sudo apt install -y gcc-arm-none-eabi cmake ninja-build stlink-tools` |

### 第一步：安装工具链 + 确定路径

```bash
# 检测 CubeIDE（Windows only，路径 A 的来源）
CUBEIDE_OK=0
ls -d /c/ST/STM32CubeIDE_*/STM32CubeIDE/STM32CubeIDE.exe /d/ST/STM32CubeIDE_*/STM32CubeIDE/STM32CubeIDE.exe 2>/dev/null && CUBEIDE_OK=1

# 检测系统包管理器中已有的编译工具（跨平台通用）
arm-none-eabi-gcc --version 2>/dev/null | head -1 && GCC_OK=1 || GCC_OK=0
cmake --version 2>/dev/null | head -1 && CMAKE_OK=1 || CMAKE_OK=0
ninja --version 2>/dev/null && NINJA_OK=1 || NINJA_OK=0
```

**路径 B 工具链安装（按平台，选一个）：**

| 平台 | 安装命令（一次性） |
|------|------------------|
| **Windows (MSYS2)** | `pacman -S --needed mingw-w64-x86_64-arm-none-eabi-gcc mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja mingw-w64-x86_64-stlink` |
| **macOS (Homebrew)** | `brew install --cask gcc-arm-embedded && brew install cmake ninja stlink` |
| **Linux (apt)** | `sudo apt install -y gcc-arm-none-eabi cmake ninja-build stlink-tools` |
| **Linux (dnf)** | `sudo dnf install -y arm-none-eabi-gcc-cs cmake ninja-build stlink` |
| **Linux (arch)** | `sudo pacman -S --needed arm-none-eabi-gcc cmake ninja stlink` |

> 💡 **非 Windows 用户无需 MSYS2。** Mac/Linux 通过系统包管理器安装工具链，其余流程（stm32-cmake、编译 CMakeLists、烧录）全部相同。

**路径判断：**

| 条件 | 路径 | 说明 |
|------|------|------|
| CubeIDE 已安装 (Windows only) | **路径 A** | 取其内置 arm-gcc + cmake + CubeProgrammer，无需额外装工具链 |
| CubeIDE 未安装 + 工具链已就绪 | **路径 B** | 纯 CLI，全部开源 |
| CubeIDE 未安装 + 工具链缺失 | **先装工具链 → 路径 B** | 按上表选一条命令即可 |

**路径 A 工具链定位（Windows CubeIDE）：**
```bash
CUBEIDE_ROOT=$(ls -d /c/ST/*/STM32CubeIDE /d/ST/*/STM32CubeIDE 2>/dev/null | head -1)
GCC_DIR=$(ls -d "$CUBEIDE_ROOT/plugins/com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32."*".win32_"*/tools/bin 2>/dev/null | head -1)
CMAKE_DIR=$(ls -d "$CUBEIDE_ROOT/plugins/com.st.stm32cube.ide.mcu.externaltools.cmake.win32_"*/tools/bin 2>/dev/null | head -1)
NINJA_DIR=$(ls -d "$CUBEIDE_ROOT/plugins/com.st.stm32cube.ide.mcu.externaltools.ninja.win32_"*/tools/bin 2>/dev/null | head -1)
export PATH="$GCC_DIR:$CMAKE_DIR:$NINJA_DIR:$PATH"
```

**检查报告：**
```
平台: [Windows / macOS / Linux]
路径: [A - CubeIDE] 或 [B - Pure CLI]
[✅/❌] ARM GCC         : [版本号]
[✅/❌] CMake           : [版本号]
[✅/❌] Ninja           : [版本号]
[✅/❌] Git             : [版本号]
[✅/❌] 烧录工具        : CubeProgrammer / st-flash
```

### 第二步：首次初始化（全局一次）

```bash
# 克隆 stm32-cmake 到固定目录（整个电脑只做一次）
mkdir -p ~/stm32-tools
git clone --depth=1 https://github.com/ObKo/stm32-cmake.git ~/stm32-tools/stm32-cmake

# 可选：后续更新
git -C ~/stm32-tools/stm32-cmake pull
```

> 🔥 **stm32-cmake 只需安装一次。** 它是一套 `.cmake` 模块，不编译任何二进制。所有项目通过绝对路径引用它，无需在每个项目里重复 clone。
> 
> **目录约定：** `~/stm32-tools/stm32-cmake/`，对应 CMakeLists.txt 中 `set(CMAKE_TOOLCHAIN_FILE ~/stm32-tools/stm32-cmake/cmake/stm32_gcc.cmake)`。

### 第三步：确认芯片型号

> **AI 必须向用户确认芯片的具体型号（丝印），不能假设默认值。** 芯片型号决定 CMSIS 类型和 Flash/RAM 布局。

```
AI: 请确认你的 STM32 芯片型号（看芯片表面丝印），例如：
    F103C8T6 / F103CBT6 / F103RET6 / F407VGT6 / ...
```

### 第四步：项目配置访谈（标准 SOP）

> **AI 按以下顺序逐一询问。这是新项目的标准初始化流程。**

**询问顺序（逐条进行，不要一次性抛出所有问题）：**

```
第1条：编程语言
  AI: "使用 C 还是 C++ 开发？"
  → CMakeLists.txt 中 project(... C ASM) 或 project(... CXX ASM C)

第2条：目标时钟频率
  AI: "期望的系统主频？"
  选项示例：
    - 72MHz（HSE 8MHz ×9，需外部晶振）
    - 48MHz（HSI 8MHz/2 ×12，内部时钟，100% 可靠）
    - 默认推荐：HSE 72MHz 优先，失败自动回退 HSI 48MHz

第3条：是否启用 FreeRTOS
  AI: "需要 FreeRTOS 吗？"
  → 是：CMakeLists.txt 加 RTOS::FreeRTOS，生成 FreeRTOSConfig.h
  → 否：裸机开发

第4条：串口配置
  AI: "需要串口吗？如果用，需要几个，Tx/Rx 引脚和波特率？"
  示例回答："UART1, PA9/PA10, 115200"
  → AI 自主判断是否追问（如多个串口才追问）

第5条：开放性问题
  AI: "请描述你想用这个项目做什么？"
  用户自由回答，例如：
    - "用 TIM3 CH1 输出 50Hz PWM 控制舵机"
    - "读 ADC1 通道 0 的温度传感器并通过 UART 打印"
    - "驱动 I2C OLED 显示屏"
  → AI 根据回答自主决定继续追问哪些外设配置（SPI/I2C/TIM/ADC/DMA 等）
  → AI 完成后总结计划，让用户确认再开始生成代码
```

> 💡 **以上 5 条是标准 SOP。** 硬件差异（LED 引脚、有无 NRST、BOOT 跳线等）不在项目初始化流程中体现——它们只在烧录/救砖阶段遇到问题时才按需处理。

---

## 两条路径总览

> **两种路径共享相同的项目结构和 CMakeLists.txt，切换路径无需改代码。跨 Windows/macOS/Linux 通用。**
> 
> 🔥 **两种路径都不需要 CubeMX。** 代码由 AI 根据模板生成，HAL/CMSIS 由 `stm32_fetch_cube()` 从 ST GitHub 自动下载。

| | **路径 A：CubeIDE 已安装** | **路径 B：纯 CLI（开源工具链）** |
|---|---|---|
| 支持平台 | Windows only（CubeIDE 是 Windows 软件） | **Windows / macOS / Linux** |
| 编译器来源 | CubeIDE 内置 GNU Tools for STM32 | 系统包管理器（见安装表） |
| CMake/Ninja | CubeIDE plugins 目录 | 系统包管理器 |
| HAL/CMSIS 源码 | `stm32_fetch_cube()` 从 ST GitHub 自动下载 | `stm32_fetch_cube()` 从 ST GitHub 自动下载 |
| 代码生成 | AI 根据模板生成（无需 CubeMX） | AI 根据模板生成（无需 CubeMX） |
| 烧录工具 | **CubeProgrammer CLI**（驱动自带） | **st-flash**（Win 需 Zadig one-time；Mac/Linux 免驱） |
| 依赖 ST 闭源软件？ | 是（CubeIDE 本体） | **否，全部开源** |

---

## 创建新项目（两条路径通用）

### 项目目录结构

```
my_project/
├── CMakeLists.txt              ← CMake 项目文件
├── main.c                      ← 主程序
├── stm32f1xx_hal_conf.h        ← [仅 HAL 模式需要]
└── build/                      ← cmake -B build 自动生成
```

> `stm32-cmake/` **不需要放在项目里。** 它是全局安装的（`~/stm32-tools/stm32-cmake/`），CMakeLists.txt 通过绝对路径引用。

### 两种开发模式

| 对比维度 | **CMSIS 寄存器模式** | **HAL 库模式** |
|----------|---------------------|----------------|
| 体积 | ~912 bytes | ~2400 bytes |
| 依赖 | CMSIS 头文件（自动下载） | CMSIS + HAL 驱动（自动下载） |
| 代码风格 | 直接操作寄存器 | HAL API 调用 |
| `hal_conf.h` | 不需要 | **必须提供** |
| 链接目标 | `CMSIS::STM32::F103C8` | `HAL::STM32::F1::RCC` `HAL::STM32::F1::GPIO` `HAL::STM32::F1::CORTEX` |
| 使用场景 | 极致精简、学习底层 | 快速开发、复杂外设 |
| 可靠性 | ✅ 100% 可靠（不依赖时钟/中断） | ⚠️ 需注意 SysTick 配置 |

---

### 模式 A：CMSIS 寄存器模式（零额外文件，已实测验证）

> 🔥 **此模板在 Blue Pill (F103C8T6, PC13 LED Active Low) 上验证通过。** 如果你的 LED 在别的引脚或极性不同，调整 `GPIO_PIN` 和 `BSRR/BR13` 即可。

**CMakeLists.txt：**
```cmake
cmake_minimum_required(VERSION 3.16)
set(CMAKE_TOOLCHAIN_FILE $ENV{HOME}/stm32-tools/stm32-cmake/cmake/stm32_gcc.cmake)
project(my-project C ASM)
stm32_fetch_cube(F1)
find_package(CMSIS COMPONENTS STM32F103C8 REQUIRED)
add_executable(my-project.elf main.c)
target_link_libraries(my-project.elf CMSIS::STM32::F103C8 STM32::NoSys)
stm32_print_size_of_target(my-project.elf)
```

**main.c（已验证，PC13 Active Low + 软件延时）：**
```c
#include "stm32f1xx.h"

void Delay_ms(uint16_t ms) {
    uint16_t i, j;
    for (i = 0; i < ms; i++)
        for (j = 0; j < 4784; j++);
}

int main(void) {
    RCC->APB2ENR |= RCC_APB2ENR_IOPCEN;
    GPIOC->CRH &= ~GPIO_CRH_CNF13;
    GPIOC->CRH |= GPIO_CRH_MODE13_0 | GPIO_CRH_MODE13_1;

    while (1) {
        GPIOC->BSRR = GPIO_BSRR_BR13;   // PC13 LOW  = LED 亮 (Active Low)
        Delay_ms(500);
        GPIOC->BSRR = GPIO_BSRR_BS13;   // PC13 HIGH = LED 灭
        Delay_ms(500);
    }
}
```

> 💡 **关于 PC13：** Blue Pill 的 LED 是 Active Low——`BR13`（Bit Reset）= LOW = 灯亮，`BS13`（Bit Set）= HIGH = 灯灭。

---

### 模式 B：HAL 库模式

**CMakeLists.txt：**
```cmake
cmake_minimum_required(VERSION 3.16)
set(CMAKE_TOOLCHAIN_FILE $ENV{HOME}/stm32-tools/stm32-cmake/cmake/stm32_gcc.cmake)
project(my-project C ASM)
stm32_fetch_cube(F1)
set(CMAKE_INCLUDE_CURRENT_DIR TRUE)

find_package(CMSIS COMPONENTS STM32F103C8 REQUIRED)
find_package(HAL COMPONENTS STM32F1 REQUIRED)        # 家族级

add_executable(my-project.elf main.c stm32f1xx_hal_conf.h)
target_link_libraries(my-project.elf
    HAL::STM32::F1::RCC      # 按外设逐个链接
    HAL::STM32::F1::GPIO
    HAL::STM32::F1::CORTEX
    CMSIS::STM32::F103C8
    STM32::NoSys
)
stm32_print_size_of_target(my-project.elf)
```

**main.c（HAL + HSE 优先 + HSI 兜底，已验证：72MHz 正常 1Hz 闪烁）：**
```c
#include "stm32f1xx_hal.h"

void SystemClock_Config(void) {
    RCC_OscInitTypeDef osc = {0};
    RCC_ClkInitTypeDef clk = {0};
    uint8_t hse_ok = 0;

    // 第1步：优先试 HSE 外部晶振 72MHz
    osc.OscillatorType = RCC_OSCILLATORTYPE_HSE;
    osc.HSEState = RCC_HSE_ON;
    osc.PLL.PLLState = RCC_PLL_ON;
    osc.PLL.PLLSource = RCC_PLLSOURCE_HSE;
    osc.PLL.PLLMUL = RCC_PLL_MUL9;

    if (HAL_RCC_OscConfig(&osc) == HAL_OK) {
        clk.ClockType = RCC_CLOCKTYPE_SYSCLK|RCC_CLOCKTYPE_HCLK|RCC_CLOCKTYPE_PCLK1|RCC_CLOCKTYPE_PCLK2;
        clk.SYSCLKSource = RCC_SYSCLKSOURCE_PLLCLK;
        clk.AHBCLKDivider = RCC_SYSCLK_DIV1;
        clk.APB1CLKDivider = RCC_HCLK_DIV2;
        clk.APB2CLKDivider = RCC_HCLK_DIV1;
        if (HAL_RCC_ClockConfig(&clk, FLASH_LATENCY_2) == HAL_OK)
            hse_ok = 1;
    }

    if (!hse_ok) {
        // 第2步：HSE 失败 → 回退 HSI 48MHz
        RCC->CR &= ~(RCC_CR_HSEON | RCC_CR_PLLON);
        while (RCC->CR & RCC_CR_PLLRDY);

        osc.OscillatorType = RCC_OSCILLATORTYPE_HSI;
        osc.HSIState = RCC_HSI_ON;
        osc.PLL.PLLSource = RCC_PLLSOURCE_HSI_DIV2;
        osc.PLL.PLLMUL = RCC_PLL_MUL12;
        HAL_RCC_OscConfig(&osc);
        HAL_RCC_ClockConfig(&clk, FLASH_LATENCY_1);
    }

    HAL_SYSTICK_Config(HAL_RCC_GetHCLKFreq() / 1000);
    HAL_SYSTICK_CLKSourceConfig(SYSTICK_CLKSOURCE_HCLK);
}

void SysTick_Handler(void) { HAL_IncTick(); }

int main(void) {
    HAL_Init();
    SystemClock_Config();
    __HAL_RCC_GPIOC_CLK_ENABLE();
    GPIO_InitTypeDef cfg = {0};
    cfg.Pin = GPIO_PIN_13; cfg.Mode = GPIO_MODE_OUTPUT_PP; cfg.Speed = GPIO_SPEED_FREQ_HIGH;
    HAL_GPIO_Init(GPIOC, &cfg);
    while (1) {
        HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);
        HAL_Delay(500);
    }
}
```

**stm32f1xx_hal_conf.h：** 从 `~/stm32-tools/stm32-cmake/examples/blinky/stm32f1xx_hal_conf.h` 复制。AI 创建 HAL 项目时自动生成。

> **关键规则：** 用了哪些 HAL 模块，就打开对应 `#define` 并按 `HAL::STM32::F1::<模块名>` 链接。
>
> **HAL 模式说明：**
> - 使用 **HSE 优先 + HSI 兜底** 模式（`HAL_RCC_OscConfig` 检查返回值，失败自动回退）
> - 时钟切换后需要重配 SysTick：`HAL_SYSTICK_Config(HAL_RCC_GetHCLKFreq()/1000)`
> - `find_package(HAL ...)` 是**家族级** `STM32F1`，不是设备级 `STM32F103C8`

---

## 外设 / 中间件配置指南

> **AI 无需记住所有外设配置。掌握以下发现方法，即可动态生成任意外设的代码。**

### 核心机制：stm32-cmake + ST HAL 覆盖所有外设

stm32-cmake 的 `FindHAL.cmake` 在配置时自动扫描 ST HAL 源码，生成了所有外设的 CMake target。命名规则：

```
HAL::STM32::<家族>::<模块名>
     │        │       └── RCC / GPIO / UART / TIM / SPI / I2C / DMA / ADC / ...
     │        └── F1 / F4 / F7 / L0 / L4 / H7 / G0 / G4 / ...
     └── 固定前缀
```

**模块名 = ST HAL 驱动文件名去掉前缀后的部分：**
`stm32f1xx_hal_uart.c` → `UART`
`stm32f1xx_hal_spi.c` → `SPI`
`stm32f1xx_hal_dma.c` → `DMA`

### AI 的自动发现流程

当用户提出需要某个外设时，AI 按以下步骤自动完成：

```
第1步：分析需求 → 确定模块名
  用户说"串口" → UART
  用户说"SPI"  → SPI
  用户说"I2C"  → I2C

第2步：查找 ST HAL API
  路径：build/_deps/stm32cubef1-src/Drivers/STM32F1xx_HAL_Driver/Inc/
  文件：stm32f1xx_hal_<模块>.h → 包含所有函数声明和结构体定义

第3步：修改 CMakeLists.txt
  find_package(HAL COMPONENTS STM32F1 REQUIRED)  ← 不变，家族级
  target_link_libraries(... HAL::STM32::F1::UART ...)  ← 加新外设

第4步：修改 hal_conf.h
  #define HAL_UART_MODULE_ENABLED  ← 去掉注释

第5步：生成用户代码
  参考 HAL API 文档和 CubeMX 的典型用法，生成初始化和服务函数
```

### STM32F1 HAL 模块完整列表

以下列出 stm32-cmake 自动发现的 F1 系列全部 HAL 模块，AI 可按需选取：

| 分类 | 模块名 | CMake Target | 功能 |
|------|--------|-------------|------|
| 系统 | RCC | `HAL::STM32::F1::RCC` | 时钟配置 |
| 系统 | GPIO | `HAL::STM32::F1::GPIO` | GPIO |
| 系统 | CORTEX | `HAL::STM32::F1::CORTEX` | NVIC/SysTick |
| 系统 | DMA | `HAL::STM32::F1::DMA` | DMA 传输 |
| 系统 | PWR | `HAL::STM32::F1::PWR` | 电源管理 |
| 外设 | UART | `HAL::STM32::F1::UART` | 串口 |
| 外设 | USART | `HAL::STM32::F1::USART` | 同步/异步串口 |
| 外设 | SPI | `HAL::STM32::F1::SPI` | SPI 总线 |
| 外设 | I2C | `HAL::STM32::F1::I2C` | I2C 总线 |
| 外设 | TIM | `HAL::STM32::F1::TIM` | 定时器/PWM |
| 外设 | ADC | `HAL::STM32::F1::ADC` | 模数转换 |
| 外设 | DAC | `HAL::STM32::F1::DAC` | 数模转换 |
| 外设 | CAN | `HAL::STM32::F1::CAN` | CAN 总线 |
| 外设 | RTC | `HAL::STM32::F1::RTC` | 实时时钟 |
| 外设 | IWDG | `HAL::STM32::F1::IWDG` | 独立看门狗 |
| 外设 | WWDG | `HAL::STM32::F1::WWDG` | 窗口看门狗 |
| 外设 | FLASH | `HAL::STM32::F1::FLASH` | Flash 操作 |
| 外设 | CRC | `HAL::STM32::F1::CRC` | CRC 校验 |
| 通信 | ETH | `HAL::STM32::F1::ETH` | 以太网 |
| 通信 | SD | `HAL::STM32::F1::SD` | SD 卡 |
| USB | HCD | `HAL::STM32::F1::HCD` | USB 主机 |
| USB | PCD | `HAL::STM32::F1::PCD` | USB 设备 |

### 中间件支持

stm32-cmake 原生支持集成以下中间件（在 `FindCMSIS.cmake` 中实现）：

| 中间件 | 引入方式 | 说明 |
|--------|---------|------|
| **FreeRTOS** | `find_package(CMSIS COMPONENTS STM32F103C8 RTOS::FreeRTOS REQUIRED)` | 自动下载 FreeRTOS 源码 |
| **FatFS** | 通过 CMSIS + HAL SD/SPI 手动集成 | 文件系统 |
| **lwIP** | 通过 HAL ETH + 手动集成 | TCP/IP 协议栈 |
| **USB Stack** | 通过 HAL PCD + 手动集成 | USB CDC/HID/MSC |

> 💡 **AI 的职责：** 根据用户需求，按上述发现流程组合 HAL 模块 + 中间件，生成 CMakeLists.txt、hal_conf.h、main.c。用户不需要知道具体的 CMake target 名称——AI 根据模块名规则自动推导。

### 时钟配置

| 参数 | HSI @ 48MHz（兜底方案） | HSE @ 72MHz（已验证） |
|------|------------------------|---------------------|
| 时钟源 | HSI 内部 8MHz RC | HSE 外部 8MHz 晶振（OSCIN/OSCOUT） |
| PLL 输入 | HSI/2 = 4MHz | HSE = 8MHz |
| PLLMUL | ×12 → 48MHz | ×9 → 72MHz |
| FLASH_LATENCY | 1 | 2 |
| 可靠性 | ✅ 100% | ✅ Blue Pill 验证通过 |
| 策略 | 兜底，确保不出问题 | 优先尝试，失败自动回退 HSI |

> 🔥 **最佳实践：HSE 优先 + HSI 兜底。** 先试外部晶振 72MHz → 如果 `HAL_RCC_OscConfig` 返回失败 → 自动回退到 HSI 48MHz。这样正品和克隆板都能跑，晶振好坏无所谓。

---

## 编译

```bash
# 1. 配置（路径 A 和 B 完全相同）
cmake -S . -B build -G Ninja -DCMAKE_MAKE_PROGRAM=ninja

# 2. 编译
cmake --build build

# 3. 生成 .bin（路径 B st-flash 烧录需要）
arm-none-eabi-objcopy -O binary build/my-project.elf build/my-project.bin
```

> 首次编译时 `stm32_fetch_cube()` 自动从 ST GitHub 下载 CMSIS + HAL，约 30-60 秒。后续编译增量编译很快。
>
> **前置条件：** `~/stm32-tools/stm32-cmake/` 已全局安装（见"首次初始化"）。每个项目不再需要自己 clone。
>
> 🔥 **ELF vs BIN 说明：**
> | 工具 | 支持 ELF？ | 说明 |
> |------|-----------|------|
> | **OpenOCD** | ✅ 自动解析 ELF segments | `flash write_image xxx.elf` 正确 |
> | **CubeProgrammer** | ✅ 自动解析 | `-w xxx.elf` 正确 |
> | **st-flash** | ❌ **把 ELF 文件头原样写入 flash** | 必须 `objcopy -O binary` 先转 `.bin`！ |

---

## 烧录

### 路径 A：CubeProgrammer CLI（CubeIDE 已安装）

优势：驱动已配好，即装即用。

```bash
# 定位 CubeProgrammer
CUBEIDE_ROOT=$(ls -d /c/ST/*/STM32CubeIDE /d/ST/*/STM32CubeIDE 2>/dev/null | head -1)
PROGRAMMER=$(ls "$CUBEIDE_ROOT/plugins/com.st.stm32cube.ide.mcu.externaltools.cubeprogrammer.win32_"*/tools/bin/STM32_Programmer_CLI.exe 2>/dev/null | head -1)

# 三步烧录
"$PROGRAMMER" -c port=SWD                              # 1. 连接
"$PROGRAMMER" -c port=SWD -w build/my-project.elf -v   # 2. 写入+校验
"$PROGRAMMER" -c port=SWD -rst -run                     # 3. 复位运行
```

---

### 路径 B：OpenOCD / st-flash（纯 CLI，无 CubeIDE）

#### 前置：ST-Link 驱动修复（Windows 需要，参考经验）

> **仅 Windows + 克隆版 ST-Link 可能需要。** 原装 ST-Link 在 Windows 上装 ST 官方驱动即可。macOS / Linux 免驱。
> 以下 Zadig 操作来自克隆版 ST-Link V2 的实测经验。

**参考操作（仅当设备管理器中 ST-Link 显示为未知设备或 VID:PID 异常时）：**
1. 下载 [Zadig](https://zadig.akeo.ie/)（≈5MB，无需安装）
2. 插上 ST-Link，打开 Zadig
3. **Options → List All Devices**（勾上）
4. 下拉列表找 **STM32 STLink**（或 `VID_0483&PID_3748`）
5. 驱动选 **libusbK** → 点 **Replace Driver**

**驱动兼容性（经验参考，克隆版 ST-Link V2 实测）：**

| 驱动 | OpenOCD | st-flash | 说明 |
|------|---------|----------|------|
| **libusbK** | ✅ 稳定（检测/解锁/擦除） | ❌ LIBUSB_ERROR_TIMEOUT | 适用于 OpenOCD |
| **WinUSB** | ⚠️ 不稳定 | ✅ 可用（烧录） | 适用于 st-flash |

> 💡 **以上驱动兼容性来自克隆版 ST-Link V2 + CS32 芯片的实测。原装 ST-Link 用 ST 官方驱动最稳定。**

#### B-1：OpenOCD（检测 + 解锁 + 擦除）

```bash
# 安装
pacman -S --needed mingw-w64-x86_64-openocd

# 验证连接
openocd -f interface/stlink.cfg -f target/stm32f1x.cfg \
    -c "adapter speed 5" -c "init" -c "reset halt" -c "shutdown"
# 期望: Cortex-M3 r1p1 processor detected, flash size = 64 KiB
```

#### B-2：st-flash（烧录工具）

> **以下模板在克隆版 ST-Link V2 + CS32 芯片上验证通过。** st-flash 使用 ST-Link 原生 flash 协议，对克隆芯片的兼容性优于 OpenOCD（OpenOCD 加载写算法到 RAM 时可能通信失败）。
>
> 🔥🔥🔥 **重要：st-flash 需要 `.bin` 格式，不能直接烧 `.elf`！**
> 
> `st-flash write xxx.elf` 会把 **ELF 文件头原样写入 flash**（hexdump 读回来是 `7F 45 4C 46` = `"ELF"`），CPU 上电读到垃圾 SP/PC，**程序完全不执行但在 st-flash 里显示 verified OK**。
> 
> **必须先用 `arm-none-eabi-objcopy` 转 raw binary：**

```bash
# 安装
pacman -S --needed mingw-w64-x86_64-stlink

# 🔥 关键步骤：ELF → 裸二进制（缺此步程序不执行！）
arm-none-eabi-objcopy -O binary build/my-project.elf build/my-project.bin

# 探测芯片
st-info --probe
# 期望: chipid: 0x0410, dev-type: STM32F1xx_MD

# 烧录 .bin（不是 .elf！）
st-flash --reset write build/my-project.bin 0x08000000

# 烧录 .bin（不 reset，配合 BOOT0=1 使用）
st-flash write build/my-project.bin 0x08000000

# 验证 Flash 内容是否写入正确（读回前 32 字节）
st-flash read /tmp/dump.bin 0x08000000 0x20
hexdump -C /tmp/dump.bin | head -3
# ✅ 正确: 00 50 00 20 xx xx 00 08 ...  (SP=0x20005000, PC=0x0800xxxx)
# ❌ 错误: 7F 45 4C 46 01 01 01 00 ...  (= ELF 文件头，程序不跑)
```

> **成功标志：** `Flash written and verified! jolly good!` + 读回验证向量表正确。

#### 烧录流程（参考，根据硬件调整）

```
# 6 针 ST-Link（含 NRST）：
st-flash --reset write build/my-project.bin 0x08000000
# 然后重新上电即可

# 4 针 ST-Link（无 NRST，如 Blue Pill）——旧芯片 SWD 被锁时：
1. BOOT0=1, 上电（进入 bootloader）
2. libusbK + OpenOCD → unlock + mass_erase
3. 切到 WinUSB + st-flash write .bin
4. BOOT0=0, 重新上电 → 程序运行

# 4 针 ST-Link（无 NRST）——新芯片 / 正常芯片：
st-flash write build/my-project.bin 0x08000000
# BOOT0=0 → 重新上电
```

---
## 🔥 SWD / 烧录问题排查（参考经验）

> ⚠️ **以下问题与解决方案均来自特定硬件的实测，不能作为通用标准。** AI 必须先确认用户的硬件配置（步骤三），再从中选取可能相关的条目。

### 路径 B 可能遇到的问题

| # | 现象 | 根本原因 | 解决步骤 |
|---|------|---------|---------|
| 1 | `VID:PID 0000:0000` 或 `init mode failed` | CubeIDE 卸载后驱动破损 | 设备管理器卸载设备 → Zadig 选 libusbK → Replace Driver |
| 2 | `LIBUSB_ERROR_TIMEOUT` | 驱动不匹配 | Zadig 切换到另一个驱动（libusbK ↔ WinUSB） |
| 3 | `Couldn't find any ST-Link devices` | USB 无驱动 | Zadig 安装 libusbK 或 WinUSB |
| 4 | `chipid: 0x000` + `Failed to enter SWD mode` | SWD 被用户程序锁死 | 见下方"救砖流程" → OpenOCD unlock + mass_erase |
| 5 | `NRST is not connected` | 4 针 ST-Link 无 RST 线 | 无需硬件 RST — 用 BOOT0 救砖替代 |
| 6 | `jtag status...communication failure` (OpenOCD 写 flash) | **克隆版 CS32 芯片** flash 写算法不兼容 | 切到 WinUSB + st-flash 写入（ST 原生协议） |
| 7 | `Flash written and verified` 但程序不跑 | **st-flash 烧了 .elf**（ELF 文件头被当成代码写入 flash） | `arm-none-eabi-objcopy -O binary xxx.elf xxx.bin` 后烧 .bin |
| 8 | 烧录后程序不跑（其他原因） | BOOT0 仍为 1 | BOOT0 跳回 0，重新上电 |
| 9 | 程序跑但 `HAL_Delay` 不工作，LED 常亮 | 切换 PLL 后未重配 SysTick | 加 `HAL_SYSTICK_Config(HAL_RCC_GetHCLKFreq()/1000)` + `SysTick_Handler` |
| 10 | HAL 版 LED 常灭，寄存器版却正常 | HSE 外部晶振不起振 | 改用 HSI 时钟（见时钟配置表） |

### 4 针 ST-Link 无 NRST 时的救砖方法（经验参考）

> ⚠️ **仅适用于特定硬件。** 如果你的 ST-Link 有 6 针（含 NRST），直接用硬件复位即可，无需以下操作。
> 以下方法来自 Blue Pill（4 针 SWD + BOOT0 跳线帽）的实测经验。

```
1. 断电（拔 USB）
2. BOOT0 跳线帽 → 1, BOOT1 跳线帽 → 0（进入系统 bootloader）
3. 重新上电（此时 SWD 被 bootloader 释放）
4. libusbK + OpenOCD → unlock + mass_erase（清除旧固件，释放 SWD）
5. 断电（不拔 USB，SWD 保持在 bootloader 模式）
6. 切驱动 WinUSB + st-flash → 烧录新固件
7. 断电 → BOOT0 跳回 0 → 重新上电 → 程序运行
```

> ⚠️ **BOOT1 必须为 0。** BOOT1=1 + BOOT0=1 进入 SRAM 启动（SRAM 为空则行为不可预测）→ SWD 同样连不上。
>
> 💡 **为什么分两步（libusbK 擦除 → WinUSB 烧录）？**
> 克隆版 ST-Link 搭配的 CS32 芯片与 OpenOCD 的 flash 写算法不兼容（`jtag status contains invalid mode value`）。但 st-flash 使用 ST-Link 的专有 flash 协议绕过此问题。所以用 OpenOCD 擦除，st-flash 写入。

### 路径 A 与路径 B 的烧录对比（经验参考）

| | 路径 A (CubeProgrammer) | 路径 B (st-flash) |
|---|---|---|
| 驱动 | ST 专有（自动装好） | WinUSB（Windows 需 Zadig one-time） |
| 6 针含 NRST | ✅ 一键烧录 | ✅ 一键烧录 |
| 4 针无 NRST | ❌ 需 NRST | ✅ 可通过 BOOT0 救砖 |

### 验证连接成功的标志

| 工具 | 成功标志 |
|------|---------|
| OpenOCD | `Cortex-M3 r1p1 processor detected` + `flash size = 64 KiB` |
| st-info | `chipid: 0x0410` + `dev-type: STM32F1xx_MD` |
| CubeProgrammer | `Target voltage: 3.xxV` + 无 error |

---

## 芯片型号速查

| 系列 | 芯片 | Flash | RAM | 封装 | CMSIS 类型 |
|------|------|-------|-----|------|-----------|
| F1 | F103C8 | 64KB | 20KB | LQFP48 | F103xB |
| F1 | F103CB | 128KB | 20KB | LQFP48 | F103xB |
| F1 | F103RC | 256KB | 48KB | LQFP64 | F103xE |
| F1 | F103ZE | 512KB | 64KB | LQFP144 | F103xG |
| L4 | L431VCTx | 256KB | 64KB | LQFP100 | L431xx |
| L4 | L476RGTx | 1MB | 128KB | LQFP64 | L476xx |
| F4 | F407VGT6 | 1MB | 192KB | LQFP100 | F407xx |
| F4 | F429ZIT6 | 2MB | 256KB | LQFP144 | F429xx |

---

---

## 🔥 已验证完整流程（路径 B，纯 CLI，仅供参考）

> ⚠️ **此流程是特定硬件的成功记录，不是通用 SOP。** 验证硬件：Windows MSYS2 + 克隆版 ST-Link V2 + CS32 芯片 + Blue Pill (F103C8T6, 4针无NRST, 8MHz HSE晶振, PC13 LED Active Low)。
> 
> **验证结果：** CMSIS 寄存器模式 ✅ / HAL 模式 (HSE 72MHz) ✅ / `HAL_Delay(500)` = 1Hz ✅
>
> **如果你的硬件不同（6 针含 NRST、原装 ST-Link、不同 LED 引脚等），AI 会根据你的实际配置生成定制流程。**

```bash
# ===== 一次性环境准备（整个电脑做一次） =====
# Windows (MSYS2):
pacman -S --needed \
    mingw-w64-x86_64-arm-none-eabi-gcc \
    mingw-w64-x86_64-cmake \
    mingw-w64-x86_64-ninja \
    mingw-w64-x86_64-stlink
# macOS:
# brew install --cask gcc-arm-embedded && brew install cmake ninja stlink
# Linux:
# sudo apt install -y gcc-arm-none-eabi cmake ninja-build stlink-tools

export PATH="$PATH"  # 确保 arm-none-eabi-gcc/cmake/ninja/st-flash 在 PATH
mkdir -p ~/stm32-tools
git clone --depth=1 https://github.com/ObKo/stm32-cmake.git ~/stm32-tools/stm32-cmake
# Windows only: Zadig → STM32 STLink → WinUSB → Replace Driver

# ===== 每次创建项目 =====
# 在工作目录下，编写 CMakeLists.txt + main.c
# CMakeLists.txt 第一行必须是: set(CMAKE_TOOLCHAIN_FILE $ENV{HOME}/stm32-tools/...)

# ===== 编译 =====
cmake -S . -B build -G Ninja -DCMAKE_MAKE_PROGRAM=ninja
cmake --build build

# ===== 烧录 =====
arm-none-eabi-objcopy -O binary build/my-project.elf build/my-project.bin
st-flash write build/my-project.bin 0x08000000

# ===== 运行 =====
# BOOT0=0 → 拔 USB → 再插上 → LED 闪烁！
```

**硬件接线：** ST-Link(SWDIO→SWIO)+(SWCLK→SWCLK)+(GND→GND)+(3V3→3V3)，共 4 线。

## 参考资源

- [ObKo/stm32-cmake](https://github.com/ObKo/stm32-cmake) — CMake 框架（MIT 开源）
- [ST GitHub](https://github.com/STMicroelectronics) — HAL/CMSIS 源码（`stm32_fetch_cube()` 自动拉取）
- [Zadig](https://zadig.akeo.ie/) — USB 驱动管理（路径 B 必需）
- [OpenOCD](https://openocd.org/) — 开源调试/烧录
- [ARM GNU Toolchain](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads)
