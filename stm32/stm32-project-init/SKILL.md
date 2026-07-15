---
name: "stm32-project-init"
description: "Initialize a new STM32 development project. 交互式收集芯片型号、开发模式（HAL/CMSIS, C/C++）、时钟方案、外设需求，生成 CMakeLists.txt 和 hal_conf.h，编译验证，烧录。Call after stm32-dev-setup is complete."
---

# STM32 项目初始化

引导用户通过人机交互方式完成新项目的创建、配置、编译和烧录。

> 跨平台支持：**Windows** / **macOS** / **Linux**。
> 先确保 `stm32-dev-setup` 已完成。

---

## Pre-flight: 确保开发环境到位

```bash
arm-none-eabi-gcc --version 2>/dev/null | head -1
cmake --version 2>/dev/null | head -1
ls ~/stm32-tools/stm32-cmake/cmake/stm32_gcc.cmake 2>/dev/null
```

| 检查项 | 缺失时的操作 |
|--------|-------------|
| `arm-none-eabi-gcc` 缺失 | 调用 `stm32-dev-setup` |
| `~/stm32-tools/stm32-cmake` 缺失 | 调用 `stm32-dev-setup` |

---

## Step 1: 芯片型号

```
AI: "请确认你的 STM32 芯片型号（看芯片表面丝印）？"
示例回答: "STM32L431VCTx" / "STM32F103C8T6"
```

