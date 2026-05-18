---
name: "stm32-dev"
description: "STM32 embedded development guide - cross-platform (Windows/macOS/Linux), supports both CubeIDE and pure CLI paths. No CubeMX required."
---

# STM32 开发指南

> 跨平台支持：**Windows** / **macOS** / **Linux**。
> 两条路径任选：**路径 A**（CubeIDE 已安装）或 **路径 B**（纯 CLI，全部开源）。

---

## 一、执行流程总览

```
Shell检测 → 工具链安装 → 路径判断 → 交互配置 → CMakeLists.txt → 编译验证 → 应用代码 → 烧录
```

---

## 二、第零步：环境检测（全局一次）

### Shell 检测（Windows 必须）

> **AI 必须先检测当前 Shell 环境。** Windows 下 stm32-cmake 工具链依赖 MSYS2 环境，PowerShell / CMD 无法正常使用 `pacman` 安装工具链。

```
AI 操作流程:
1. 执行 uname -s 检测当前环境
2. 根据结果判断:
```

| `uname -s` 输出 | 平台/Shell | AI 动作 |
|-----------------|-----------|---------|
| `MSYS_NT-*` | Windows + MSYS2 ✅ | 继续工具链检测 |
| `MINGW64_NT-*` | Windows + MSYS2 ✅ | 继续工具链检测 |
| `Linux` | Linux ✅ | 继续工具链检测 |
| `Darwin` | macOS ✅ | 继续工具链检测 |
| **其他** (含 PowerShell 执行失败) | **Windows 非 MSYS2** ❌ | **引导安装 MSYS2** |

#### Windows 用户不在 MSYS2 环境时的处理

> **AI 检测到非 MSYS2 环境时，输出以下引导信息：**

```
AI 向用户输出:

"检测到你当前不在 MSYS2 环境中。STM32 开发工具链需要通过 MSYS2 安装和管理。

请按以下步骤安装 MSYS2:

1. 下载安装包: https://www.msys2.org/
   运行安装程序，默认安装到 C:\msys64

2. 安装完成后，从开始菜单启动 「MSYS2 UCRT64」

3. 在 UCRT64 终端中验证:
   uname -s          # 应输出 MINGW64_NT-* 或 MSYS_NT-*
   pacman --version  # 确认包管理器可用

4. 然后在 UCRT64 终端中重新执行本 Skill

安装完成后告诉我，我会继续环境检测。"
```

> **⚠️ 重要：** 后续所有 `pacman`、`arm-none-eabi-gcc`、`cmake`、`ninja`、`st-flash` 命令都必须在 MSYS2 UCRT64 终端中执行。不要尝试在 PowerShell 中安装这些工具。

### 工具链安装

| 平台 | 推荐 Shell | 安装命令（一次） |
|------|-----------|---------|
| **Windows** | **MSYS2 UCRT64** | `pacman -S --needed mingw-w64-x86_64-arm-none-eabi-gcc mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja mingw-w64-x86_64-stlink mingw-w64-x86_64-openocd` |
| **macOS** | Terminal + Homebrew | `brew install --cask gcc-arm-embedded && brew install cmake ninja stlink openocd` |
| **Linux (apt)** | 系统 Terminal | `sudo apt install -y gcc-arm-none-eabi cmake ninja-build stlink-tools openocd` |

### 路径判断

```bash
# 检测 CubeIDE（Windows only，路径 A）
ls -d /c/ST/STM32CubeIDE_*/STM32CubeIDE/STM32CubeIDE.exe 2>/dev/null

# 检测系统工具链
arm-none-eabi-gcc --version 2>/dev/null | head -1
cmake --version 2>/dev/null | head -1
ninja --version 2>/dev/null
```

| 条件 | 路径 | 说明 |
|------|------|------|
| CubeIDE 已安装 | **路径 A** | 取其内置 arm-gcc + cmake + CubeProgrammer |
| 无 CubeIDE + 工具链就绪 | **路径 B** | 纯 CLI，全部开源 |
| 无 CubeIDE + 工具链缺失 | **先装工具链 → 路径 B** | 按上表选一条命令 |

