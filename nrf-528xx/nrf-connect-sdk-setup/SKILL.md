---
name: "nrf-connect-sdk-setup"
description: "SOP for setting up nRF Connect SDK (Zephyr-based) development environment on macOS and Linux. 先检测已安装组件，仅安装缺失项。Installs and configures all required tools for Nordic nRF52/nRF53/nRF91 development."
---

# nRF Connect SDK 环境安装

标准 SOP 流程，在 macOS 或 Linux 上搭建 nRF Connect SDK (Zephyr) 开发环境。
**先检测已有安装，仅安装缺失组件，避免重复安装。**

## 适用场景

- 初次在 macOS / Linux 上搭建 nRF52 / nRF53 / nRF91 开发环境
- 补充安装缺失的工具链组件
- 纯命令行环境（不依赖 VS Code / IDE）

## 前置条件

1. macOS（Intel 或 Apple Silicon）或 Linux（x86_64 或 arm64）
2. 已安装 Homebrew（macOS）或 apt/dnf（Linux）
3. 已安装 git
4. 网络可访问 GitHub

---

## Pre-flight: 环境检测（⚠️ 必须最先执行）

> **在安装任何组件之前，必须先运行检测命令，确认当前系统已有组件状态。仅对缺失项执行后续安装步骤。**

### 检测项目表

逐项运行以下检测命令，记录结果决定是否跳过对应 Step：

| # | 检测项 | 检测命令 | 匹配条件 |
|---|--------|---------|---------|
| P1 | cmake | `which cmake && cmake --version \| head -1` | 可执行 + 显示版本 |
| P2 | ninja | `which ninja && ninja --version` | 可执行 + 显示版本 |
| P3 | dtc | `which dtc && dtc --version \| head -1` | 可执行 + 显示版本 |
| P4 | gperf | `which gperf && gperf --version \| head -1` | 可执行 + 显示版本 |
| P5 | python3 | `python3 --version` | 版本 >= 3.8 |
| P6 | arm-none-eabi-gcc | `which arm-none-eabi-gcc && arm-none-eabi-gcc --version \| head -1` | 可执行 + 显示版本 |
| P7 | JLinkExe | 见下方「J-Link 专用检测逻辑」 | 任意方式找到可执行文件 |
| P8 | west | `west --version` 或 `python3 -c "import west; print(west.__version__)"` | 可正常返回 |
| P9 | NCS workspace | `test -d "$NCS_DIR/.west"` | 目录存在 |
| P10 | pyelftools | `python3 -c "import elftools"` | 不报错 |
| P11 | intelhex | `python3 -c "import intelhex"` | 不报错 |
| P12 | .zshrc/.bashrc | `grep "nRF Connect SDK" ~/.zshrc` (或 .bashrc) | 包含 NCS 配置行 |

### J-Link 专用检测逻辑（P7）

按优先级依次查找：

```bash
# 1. PATH 中直接可执行
which JLinkExe 2>/dev/null

# 2. macOS 标准安装路径
ls /Applications/SEGGER/JLink/JLinkExe 2>/dev/null
# 或用通配符匹配版本号子目录
find /Applications/SEGGER -name "JLinkExe" -maxdepth 3 2>/dev/null

# 3. Homebrew 安装路径
ls /opt/homebrew/bin/JLinkExe 2>/dev/null
ls /usr/local/bin/JLinkExe 2>/dev/null

# 4. 用户自定义工具目录（兜底）
find "$HOME/tools" -name "JLinkExe" -maxdepth 5 2>/dev/null
find "$HOME/.local" -name "JLinkExe" -maxdepth 5 2>/dev/null
```

> 只要上述任一命令返回有效路径，即标记 J-Link 已安装。记录实际路径供后续使用。

### 检测结果报告

向用户汇报检测结果后再进入安装流程：