> 从丝印可以确定：Flash 大小、RAM 大小、封装。常见型号见文末[芯片型号速查](#芯片型号速查)。

---

## Step 2: 开发模式（核心决策）

```
AI: "你希望用哪种方式开发？"

┌──────────────────────────────────────────────────────────────┐
│ [1] HAL 库 + C        ← 推荐新手/快速开发                  │
│     入口 main.c  │  project(C C ASM)  │  需 hal_conf.h      │
│                                                             │
│ [2] HAL 库 + C++      ← 面向对象封装 HAL                    │
│     入口 main.cpp │  project(C CXX ASM)│  需 hal_conf.h     │
│     ⚠️ HAL 回调必须 extern "C"                             │
│                                                             │
│ [3] CMSIS 寄存器 + C  ← 极致精简、学习底层                  │
│     入口 main.c  │  project(C ASM)    │  无需 hal_conf.h    │
│                                                             │
│ [4] CMSIS 寄存器 + C++ ← C++ 风格底层编程                   │
│     入口 main.cpp │  project(C CXX ASM)│  无需 hal_conf.h   │
│     ISR 必须 extern "C"                                     │
└──────────────────────────────────────────────────────────────┘
```

### 四种模式的 CMakeLists.txt 关键差异

| 配置项 | HAL + C | HAL + C++ | CMSIS + C | CMSIS + C++ |
|--------|---------|-----------|-----------|-------------|
| `project(...)` | `C C ASM` | `C CXX ASM` | `C ASM` | `C CXX ASM` |
| `find_package(HAL)` | ✅ 必需 | ✅ 必需 | ❌ | ❌ |
| `hal_conf.h` | ✅ 必需 | ✅ 必需 | ❌ | ❌ |
| 入口文件 | `main.c` | `main.cpp` | `main.c` | `main.cpp` |
| `extern "C"` ISR | 不需要 | ✅ 必需 | 不需要 | ✅ 必需 |

---

## Step 3: 时钟配置

```
AI: "期望的系统主频是多少？使用什么时钟源？"
```

### 时钟配置速查

| 系列 | 可用内部时钟 | PLL 输入范围 | VCO 范围 | 最高主频 |
|------|------------|-------------|---------|---------|
| STM32F1 | HSI 8MHz | 4-16MHz | — | 72MHz |
| STM32F4 | HSI 16MHz | 1-2MHz | 100-432MHz | 168MHz |
| STM32L4 | MSI 100k-48M / HSI 16MHz | 4-16MHz | 64-344MHz | 80MHz |
| STM32G0 | HSI 16MHz | 2.66-8MHz | 96-344MHz | 64MHz |
| STM32H7 | HSI 64MHz | 1-16MHz | 150-836MHz | 550MHz |

### 常用时钟方案

| 方案 | 芯片 | PLL 链 | 结果 | FLASH_LATENCY |
|------|------|--------|------|---------------|
| MSI 内部 | STM32L4 | MSI 4M /1 ×40 /2 | **80MHz** | 4 |
| HSI 内部 | STM32F1 | HSI 8M /2 ×12 | **48MHz** | 1 |
| HSE 外部 | STM32F1 | HSE 8M ×9 | **72MHz** | 2 |
| HSI 内部 | STM32G0 | HSI 16M /1 ×8 /2 | **64MHz** | 2 |

### PLL 计算公式

```
PLL_IN  = PLL_SRC / PLLM          → 必须落在 PLL 输入范围内
PLL_VCO = PLL_IN * PLLN           → 必须落在 VCO 范围内
PLL_R   = PLL_VCO / PLLR          → SYSCLK（系统主频）
```

### STM32L4 电压缩放

```c
// L4 系列 80MHz 必须先设置电压等级
HAL_PWREx_ControlVoltageScaling(PWR_REGULATOR_VOLTAGE_SCALE1);
// SCALE1 支持 ≤ 80MHz  │  SCALE2 支持 ≤ 26MHz
```

---

## Step 4: 中间件选择

```
AI: "需要 RTOS 吗？"
```

| 中间件 | 引入方式 |
|--------|---------|
| **FreeRTOS** | `find_package(CMSIS COMPONENTS {chip} RTOS::FreeRTOS REQUIRED)` |
| **FatFS** | 通过 CMSIS + HAL SD/SPI 手动集成 |
| **lwIP** | 通过 HAL ETH + 手动集成 |
| **USB Stack** | 通过 HAL PCD + 手动集成 |

> ⚠️ 使用 FreeRTOS 时，HAL 时基不能再使用 SysTick（FreeRTOS 占用），需用硬件定时器替代。

---

## Step 5: 外设配置

```
AI: "需要哪些外设？"
示例回答: "UART1, PA9/PA10, 115200"  或  "SPI1 + TIM3 CH1 PWM"
可一次列出多个。
```

> AI 根据回答自主判断是否追问具体引脚、波特率等参数。

---

## Step 6: 确认 + 生成项目

```
AI 完成交互后，输出配置汇总并让用户确认：

  ── 项目配置汇总 ──
  芯片    : STM32L431VCTx
  模式    : HAL + C++
  时钟    : MSI 4MHz → PLL 80MHz
  中间件  : 无
  外设    : UART1 (PA9/PA10, 115200) + GPIO (PB0, 推挽输出)

  确认以上配置？我将开始生成 CMakeLists.txt 和 hal_conf.h。
```

---

## Step 7: 生成项目框架

### 目录结构

```
<project>/
├── CMakeLists.txt
├── code/
│   ├── include/
│   │   └── stm32xxx_hal_conf.h    ← HAL 模式必需
│   └── src/
│       └── main.c / main.cpp       ← 按开发模式
└── build/                           ← cmake -B build 自动生成
```

### CMakeLists.txt 模板（按 4 种模式生成）

#### 模式 1: HAL + C

```cmake
cmake_minimum_required(VERSION 3.22)
set(CMAKE_TOOLCHAIN_FILE "$ENV{HOME}/stm32-tools/stm32-cmake/cmake/stm32_gcc.cmake")
project(my-project C C ASM)
stm32_fetch_cube({FAMILY})
find_package(CMSIS COMPONENTS {CHIP} REQUIRED)
find_package(HAL COMPONENTS {FAMILY} REQUIRED)
file(GLOB_RECURSE PROJECT_SOURCES code/src/*.c)
add_executable(${PROJECT_NAME} ${PROJECT_SOURCES})
target_include_directories(${PROJECT_NAME} PRIVATE code/include)
target_link_libraries(${PROJECT_NAME} PRIVATE
    CMSIS::STM32::{TYPE}
    HAL::STM32::{FAMILY}
    STM32::NoSys
    # 按启用的外设添加 HAL modules
)
```

#### 模式 2: HAL + C++（外设同上，额外加 C++ 选项）

```cmake
project(my-project C CXX ASM)           # ⚠️ 必须包含 C
file(GLOB_RECURSE PROJECT_SOURCES code/src/*.cpp)
target_compile_options(${PROJECT_NAME} PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:-std=c++17>
    $<$<COMPILE_LANGUAGE:CXX>:-fno-rtti>
    $<$<COMPILE_LANGUAGE:CXX>:-fno-exceptions>
    $<$<COMPILE_LANGUAGE:CXX>:-fno-threadsafe-statics>
)
```

#### 模式 3: CMSIS + C

```cmake
project(my-project C ASM)
stm32_fetch_cube({FAMILY})
find_package(CMSIS COMPONENTS {CHIP} REQUIRED)
# 不加 find_package(HAL)
target_link_libraries(${PROJECT_NAME} PRIVATE
    CMSIS::STM32::{TYPE}
    STM32::NoSys
)
```

#### 模式 4: CMSIS + C++（同 CMSIS+C + C++编译选项）

### hal_conf.h（HAL 模式必需）

从 `~/stm32-tools/stm32-cmake/examples/` 下对应家族的模板复制，根据启用的外设**去掉对应 `#define` 注释**。

```c
// 示例：启用 UART 和 DMA
#define HAL_UART_MODULE_ENABLED
#define HAL_DMA_MODULE_ENABLED     // ⚠️ UART 驱动内部引用 DMA

// STM32L4 必须定义完整振荡器值
#define HSE_VALUE    8000000U
#define HSI_VALUE    16000000U
#define MSI_VALUE    4000000U
#define LSE_VALUE    32768U
```

---

## Step 8: 编译

```bash
cmake -S . -B build -G Ninja
cmake --build build 2>&1
# 首次编译时 stm32_fetch_cube() 自动下载 CMSIS+HAL，约 30-60 秒
```

> **CMakeLists.txt 编译通过后，AI 才开始写 code/src/main.c(pp)。**

---

## Step 9: 应用代码（按模式生成模板）

### HAL + C 入口

```c
#include "stm32xxx_hal.h"

static void SystemClock_Config(void) { /* 根据时钟配置生成 */ }

int main(void) {
    HAL_Init();
    SystemClock_Config();
    /* 外设 init */
    while (1) { /* 用户逻辑 */ }
}
```

### HAL + C++ 入口

```cpp
#include "stm32xxx_hal.h"

// ⚠️ ISR 和 HAL 回调必须 extern "C"
extern "C" void SysTick_Handler(void) { HAL_IncTick(); }

int main(void) {
    HAL_Init();
    /* 时钟 + 外设 init（含电压缩放等） */
    while (1) { /* 用户逻辑 */ }
}
```

### CMSIS + C 入口

```c
#include "stm32f1xx.h"

static void delay_ms(uint32_t ms) {
    SysTick->LOAD = 72000 - 1;
    SysTick->VAL = 0;
    SysTick->CTRL = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_ENABLE_Msk;
    for (uint32_t i = 0; i < ms; i++) {
        while ((SysTick->CTRL & SysTick_CTRL_COUNTFLAG_Msk) == 0);
    }
    SysTick->CTRL = 0;
}

int main(void) {
    RCC->APB2ENR |= RCC_APB2ENR_IOPCEN;
    GPIOC->CRH &= ~(0xF << 20);
    GPIOC->CRH |= (0x3 << 20);   // PC13 推挽输出
    while (1) {
        GPIOC->ODR ^= (1 << 13);
        delay_ms(500);
    }
}
```

### CMSIS + C++ 入口

```cpp
#include "stm32f1xx.h"
extern "C" void SysTick_Handler(void) {}
int main(void) {
    RCC->APB2ENR |= RCC_APB2ENR_IOPCEN;
    /* 寄存器操作 */
    while (1) { /* ... */ }
}
```

---

## Step 10: 烧录

### 路径 A（CubeProgrammer CLI）

```bash
CUBEIDE_ROOT=$(ls -d /c/ST/*/STM32CubeIDE /d/ST/*/STM32CubeIDE 2>/dev/null | head -1)
PROGRAMMER=$(ls "$CUBEIDE_ROOT/plugins/.../cubeprogrammer..."_*/tools/bin/STM32_Programmer_CLI.exe | head -1)
"$PROGRAMMER" -c port=SWD -w build/my-project.elf -v -rst -run
```

### 路径 B（st-flash）

```bash
arm-none-eabi-objcopy -O binary build/my-project.elf build/my-project.bin
st-flash --reset write build/my-project.bin 0x08000000
```

> 🔥 **st-flash 必须烧 `.bin` 不是 `.elf`！** 烧 `.elf` 会把 ELF 头写入 flash，CPU 读到垃圾 SP/PC，程序完全不执行但显示 verified OK。

### 硬件接线

```
ST-Link                    目标板
SWDIO  ────────────────→  SWDIO
SWCLK  ────────────────→  SWCLK
GND    ────────────────→  GND
3.3V   ────────────────→  3.3V（如不独立供电）
```

---

## 外设模块速查

> HAL 模块名 = HAL 驱动文件名去掉前缀后全大写。如 `stm32l4xx_hal_uart.c` → `HAL::STM32::L4::UART`

| 分类 | 模块 | CMake Target |
|------|------|-------------|
| 必选 | RCC / GPIO / CORTEX / DMA / FLASH / PWR | `HAL::STM32::{F}::{MOD}` |
| 通信 | UART / USART / SPI / I2C / CAN | `HAL::STM32::{F}::{MOD}` |
| 定时 | TIM / RTC | `HAL::STM32::{F}::{MOD}` |
| 模拟 | ADC / DAC | `HAL::STM32::{F}::{MOD}` |
| 看门狗 | IWDG / WWDG | `HAL::STM32::{F}::{MOD}` |
| 存储 | SD / QSPI | `HAL::STM32::{F}::{MOD}` |
| USB | PCD | `HAL::STM32::{F}::PCD` |
| 扩展 | RCCEx / PWREx | `HAL::STM32::{F}::{MOD}` |

---

## 芯片型号速查

| 系列 | 芯片 | Flash | RAM | 封装 | CMSIS 类型 |
|------|------|-------|-----|------|-----------|
| F1 | F103C8T6 | 64KB | 20KB | LQFP48 | F103xB |
| F1 | F103RCT6 | 256KB | 48KB | LQFP64 | F103xE |
| F1 | F103VCT6 | 512KB | 64KB | LQFP100 | F103xG |
| L4 | L431VCTx | 256KB | 64KB | LQFP100 | L431xx |
| L4 | L476RGTx | 1MB | 128KB | LQFP64 | L476xx |
| F4 | F407VGT6 | 1MB | 192KB | LQFP100 | F407xx |
| F4 | F429ZIT6 | 2MB | 256KB | LQFP144 | F429xx |

---

## 故障排错

### 编译错误

| # | 报错 | 原因 | 修复 |
|---|------|------|------|
| 1 | `UART_HandleTypeDef undeclared` | hal_conf.h 中对应 `#define` 被注释 | 去注释 |
| 2 | `undefined reference to HAL_xxx` | CMakeLists 未链接对应 HAL module | 添加 `HAL::STM32::{F}::xxx` |
| 3 | `cannot find -lSTM32::NoSys` | 未链接 NoSys | 添加 `STM32::NoSys` |
| 4 | `fatal error: stm32xxx_hal.h` | include 路径不对 | `target_include_directories` |
| 5 | `'-std=c++17' is valid for C++ but not for C` | C++ 选项传给 C | 用 `$<$<COMPILE_LANGUAGE:CXX>:...>` |
| 6 | C++ 项目 `undefined reference to HAL_xxx` | project 只写了 CXX 没 C | 改为 `project(... C CXX ASM)` |
| 7 | `XferAbortCallback` not in struct | DMA 模块未启用 | hal_conf.h 中启用 `HAL_DMA_MODULE_ENABLED` |

### 运行时问题

| # | 现象 | 原因 | 修复 |
|---|------|------|------|
| 8 | `HAL_Delay` 不工作 | PLL 后 SysTick 未重配 | `HAL_SYSTICK_Config(HAL_RCC_GetHCLKFreq()/1000)` |
| 9 | L4 PLL 80MHz 死机 | 未设置电压等级 | `HAL_PWREx_ControlVoltageScaling(SCALE1)` |
| 10 | 烧录 verified 但程序不跑 | st-flash 烧了 .elf | `objcopy -O binary` 后烧 .bin |
| 11 | 串口乱码 | 时钟配置与实际不符 | 检查 `SystemClock_Config` |
| 12 | FreeRTOS + HAL_Delay 都不工作 | HAL 时基用 SysTick（被 FreeRTOS 占用） | 改为硬件定时器 |

### 烧录问题

| # | 现象 | 修复 |
|---|------|------|
| 13 | `chipid: 0x000` + `Failed to enter SWD` | SWD 被锁。断电 → BOOT0=1 上电 → 擦除 → BOOT0=0 |
| 14 | `st-flash` LIBUSB_ERROR_TIMEOUT | 检查 ST-Link 驱动 |