**路径 A 工具链定位（Windows）：**
```bash
CUBEIDE_ROOT=$(ls -d /c/ST/*/STM32CubeIDE /d/ST/*/STM32CubeIDE 2>/dev/null | head -1)
GCC_DIR=$(ls -d "$CUBEIDE_ROOT/plugins/com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32."*".win32_"*/tools/bin 2>/dev/null | head -1)
CMAKE_DIR=$(ls -d "$CUBEIDE_ROOT/plugins/com.st.stm32cube.ide.mcu.externaltools.cmake.win32_"*/tools/bin 2>/dev/null | head -1)
export PATH="$GCC_DIR:$CMAKE_DIR:$PATH"
```

### stm32-cmake 初始化（全局一次）

```bash
mkdir -p ~/stm32-tools
git clone --depth=1 https://github.com/ObKo/stm32-cmake.git ~/stm32-tools/stm32-cmake
```

---

## 三、第一步：交互式项目配置

> **AI 逐条询问，应追问时追问。核心理念：理解用户需求后才能正确生成 CMakeLists.txt。**

### 0. 固件来源确认（编译前置条件）

> **⚠️ 必问！** 网络不通时 `stm32_fetch_cube()` 无法从 GitHub 下载 Cube 固件包，必须提前确认。

```
AI: "你的开发环境能否正常访问 GitHub？（编译时需要下载 STM32Cube 固件包）"

┌──────────────────────────────────────────────────────────────┐
│ [1] 网络正常（能访问 GitHub）                              │
│     → stm32_fetch_cube() 自动从 GitHub 下载 CMSIS+HAL       │
│     首次编译约 30-60 秒                                     │
│                                                             │
│ [2] 网络不通                                               │
│     → stm32-cmake 需要通过 GitHub 拉取固件源码              │
│     请确保网络畅通后再继续，或自行解决网络问题              │
└──────────────────────────────────────────────────────────────┘
```

### 1. 芯片型号

```
AI: "请确认你的 STM32 芯片型号（看芯片表面丝印）？"
示例回答: "STM32L431VCTx" / "STM32F103C8T6"
```

### 2. 开发模式（核心决策）

> **AI 必须明确确认开发模式。这决定了 CMakeLists.txt 的 `project()` 写法、入口文件后缀、C++ 链接约定、hal_conf.h 是否需要等。**

```
AI: "你希望用哪种方式开发？"

┌──────────────────────────────────────────────────────────────┐
│ [1] HAL 库 + C        ← 推荐新手/快速开发                  │
│     入口 main.c  │  project(C C ASM)  │  需 hal_conf.h      │
│                                                             │
│ [2] HAL 库 + C++      ← 面向对象封装 HAL                    │
│     入口 main.cpp │  project(C CXX ASM)│  需 hal_conf.h     │
│     ⚠️ HAL 回调必须 extern "C"  │ C++ 选项仅对 cpp 生效     │
│                                                             │
│ [3] CMSIS 寄存器 + C  ← 极致精简、学习底层                  │
│     入口 main.c  │  project(C ASM)    │  无需 hal_conf.h    │
│     直接操作寄存器，无 HAL 依赖                             │
│                                                             │
│ [4] CMSIS 寄存器 + C++ ← C++ 风格底层编程                   │
│     入口 main.cpp │  project(C CXX ASM)│  无需 hal_conf.h   │
│     ISR 必须 extern "C"  │  C++ 选项仅对 cpp 生效           │
└──────────────────────────────────────────────────────────────┘
```

**四种模式的 CMakeLists.txt 关键差异：**

| 配置项 | HAL + C | HAL + C++ | CMSIS + C | CMSIS + C++ |
|--------|---------|-----------|-----------|-------------|
| `project(...)` | `C C ASM` | `C CXX ASM` | `C ASM` | `C CXX ASM` |
| `find_package(HAL)` | ✅ 必需 | ✅ 必需 | ❌ 不需要 | ❌ 不需要 |
| `hal_conf.h` | ✅ 必需 | ✅ 必需 | ❌ 不需要 | ❌ 不需要 |
| 入口文件 | `main.c` | `main.cpp` | `main.c` | `main.cpp` |
| `extern "C"` ISR | 不需要 | ✅ 所有 ISR + HAL 回调 | 不需要 | ✅ 所有 ISR |
| `file(GLOB SOURCES)` | `*.c` | `*.cpp` | `*.c` | `*.cpp` |
| C++ 编译选项 | ❌ | ✅ `-std=c++17` 等 | ❌ | ✅ `-std=c++17` 等 |
| HAL 外设链接 | ✅ 按需 | ✅ 按需 | ❌ | ❌ |

