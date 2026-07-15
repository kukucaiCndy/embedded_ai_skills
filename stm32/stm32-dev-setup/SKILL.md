---
name: "stm32-dev-setup"
description: "STM32 开发环境安装。跨平台（Windows/macOS/Linux）支持，兼容 CubeIDE（路径A）和纯 CLI（路径B）两种方式。检测已有安装，仅安装缺失组件。Call first before any STM32 development."
---

# STM32 开发环境安装

> 跨平台支持：**Windows** / **macOS** / **Linux**。
> 两条路径任选：**路径 A**（CubeIDE 已安装）或 **路径 B**（纯 CLI，全部开源）。

---

## Pre-flight: 环境检测（⚠️ 必须最先执行）

### Shell 检测（Windows 必须）

> **AI 必须先检测当前 Shell 环境。** Windows 下工具链依赖 MSYS2 环境，PowerShell / CMD 无法正常使用 `pacman`。

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

```
AI 向用户输出:
"检测到你当前不在 MSYS2 环境中。STM32 开发工具链需要通过 MSYS2 安装和管理。

请按以下步骤安装 MSYS2:
1. 下载安装包: https://www.msys2.org/ ，运行安装程序，默认安装到 C:\msys64
2. 安装完成后，从开始菜单启动 「MSYS2 UCRT64」
3. 在 UCRT64 终端中验证: uname -s  # 应输出 MINGW64_NT-* 或 MSYS_NT-*
4. 然后在 UCRT64 终端中重新执行本 Skill

安装完成后告诉我，我会继续环境检测。"
```

### 工具链检测

#### 1. 检测 CubeIDE（Windows only，路径 A）

```bash
ls -d /c/ST/STM32CubeIDE_*/STM32CubeIDE/STM32CubeIDE.exe 2>/dev/null
```

#### 2. 检测系统工具链

```bash
arm-none-eabi-gcc --version 2>/dev/null | head -1
cmake --version 2>/dev/null | head -1
ninja --version 2>/dev/null
```

#### 3. 判断路径

| 条件 | 路径 | 说明 |
|------|------|------|
| CubeIDE 已安装 | **路径 A** | 取其内置 arm-gcc + cmake + CubeProgrammer |
| 无 CubeIDE + 工具链就绪 | **路径 B** | 纯 CLI，全部开源 |
| 无 CubeIDE + 工具链缺失 | **先装工具链 → 路径 B** | 按下方对应平台命令安装 |

---

## Step 1: 安装工具链（仅缺失项）

| 平台 | 推荐 Shell | 安装命令（一次） |
|------|-----------|---------|
| **Windows** | **MSYS2 UCRT64** | `pacman -S --needed mingw-w64-x86_64-arm-none-eabi-gcc mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja mingw-w64-x86_64-stlink mingw-w64-x86_64-openocd` |
| **macOS** | Terminal + Homebrew | `brew install --cask gcc-arm-embedded && brew install cmake ninja stlink openocd` |
| **Linux (apt)** | 系统 Terminal | `sudo apt install -y gcc-arm-none-eabi cmake ninja-build stlink-tools openocd` |

> 如果 Pre-flight 检测到工具链已安装，跳过对应平台的安装命令。

---

## Step 2: 路径 A 补充配置（仅 CubeIDE 用户）

**路径 A 工具链定位（Windows）：**
```bash
CUBEIDE_ROOT=$(ls -d /c/ST/*/STM32CubeIDE /d/ST/*/STM32CubeIDE 2>/dev/null | head -1)
GCC_DIR=$(ls -d "$CUBEIDE_ROOT/plugins/com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32."*".win32_"*/tools/bin 2>/dev/null | head -1)
CMAKE_DIR=$(ls -d "$CUBEIDE_ROOT/plugins/com.st.stm32cube.ide.mcu.externaltools.cmake.win32_"*/tools/bin 2>/dev/null | head -1)
export PATH="$GCC_DIR:$CMAKE_DIR:$PATH"
```

---

## Step 3: stm32-cmake 初始化（全局一次）

```bash
mkdir -p ~/stm32-tools
git clone --depth=1 https://github.com/ObKo/stm32-cmake.git ~/stm32-tools/stm32-cmake
```

> 如果 `~/stm32-tools/stm32-cmake` 已存在，跳过此步骤。

---

## Step 4: 验证环境

### 工具链验证

```bash
arm-none-eabi-gcc --version | head -1
cmake --version | head -1
ninja --version
```

### ST-Link 验证

```bash
# 探测 ST-Link 并读取芯片信息
st-info --probe
```

| 结果 | 动作 |
|------|------|
| `Found 1 stlink programmers` + 芯片信息 | ✅ 继续 |
| `Couldn't find any ST-Link` | ❌ 告知用户检查连接 |

### OpenOCD 验证

```bash
openocd -f interface/stlink.cfg -f target/stm32f1x.cfg \
    -c "init" -c "halt" -c "reg" -c "resume" -c "shutdown" 2>&1
```

> 如能正常输出 `r0`~`r15`、`pc`、`msp`、`psp`、`xPSR` 等寄存器，说明调试通道正常。

---

## 完成标志

- [x] `arm-none-eabi-gcc --version` 正常
- [x] `cmake --version` 正常
- [x] `ninja --version` 正常
- [x] `~/stm32-tools/stm32-cmake` 已 clone
- [x] `st-info --probe` 能检测到 ST-Link

## 后续

环境安装完毕后，使用 `stm32-project-init` skill 创建项目并编译烧录。