```
环境检测结果:
  ✅ cmake 4.x       ✅ ninja 1.x      ✅ dtc 1.x
  ✅ gperf           ✅ python3 3.x    ✅ arm-none-eabi-gcc
  ✅ JLinkExe        ✅ west           ❌ NCS workspace (将安装)
  ✅ pyelftools      ✅ intelhex       ✅ .zshrc

安装计划（仅缺失项）:
  → Step 5: west init $HOME/ncs + west update (~15min)
```

---

## Step 0: 确认安装路径（⚠️ 必须与用户沟通）

> **如果 Pre-flight P9 已检测到 NCS workspace 存在，跳过此步骤并直接使用已有路径。**

通过 `AskUserQuestion` 工具询问用户：

```
"nRF Connect SDK 安装目录"
- 选项1: "使用默认路径 $HOME/ncs (Recommended)"
- 选项2: "自定义路径（请在 Other 中输入绝对路径）"
```

若 `$HOME/ncs` 已存在且有 `.west/`，追加提示: "检测到 $HOME/ncs 已存在 SDK，选择此项将继续使用。"

确认后将此路径作为 `$NCS_DIR` 变量用于后续所有步骤。

---

## Step 1: 安装系统依赖

> **如果 Pre-flight P1~P5 全部通过，跳过此步骤。**

```bash
# macOS（仅安装缺失项）
brew install cmake ninja dtc gperf python3 2>/dev/null || true

# Ubuntu / Debian
sudo apt install --no-install-recommends git cmake ninja-build gperf \
  ccache device-tree-compiler wget python3-dev python3-pip \
  python3-setuptools python3-wheel xz-utils file make
```

> 验证: `cmake --version`, `ninja --version`

## Step 2: 安装 GNU ARM Embedded Toolchain

> **如果 Pre-flight P6 通过（`arm-none-eabi-gcc` 可执行），跳过此步骤。**

### macOS
```bash
brew install --cask gcc-arm-embedded
```
> 需要用户输入 sudo 密码。如不可用，改为:
> ```bash
> brew install arm-none-eabi-gcc
> ```

### Linux
从 ARM 官网下载并解压到 `${NCS_DIR}/toolchain/`，将其 `bin/` 加入 PATH。

> 验证: `arm-none-eabi-gcc --version`

## Step 3: 安装 SEGGER J-Link 软件

> **如果 Pre-flight P7 找到 JLinkExe，记录其路径并跳过此步骤。**