### 3. 时钟配置

> **AI 需要理解时钟树而非死记参数。掌握以下公式即可正确配置任意 STM32 系列。**

```
AI: "期望的系统主频是多少？使用什么时钟源？"
```

#### 时钟配置速查（按系列）

| 系列 | 可用内部时钟 | PLL 输入范围 | VCO 范围 | 最高主频 |
|------|------------|-------------|---------|---------|
| STM32F1 | HSI 8MHz | 4-16MHz (HSE/HSI) | — | 72MHz |
| STM32F4 | HSI 16MHz | 1-2MHz (HSE/HSI) | 100-432MHz | 168MHz |
| STM32L4 | MSI 100k-48M / HSI 16MHz | 4-16MHz | 64-344MHz | 80MHz |
| STM32G0 | HSI 16MHz | 2.66-8MHz | 96-344MHz | 64MHz |
| STM32H7 | HSI 64MHz | 1-16MHz (HSE/HSI) | 150-836MHz | 550MHz |

#### PLL 计算公式（通用）

```
PLL_IN  = PLL_SRC / PLLM          → 必须落在 PLL 输入范围内
PLL_VCO = PLL_IN * PLLN           → 必须落在 VCO 范围内
PLL_P   = PLL_VCO / PLLP          → SAI / 辅助时钟
PLL_Q   = PLL_VCO / PLLQ          → USB / 48MHz 外设
PLL_R   = PLL_VCO / PLLR          → SYSCLK（系统主频）
```

#### 常用时钟方案

| 方案 | 芯片 | PLL 链 | 结果 | FLASH_LATENCY |
|------|------|--------|------|---------------|
| MSI 内部 | STM32L4 | MSI 4M /1 ×40 /2 | **80MHz** | 4 |
| HSI 内部 | STM32F1 | HSI 8M /2 ×12 | **48MHz** | 1 |
| HSE 外部 | STM32F1 | HSE 8M ×9 | **72MHz** | 2 |
| HSE 外部 | STM32L4 | HSE 8M /1 ×20 /2 | **80MHz** | 4 |
| HSI 内部 | STM32F4 | HSI 16M /8 ×168 /2 | **168MHz** | 5 |
| HSI 内部 | STM32G0 | HSI 16M /1 ×8 /2 | **64MHz** | 2 |

#### STM32L4 电压缩放（特殊）

```cpp
// L4 系列 80MHz 必须先设置电压等级！否则 PLL 不稳定
HAL_PWREx_ControlVoltageScaling(PWR_REGULATOR_VOLTAGE_SCALE1);
// SCALE1 支持 ≤ 80MHz  │  SCALE2 支持 ≤ 26MHz
// ℹ️ 参考手册说明，不同电压等级对应不同频率上限
```

### 4. 中间件选择

```
AI: "需要 RTOS 吗？"
```

| 中间件 | 引入方式 |
|--------|---------|
| **FreeRTOS** | `find_package(CMSIS COMPONENTS {chip} RTOS::FreeRTOS REQUIRED)` |
| **FatFS** | 通过 CMSIS + HAL SD/SPI 手动集成 |
| **lwIP** | 通过 HAL ETH + 手动集成 |
| **USB Stack** | 通过 HAL PCD + 手动集成 |

> 使用 FreeRTOS 时，HAL 时基不能再使用 SysTick（FreeRTOS 占用）。需使用硬件定时器（如 TIM6）替代，参见"故障排错"表第 10 条。

### 5. 外设配置

```
AI: "需要哪些外设？"
示例回答: "UART1, PA9/PA10, 115200波特率"
可一次列出多个，如: "UART1 + SPI1 + TIM3 CH1 PWM"
```

> **AI 根据回答自主判断是否追问具体引脚、波特率等参数。**

### 6. 确认 + 预览

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

## 四、第二步：工程配置（CMakeLists.txt）

> **AI 先配置 CMakeLists.txt 并编译验证通过，再写应用代码。** 工程配置决定编译目标和依赖，代码依赖这些配置。

### 目录结构

```
my_project/
├── CMakeLists.txt
├── code/
│   ├── include/
│   │   └── stm32l4xx_hal_conf.h    ← HAL 模式必需
│   └── src/
│       └── main.c / main.cpp       ← 按开发模式
└── build/                           ← cmake -B build 自动生成
```

### 四种模式的 CMakeLists.txt 模板

#### 模式 1：HAL + C

```cmake
cmake_minimum_required(VERSION 3.22)
set(CMAKE_TOOLCHAIN_FILE "$ENV{HOME}/stm32-tools/stm32-cmake/cmake/stm32_gcc.cmake")

project(my-project C C ASM)

stm32_fetch_cube(L4)

find_package(CMSIS COMPONENTS STM32L431VC REQUIRED)
find_package(HAL COMPONENTS STM32L4 REQUIRED)

file(GLOB_RECURSE PROJECT_SOURCES code/src/*.c)

add_executable(${PROJECT_NAME} ${PROJECT_SOURCES})

target_include_directories(${PROJECT_NAME} PRIVATE code/include)

target_link_libraries(${PROJECT_NAME} PRIVATE
    CMSIS::STM32::L431VC
    HAL::STM32::L4
    STM32::NoSys
    HAL::STM32::L4::RCC
    HAL::STM32::L4::CORTEX
    HAL::STM32::L4::GPIO
    HAL::STM32::L4::FLASH
    HAL::STM32::L4::PWR
    HAL::STM32::L4::DMA
    HAL::STM32::L4::UART
    HAL::STM32::L4::RCCEx
    HAL::STM32::L4::PWREx
)
```

#### 模式 2：HAL + C++

```cmake
cmake_minimum_required(VERSION 3.22)
set(CMAKE_TOOLCHAIN_FILE "$ENV{HOME}/stm32-tools/stm32-cmake/cmake/stm32_gcc.cmake")

# ⚠️ 必须包含 C CXX 两者！
project(my-project C CXX ASM)

stm32_fetch_cube(L4)

find_package(CMSIS COMPONENTS STM32L431VC REQUIRED)
find_package(HAL COMPONENTS STM32L4 REQUIRED)

file(GLOB_RECURSE PROJECT_SOURCES code/src/*.cpp)

add_executable(${PROJECT_NAME} ${PROJECT_SOURCES})

target_include_directories(${PROJECT_NAME} PRIVATE code/include)

target_link_libraries(${PROJECT_NAME} PRIVATE
    CMSIS::STM32::L431VC
    HAL::STM32::L4
    STM32::NoSys
    HAL::STM32::L4::RCC
    HAL::STM32::L4::CORTEX
    HAL::STM32::L4::GPIO
    HAL::STM32::L4::FLASH
    HAL::STM32::L4::PWR
    HAL::STM32::L4::DMA
    HAL::STM32::L4::UART
    HAL::STM32::L4::RCCEx
    HAL::STM32::L4::PWREx
)

# ⚠️ C++ 选项仅对 .cpp 生效
target_compile_options(${PROJECT_NAME} PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:-std=c++17>
    $<$<COMPILE_LANGUAGE:CXX>:-fno-rtti>
    $<$<COMPILE_LANGUAGE:CXX>:-fno-exceptions>
    $<$<COMPILE_LANGUAGE:CXX>:-fno-threadsafe-statics>
)
```

| C++ 编译选项 | 说明 |
|-------------|------|
| `-std=c++17` | C++ 标准 |
| `-fno-rtti` | 禁用 RTTI，嵌入式必须 |
| `-fno-exceptions` | 禁用异常，嵌入式必须 |
| `-fno-threadsafe-statics` | 裸机不需要线程安全静态初始化 |

#### 模式 3：CMSIS 寄存器 + C