1. 打开 [https://www.segger.com/downloads/jlink/](https://www.segger.com/downloads/jlink/)
2. 选择对应平台：
   - macOS Apple Silicon: `JLink_MacOSX_arm64.pkg`
   - macOS Intel: `JLink_MacOSX_x86_64.pkg`
   - Linux: `.deb` 或 `.rpm`
3. 安装（macOS 双击 `.pkg` 或 `sudo installer -pkg ... -target /`）

**备选方案 1（SEGGER 下载被阻断时）**：从 Nordic 的 nRF Command Line Tools DMG 中提取 J-Link 安装包。该 DMG 内含 `.JLink_MacOSX_xxx.pkg`：
```bash
curl -L -o /tmp/nRFCommandLineTools.dmg \
  "https://nsscprodmedia.blob.core.windows.net/prod/.../nrf-command-line-tools-10.24.2-darwin.dmg"
hdiutil attach /tmp/nRFCommandLineTools.dmg -nobrowse
# 安装 DMG 内的 .JLink_MacOSX_*.pkg
# 或通过 pkgutil --expand 手动提取到 $NCS_DIR/tools/jlink/
```

**备选方案 2（Homebrew cask）**：
```bash
brew install --cask segger-jlink
```
> 可能因 SEGGER 更新导致 checksum 不匹配而失败，届时回退到备选方案 1。

> 验证: `JLinkExe -NoGui 0 -CommandFile /dev/null -ExitOnError 0` 能显示 J-Link 信息

## Step 4: 安装 west 工具

> **如果 Pre-flight P8 通过，跳过此步骤。**

```bash
pip3 install --user west
# 确保 pip3 user bin 目录在 PATH 中
# macOS: PATH 已自动包含 ~/Library/Python/3.x/bin
# Linux:  export PATH="$HOME/.local/bin:$PATH"
```

> 验证: `west --version`

## Step 5: 初始化 nRF Connect SDK

> **如果 Pre-flight P9 通过（`$NCS_DIR/.west` 存在），跳过此步骤。**

```bash
cd "$NCS_DIR"
west init -m https://github.com/nrfconnect/sdk-nrf --mr v2.9.0
west update
```

> `west update` Clone 所有子仓库（约 4-5GB），需 15-30 分钟。  
> 如中断：删除只有 `.git/` 无文件的空目录后重新 `west update`。

## Step 6: 安装 Python 依赖

> **如果 Pre-flight P10+P11 全部通过，跳过此步骤。**

```bash
pip3 install -r "$NCS_DIR/zephyr/scripts/requirements.txt"
# 或至少安装关键包:
pip3 install pyelftools intelhex
```

> 验证: `python3 -c "import elftools; import intelhex; print('OK')"`

## Step 7: 配置 shell 环境变量

> **如果 Pre-flight P12 通过，跳过此步骤。**
> **如果 NCS_DIR 路径与之前不同，需要更新。**

```bash
# 加入 ~/.zshrc 或 ~/.bashrc
cat >> ~/.zshrc << EOF
# === nRF Connect SDK ===
export ZEPHYR_TOOLCHAIN_VARIANT=gnuarmemb

# ARM GCC 路径（根据实际情况调整）
# macOS (Homebrew cask):
export GNUARMEMB_TOOLCHAIN_PATH="\$HOMEBREW_PREFIX"
# 或自定义: export GNUARMEMB_TOOLCHAIN_PATH="/path/to/arm-gcc"

# Source Zephyr 环境
source "$NCS_DIR/zephyr/zephyr-env.sh"
EOF

source ~/.zshrc
```

> 对于 Linux 且 ARM GCC 在 `/usr` 下: `GNUARMEMB_TOOLCHAIN_PATH="/usr"`

## Step 8: 验证环境

> **仅在首次安装或有组件新增时执行。**

编译一个最简单的示例确保环境正确：

```bash
cd "$NCS_DIR"
west build -b nrf52840dk_nrf52840 \
  "$NCS_DIR/zephyr/samples/basic/blinky" \
  --build-dir /tmp/ncs_verify \
  --pristine
```

> 构建成功即表示环境安装完毕。具体的烧录和项目创建由 `nrf-connect-project-init` skill 负责。

## 完成标志

- [x] `cmake --version` 正常
- [x] `arm-none-eabi-gcc --version` 正常
- [x] `JLinkExe` 可执行（`which JLinkExe` 或 find 能找到）
- [x] `west --version` 正常
- [x] `$NCS_DIR/.west` 存在
- [x] `west build -b nrf52840dk_nrf52840 .../blinky` 成功

## 故障排除

| 问题 | 解决方案 |
|------|----------|
| `ModuleNotFoundError: No module named 'elftools'` | `pip3 install pyelftools` |
| `ModuleNotFoundError: No module named 'intelhex'` | `pip3 install intelhex` |
| `HAS_CMSIS_CORE ... has direct dependencies 0` | CMSIS 模块仅 fetch 未 checkout。删除 `modules/hal/cmsis` 后重新 `west update` |
| `west update` 后部分模块只有 `.git/` 无工作文件 | `find modules -name ".git" -maxdepth 3 \| while read g; do ... done` 删空目录，重跑 `west update` |
| macOS `segger-jlink` cask checksum 错 | 从 SEGGER 官网下载 `.pkg`，或用 Nordic DMG 提取方案 |
| `west` 命令找不到 | 确认 `pip3 show -f west` 输出的 bin 路径在 PATH 中 |
| JLinkExe 在非标准路径 | 在 Pre-flight P7 中，find 会扫描 `~/tools/`、`~/.local/` 等目录兜底 |