```cmake
cmake_minimum_required(VERSION 3.22)
set(CMAKE_TOOLCHAIN_FILE "$ENV{HOME}/stm32-tools/stm32-cmake/cmake/stm32_gcc.cmake")

project(my-project C ASM)

stm32_fetch_cube(F1)

find_package(CMSIS COMPONENTS STM32F103C8 REQUIRED)

file(GLOB_RECURSE PROJECT_SOURCES code/src/*.c)

add_executable(${PROJECT_NAME} ${PROJECT_SOURCES})

target_link_libraries(${PROJECT_NAME} PRIVATE
    CMSIS::STM32::F103C8
    STM32::NoSys
)
```

#### 模式 4：CMSIS 寄存器 + C++

```cmake
cmake_minimum_required(VERSION 3.22)
set(CMAKE_TOOLCHAIN_FILE "$ENV{HOME}/stm32-tools/stm32-cmake/cmake/stm32_gcc.cmake")

project(my-project C CXX ASM)

stm32_fetch_cube(F1)

find_package(CMSIS COMPONENTS STM32F103C8 REQUIRED)

file(GLOB_RECURSE PROJECT_SOURCES code/src/*.cpp)

add_executable(${PROJECT_NAME} ${PROJECT_SOURCES})

target_link_libraries(${PROJECT_NAME} PRIVATE
    CMSIS::STM32::F103C8
    STM32::NoSys
)

target_compile_options(${PROJECT_NAME} PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:-std=c++17>
    $<$<COMPILE_LANGUAGE:CXX>:-fno-rtti>
    $<$<COMPILE_LANGUAGE:CXX>:-fno-exceptions>
)
```

### hal_conf.h（HAL 模式必需）

从 `~/stm32-tools/stm32-cmake/examples/` 下对应家族的模板复制，然后根据启用的外设**去掉对应 `#define` 注释**。

```c
// 示例：启用 UART 和 DMA
#define HAL_UART_MODULE_ENABLED
#define HAL_DMA_MODULE_ENABLED     // ⚠️ UART 驱动内部引用了 DMA 类型定义

// STM32L4 必须定义完整振荡器值
#define HSE_VALUE    8000000U
#define HSI_VALUE    16000000U
#define MSI_VALUE    4000000U
#define HSI48_VALUE  48000000U
#define LSI_VALUE    32000U
#define LSE_VALUE    32768U
#define EXTERNAL_SAI1_CLOCK_VALUE    2097000U
#define EXTERNAL_SAI2_CLOCK_VALUE    48000U
```

---

## 五、第三步：编译

```bash
# 配置
cmake -S . -B build -G Ninja

# 编译
cmake --build build 2>&1

# 首次编译时 stm32_fetch_cube() 自动下载 CMSIS+HAL，约 30-60 秒
```

> **CMakeLists.txt 配置通过后，AI 才开始写 code/src/main.c(pp)。**

---

## 六、第四步：应用代码

### HAL + C 入口模板

```c
// code/src/main.c
#include "stm32l4xx_hal.h"

static void SystemClock_Config(void) { /* AI 根据配置生成 */ }
static void MX_USART1_UART_Init(void) { /* AI 根据配置生成 */ }

int main(void) {
    HAL_Init();
    SystemClock_Config();
    MX_USART1_UART_Init();
    while (1) {
        // 用户功能代码
    }
}
```

### HAL + C++ 入口模板

```cpp
// code/src/main.cpp
#include "stm32l4xx_hal.h"

// ISR 和 HAL 回调必须 extern "C"
extern "C" void SysTick_Handler(void)
{
    HAL_IncTick();
}

extern "C" void HAL_UART_MspInit(UART_HandleTypeDef *huart) {
    if (huart->Instance == USART1) {
        __HAL_RCC_USART1_CLK_ENABLE();
        __HAL_RCC_GPIOA_CLK_ENABLE();

        GPIO_InitTypeDef gpio = {};
        gpio.Pin = GPIO_PIN_9 | GPIO_PIN_10;
        gpio.Mode = GPIO_MODE_AF_PP;
        gpio.Pull = GPIO_NOPULL;
        gpio.Speed = GPIO_SPEED_FREQ_VERY_HIGH;
        gpio.Alternate = GPIO_AF7_USART1;
        HAL_GPIO_Init(GPIOA, &gpio);
    }
}

static bool SystemClock_Config(void) { /* AI 根据配置生成 */ }
static bool MX_USART1_UART_Init(void) { /* AI 根据配置生成 */ }

int main(void) {
    HAL_Init();
    if (!SystemClock_Config()) Error_Handler();
    if (!MX_USART1_UART_Init()) Error_Handler();
    while (1) {
        // 用户功能代码
    }
}
```

> ⚠️ **HAL 回调函数必须 `extern "C"`**：`HAL_MspInit`、`HAL_UART_MspInit`、`SysTick_Handler` 等。HAL 库是 C 代码，通过 C 链接调用回调，C++ 名称修饰会导致链接失败。

### CMSIS + C 入口模板

```c
// code/src/main.c
#include "stm32f1xx.h"

// 简易 SysTick 延时
static void delay_ms(uint32_t ms) {
    SysTick->LOAD = 72000 - 1;  // 72MHz
    SysTick->VAL = 0;
    SysTick->CTRL = SysTick_CTRL_CLKSOURCE_Msk | SysTick_CTRL_ENABLE_Msk;
    for (uint32_t i = 0; i < ms; i++) {
        while ((SysTick->CTRL & SysTick_CTRL_COUNTFLAG_Msk) == 0);
    }
    SysTick->CTRL = 0;
}

int main(void) {
    RCC->APB2ENR |= RCC_APB2ENR_IOPCEN;  // GPIOC 时钟
    GPIOC->CRH &= ~(0xF << 20);
    GPIOC->CRH |= (0x3 << 20);            // PC13 推挽输出
    while (1) {
        GPIOC->ODR ^= (1 << 13);          // LED 翻转
        delay_ms(500);
    }
}
```

### CMSIS + C++ 入口模板

```cpp
// code/src/main.cpp
#include "stm32f1xx.h"

extern "C" void SysTick_Handler(void) {}  // C 链接 ISR

int main(void) {
    RCC->APB2ENR |= RCC_APB2ENR_IOPCEN;
    GPIOC->CRH &= ~(0xF << 20);
    GPIOC->CRH |= (0x3 << 20);
    while (1) {
        GPIOC->ODR ^= (1 << 13);
        for (volatile int i = 0; i < 100000; i++);
    }
}
```

---

## 七、第五步：烧录

### 路径 A（CubeProgrammer CLI）

```bash
CUBEIDE_ROOT=$(ls -d /c/ST/*/STM32CubeIDE /d/ST/*/STM32CubeIDE 2>/dev/null | head -1)
PROGRAMMER=$(ls "$CUBEIDE_ROOT/plugins/com.st.stm32cube.ide.mcu.externaltools.cubeprogrammer.win32_"*/tools/bin/STM32_Programmer_CLI.exe 2>/dev/null | head -1)

"$PROGRAMMER" -c port=SWD
"$PROGRAMMER" -c port=SWD -w build/my-project.elf -v
"$PROGRAMMER" -c port=SWD -rst -run
```

### 路径 B（st-flash / OpenOCD）

```bash
# st-flash（简单快速）
arm-none-eabi-objcopy -O binary build/my-project.elf build/my-project.bin
st-flash --reset write build/my-project.bin 0x08000000
# ✅ 期望: Flash written and verified! jolly good!

# OpenOCD（支持调试）
openocd -f interface/stlink.cfg -f target/stm32l4x.cfg \
    -c "program build/my-project.elf verify reset exit"
```

> 🔥 **重要：st-flash 必须烧 `.bin` 不是 `.elf`！** 直接烧 `.elf` 会把 ELF 文件头写入 flash（hexdump 读回是 `7F 45 4C 46` = `"ELF"`），CPU 上电读到垃圾 SP/PC，**程序完全不执行但显示 verified OK**。

### 硬件接线

```
ST-Link                    目标板
SWDIO (通常第2针)  ────→  SWDIO
SWCLK (通常第4针)  ────→  SWCLK
GND    ────────────→  GND
3.3V   ────────────→  3.3V（如板子不独立供电）

4 线即可完成烧录。NRST 线可选（用于自动复位）。
```

---

## 八、故障排错表

### 编译错误

| # | 报错信息 | 原因 | 修复 |
|---|---------|------|------|
| 1 | `UART_HandleTypeDef undeclared` / `TIM_HandleTypeDef undeclared` | hal_conf.h 中对应模块的 `#define HAL_xxx_MODULE_ENABLED` 被注释 | 去注释对应模块 |
| 2 | `undefined reference to HAL_xxx` | CMakeLists.txt 中未链接对应 HAL module | `target_link_libraries` 中添加 `HAL::STM32::{F}::xxx` |
| 3 | `cannot find -lSTM32::NoSys` | 未链接 `STM32::NoSys` | `target_link_libraries` 中加 `STM32::NoSys` |
| 4 | `fatal error: stm32l4xx_hal.h: No such file` | include 路径不对 | CMakeLists.txt 中 `target_include_directories(${PROJECT_NAME} PRIVATE code/include)` |
| 5 | `cc1.exe: warning: '-std=c++17' is valid for C++ but not for C` | C++ 选项被传给 C 编译器 | 用 `$<$<COMPILE_LANGUAGE:CXX>:-std=c++17>` generator expression |
| 6 | `undefined reference to HAL_xxx`（C++ 项目） | project 只写了 `CXX ASM`，HAL C 源文件未编译 | 改为 `project(... C CXX ASM)` |
| 7 | `dangerous relocation: unsupported relocation`（C++ 项目） | HAL .c 文件未链接进目标 | 确保 `project()` 包含 C 语言 |
| 8 | `request for member 'XferAbortCallback' in something not a structure or union` | DMA 模块未启用但 UART 驱动内部引用 | hal_conf.h 中启用 `HAL_DMA_MODULE_ENABLED` + CMakeLists 链接 `HAL::STM32::{F}::DMA` |
| 9 | `LSE_STARTUP_TIMEOUT undeclared` / `HSE_STARTUP_TIMEOUT undeclared` | hal_conf.h 中未定义振荡器超时宏 | 添加 `#define HSE_STARTUP_TIMEOUT 100` / `#define LSE_STARTUP_TIMEOUT 5000` |
| 10 | `HSI48_VALUE undeclared` / `EXTERNAL_SAI1_CLOCK_VALUE undeclared` | hal_conf.h 中缺少特定振荡器值 | 添加所有必需的 `xxx_VALUE` 定义（参考 hal_conf.h 章节） |
| 11 | `undefined reference to HAL_PWREx_xxx` | L4 系列 PWREx 模块未链接 | 链接 `HAL::STM32::L4::PWREx` |
| 12 | `undefined reference to HAL_RCCEx_PeriphCLKConfig` | RCCEx 模块未链接 | 链接 `HAL::STM32::{F}::RCCEx` |

### 运行时问题

| # | 现象 | 原因 | 修复 |
|---|------|------|------|
| 13 | 串口只输出部分数据后死机 | `SysTick_Handler` 未定义 | 添加 `extern "C" void SysTick_Handler(void) { HAL_IncTick(); }` |
| 14 | `HAL_Delay` 不工作 | PLL 切换后 SysTick 未重配 | 添加 `HAL_SYSTICK_Config(HAL_RCC_GetHCLKFreq() / 1000)` |
| 15 | STM32L4 PLL 80MHz 不稳定 / 死机 | 未调用 `HAL_PWREx_ControlVoltageScaling(SCALE1)` | 在 `SystemClock_Config` 开头调用 |
| 16 | `HAL_PWREx_ControlVoltageScaling` 返回 HAL_ERROR | `HAL_MspInit` 未启用 `PWR` 时钟 | `HAL_MspInit` 中添加 `__HAL_RCC_PWR_CLK_ENABLE()` |
| 17 | `multiple definition of SysTick_Handler`（FreeRTOS） | 用户定义了 SysTick_Handler 但 FreeRTOS 已接管 | 删除用户定义，FreeRTOS 占用 SysTick |
| 18 | FreeRTOS + HAL_Delay 都不工作 | HAL 时基仍用 SysTick（被 FreeRTOS 占用） | HAL 时基改为硬件定时器。在 hal_conf.h 中启用 `USE_HAL_TIM_REGISTER_CALLBACKS`，用 `HAL_InitTick(TICK_INT_PRIORITY)` 自定义 |
| 19 | `Flash written and verified` 但程序不跑 | st-flash 烧了 .elf（文件头被当成代码） | `arm-none-eabi-objcopy -O binary xxx.elf xxx.bin` 后烧 .bin |
| 20 | USB 串口收到乱码 | 波特率不匹配（通常因时钟配置与实际不符） | 检查 `SystemClock_Config` 是否正确执行 |

### 连接/烧录问题

| # | 现象 | 可能原因 | 排查顺序 |
|---|------|---------|---------|
| 21 | `st-info --probe` 报 `Couldn't find any ST-Link` | USB 无驱动 / 线松动 | ① 重插 USB ② Windows: 检查设备管理器 |
| 22 | `st-flash` 返回 `LIBUSB_ERROR_TIMEOUT` | 驱动问题 | 检查 ST-Link 驱动是否正确安装 |
| 23 | `chipid: 0x000` + `Failed to enter SWD mode` | SWD 被用户程序锁死 | 断电 → BOOT0=1 上电 → 擦除芯片 → BOOT0=0 |
| 24 | OpenOCD 报 `init mode failed` | 驱动/权限问题 | Windows: 检查设备管理器；Linux: `sudo` |

---

## 九、外设模块速查

> **AI 无需死记外设配置。HAL 模块名 = HAL 驱动文件名去掉前缀后全大写。**
> 如 `stm32l4xx_hal_uart.c` → CMake target: `HAL::STM32::L4::UART`

| 分类 | 模块 | CMake Target | 功能 |
|------|------|-------------|------|
| 必选 | RCC | `HAL::STM32::{F}::RCC` | 时钟配置 |
| 必选 | GPIO | `HAL::STM32::{F}::GPIO` | 输入/输出 |
| 必选 | CORTEX | `HAL::STM32::{F}::CORTEX` | NVIC / SysTick |
| 必选 | DMA | `HAL::STM32::{F}::DMA` | DMA（UART/SPI 内部依赖） |
| 必选 | FLASH | `HAL::STM32::{F}::FLASH` | Flash 操作 |
| 必选 | PWR | `HAL::STM32::{F}::PWR` | 电源管理 |
| 通信 | UART | `HAL::STM32::{F}::UART` | 异步串口 |
| 通信 | USART | `HAL::STM32::{F}::USART` | 同步/异步串口 |
| 通信 | SPI | `HAL::STM32::{F}::SPI` | SPI |
| 通信 | I2C | `HAL::STM32::{F}::I2C` | I2C |
| 通信 | CAN | `HAL::STM32::{F}::CAN` | CAN 总线 |
| 定时 | TIM | `HAL::STM32::{F}::TIM` | 定时器/PWM |
| 定时 | RTC | `HAL::STM32::{F}::RTC` | 实时时钟 |
| 模拟 | ADC | `HAL::STM32::{F}::ADC` | ADC |
| 模拟 | DAC | `HAL::STM32::{F}::DAC` | DAC |
| 看门狗 | IWDG | `HAL::STM32::{F}::IWDG` | 独立看门狗 |
| 看门狗 | WWDG | `HAL::STM32::{F}::WWDG` | 窗口看门狗 |
| 存储 | SD | `HAL::STM32::{F}::SD` | SD 卡 |
| 存储 | QSPI | `HAL::STM32::{F}::QSPI` | Quad-SPI |
| USB | PCD | `HAL::STM32::{F}::PCD` | USB 设备 |
| ETH | ETH | `HAL::STM32::{F}::ETH` | 以太网 |
| CRC | CRC | `HAL::STM32::{F}::CRC` | CRC |
| 随机数 | RNG | `HAL::STM32::{F}::RNG` | 硬件随机数 |
| 扩展 | RCCEx | `HAL::STM32::{F}::RCCEx` | 扩展时钟 |
| 扩展 | PWREx | `HAL::STM32::{F}::PWREx` | 扩展电源（L4/F4/F7/H7） |

---

## 十、芯片型号速查

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

## 参考资源

- [ObKo/stm32-cmake](https://github.com/ObKo/stm32-cmake) — CMake 框架（MIT 开源）
- [ST GitHub](https://github.com/STMicroelectronics) — HAL/CMSIS 源码（`stm32_fetch_cube()` 自动拉取）
- [ARM GNU Toolchain](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads)
