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
>
> **⚠️ 执行规则**：所有检测命令必须并行执行（单条消息多个 RunCommand 调用），不要串行等待。

### 检测项目表

| # | 检测项 | 检测命令 | 匹配条件 |
|---|--------|---------|---------|
| P1 | cmake | `which cmake && cmake --version \| head -1` | 可执行 + 显示版本 |
| P2 | ninja | `which ninja && ninja --version` | 可执行 + 显示版本 |
| P3 | dtc | `which dtc && dtc --version \| head -1` | 可执行 + 显示版本 |
| P4 | gperf | `which gperf && gperf --version \| head -1` | 可执行 + 显示版本 |
| P5 | python3 | `python3 --version` | 版本 >= 3.8 |
| P6 | arm-none-eabi-gcc | `which arm-none-eabi-gcc && arm-none-eabi-gcc --version \| head -1` | 可执行 + 显示版本 |
| P7 | JLinkExe | 见下方「J-Link 专用检测逻辑」 | 找到可执行文件（非断裂符号链接） |
| P8 | west | `west --version 2>/dev/null \|\| python3 -c "import west; print(west.__version__)" 2>/dev/null \|\| echo NOT_FOUND` | 可正常返回 |
| P9 | NCS workspace | `test -d "$HOME/ncs/.west" && echo "FOUND: $HOME/ncs" \|\| echo "NOT_FOUND"` | 目录存在 |
| P10 | Zephyr Python 依赖完整性 | 见下方「Python 依赖检测逻辑」 | 所有必需包已安装 |
| P11 | .zshrc/.bashrc | `grep "nRF Connect SDK" ~/.zshrc 2>/dev/null \|\| grep "nRF Connect SDK" ~/.bashrc 2>/dev/null \|\| echo NOT_FOUND` | 包含 NCS 配置行 |
| P12 | west 在 PATH 中 | `which west 2>/dev/null \|\| echo NOT_FOUND` | 可直接执行（非需完整路径） |

### J-Link 专用检测逻辑（P7）

> **⚠️ 注意以下两个陷阱：**
> 1. **`find` 返回值陷阱**：`find` 即使没有匹配结果也返回 exit code 0。切勿将 `find` 放在 `||` 短路链中使用，否则第一个 `find` 执行后链即短路，后续检测步骤会被跳过。
> 2. **断裂符号链接陷阱**：JLink 安装到自定义前缀时，`usr/local/bin/JLinkExe` 等符号链接可能指向不存在的绝对路径（如 `/Applications/SEGGER/...`），导致 `-x` 检测失败。因此 **不能使用 `head -1` 只取第一个 find 结果**，必须收集所有结果逐个检查。

使用以下一次性循环检测脚本（收集所有候选路径，找到第一个可执行文件即停止）：

```bash
JLINK_PATH=""
# 收集所有候选路径（不用 head -1，保留全部 find 结果以跳过断裂符号链接）
candidates="$(
  which JLinkExe 2>/dev/null
  echo "/Applications/SEGGER/JLink/JLinkExe"
  find /Applications/SEGGER -name 'JLinkExe' -maxdepth 3 2>/dev/null
  echo "/opt/homebrew/bin/JLinkExe"
  echo "/usr/local/bin/JLinkExe"
  find "$HOME/tools" -name 'JLinkExe' -maxdepth 5 2>/dev/null
  find "$HOME/.local" -name 'JLinkExe' -maxdepth 5 2>/dev/null
)"
# 逐行检查，找到第一个可执行文件（用 <<< here-string 避免管道子 shell 变量丢失）
while IFS= read -r p; do
  if [ -n "$p" ] && [ -x "$p" ]; then
    JLINK_PATH="$p"
    break
  fi
done <<< "$candidates"
echo "JLinkExe: ${JLINK_PATH:-NOT_FOUND}"
```

> 只要输出非 `NOT_FOUND`，即标记 J-Link 已安装。**记录 JLINK_PATH 实际路径**，后续烧录步骤需要用到（可能不在 PATH 中）。

### Python 依赖检测逻辑（P10）

> **⚠️ 不能只检查 pyelftools/intelhex**。Zephyr 的 `west flash` 需要 `requirements-base.txt` 中的全部包（psutil、pylink-square、pyserial 等），缺失任何一个都会导致 `FATAL ERROR: one or more Python dependencies were missing`。

```bash
# 检查 requirements-base.txt 中的所有必需包（模块名与包名不同，用 import 名）
MISSING_PKGS=""
# 格式: "import名:显示名"，用正确的 import 模块名
for entry in "elftools:pyelftools" "intelhex:intelhex" "yaml:PyYAML" "pykwalify:pykwalify" "canopen:canopen" "packaging:packaging" "progress:progress" "patoolib:patool" "psutil:psutil" "pylink:pylink-square" "serial:pyserial" "requests:requests" "semver:semver" "anytree:anytree" "west:west"; do
  mod="${entry%%:*}"
  python3 -c "import $mod" 2>/dev/null || MISSING_PKGS="$MISSING_PKGS $mod"
done
if [ -z "$MISSING_PKGS" ]; then
  echo "Python deps: ALL OK"
else
  echo "Python deps MISSING:$MISSING_PKGS"
fi
```

> **注意**：检测脚本用的是 Python `import` 名（如 `pylink`、`serial`、`yaml`），不是 pip 包名（如 `pylink-square`、`pyserial`、`PyYAML`）。缺失时用 pip 包名安装。

### west 路径检测逻辑（P8 + P12）

> **⚠️ macOS 上 pip3 --user 安装的 west 位于 `~/Library/Python/3.x/bin/`，可能不在 PATH 中**。即使 `python3 -c "import west"` 成功，`which west` 仍可能失败。

- **P8 通过但 P12 失败**：west 已安装但未在 PATH → 执行 Step 4 的 PATH 配置部分
- **P8 失败**：west 未安装 → 执行 Step 4 完整安装

查找 west 实际路径：
```bash
WEST_BIN=""
for p in "$(which west 2>/dev/null)" \
         "$HOME/Library/Python/3.9/bin/west" \
         "$HOME/Library/Python/3.10/bin/west" \
         "$HOME/Library/Python/3.11/bin/west" \
         "$HOME/.local/bin/west"; do
  if [ -n "$p" ] && [ -x "$p" ]; then
    WEST_BIN="$p"
    break
  fi
done
echo "west: ${WEST_BIN:-NOT_FOUND}"
```

### 检测结果报告

向用户汇报检测结果后再进入安装流程：

```
环境检测结果:
  ✅ cmake 4.x       ✅ ninja 1.x      ✅ dtc 1.x
  ✅ gperf           ✅ python3 3.x    ✅ arm-none-eabi-gcc
  ✅ JLinkExe (/path/to/JLinkExe)  ✅ west 1.5.0  ❌ west 不在 PATH (将配置)
  ✅ NCS workspace (/Users/xxx/ncs)
  ❌ Python deps MISSING: psutil pylink-square (将安装)
  ✅ .zshrc

安装计划（仅缺失项）:
  → Step 4: 配置 west PATH
  → Step 6: pip3 install 缺失的 Python 依赖
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

## Step 4: 安装 west 工具并配置 PATH

> **如果 P8 通过且 P12 通过，跳过此步骤。**
> **如果 P8 通过但 P12 失败（west 不在 PATH），仅执行下方 PATH 配置。**
> **如果 P8 失败，执行完整安装 + PATH 配置。**

### 4.1 安装 west（如未安装）

```bash
pip3 install --user west
```

### 4.2 配置 PATH（⚠️ 必须执行，即使 west 已安装）

```bash
# 查找 west 实际安装路径
WEST_BIN_DIR=""
for d in "$HOME/Library/Python/3.9/bin" \
         "$HOME/Library/Python/3.10/bin" \
         "$HOME/Library/Python/3.11/bin" \
         "$HOME/.local/bin"; do
  if [ -x "$d/west" ]; then
    WEST_BIN_DIR="$d"
    break
  fi
done
echo "west bin dir: ${WEST_BIN_DIR:-NOT_FOUND}"

# 将 west bin 目录加入 ~/.zshrc（如尚未存在）
if [ -n "$WEST_BIN_DIR" ]; then
  grep -q "$WEST_BIN_DIR" ~/.zshrc 2>/dev/null || echo "export PATH=\"$WEST_BIN_DIR:\$PATH\"" >> ~/.zshrc
fi
```

> 验证: `export PATH="$WEST_BIN_DIR:$PATH" && west --version`

## Step 5: 初始化 nRF Connect SDK

> **如果 Pre-flight P9 通过（`$NCS_DIR/.west` 存在），跳过此步骤。**

```bash
cd "$NCS_DIR"
west init -m https://github.com/nrfconnect/sdk-nrf --mr v2.9.0
west update
```

> `west update` Clone 所有子仓库（约 4-5GB），需 15-30 分钟。  
> 如中断：删除只有 `.git/` 无文件的空目录后重新 `west update`。

## Step 6: 安装 Python 依赖（⚠️ 完整安装，非仅 pyelftools/intelhex）

> **如果 Pre-flight P10 通过（ALL OK），跳过此步骤。**
> **如果 P10 报告缺失包，仅安装缺失包或完整重装。**

```bash
# 方案 A：完整安装 requirements-base.txt（推荐，避免遗漏）
pip3 install --user -r "$NCS_DIR/zephyr/scripts/requirements-base.txt"

# 方案 B：仅安装缺失包（从 P10 检测结果获取包名）
# pip3 install --user <missing_packages>
```

> 验证: 重新运行 P10 检测脚本，确认输出 `Python deps: ALL OK`

## Step 7: 配置 shell 环境变量

> **如果 Pre-flight P11 通过，检查内容是否需要更新（如 NCS_DIR 变化）。**
> **必须包含：ZEPHYR_TOOLCHAIN_VARIANT、GNUARMEMB_TOOLCHAIN_PATH、west PATH、zephyr-env.sh source。**

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
- [x] `JLinkExe` 可执行（已记录路径，必要时已加入 PATH）
- [x] `west --version` 正常 **且 `which west` 能直接找到**
- [x] `$NCS_DIR/.west` 存在
- [x] **P10 Python 依赖检测 ALL OK（含 psutil/pylink-square/pyserial 等）**
- [x] `west build -b nrf52840dk_nrf52840 .../blinky` 成功

## 故障排除

| 问题 | 解决方案 |
|------|----------|
| `ModuleNotFoundError: No module named 'elftools'` | `pip3 install pyelftools` |
| `ModuleNotFoundError: No module named 'intelhex'` | `pip3 install intelhex` |
| `FATAL ERROR: one or more Python dependencies were missing` | `pip3 install --user -r $NCS_DIR/zephyr/scripts/requirements-base.txt` |
| `HAS_CMSIS_CORE ... has direct dependencies 0` | CMSIS 模块仅 fetch 未 checkout。删除 `modules/hal/cmsis` 后重新 `west update` |
| `west update` 后部分模块只有 `.git/` 无工作文件 | `find modules -name ".git" -maxdepth 3 \| while read g; do ... done` 删空目录，重跑 `west update` |
| macOS `segger-jlink` cask checksum 错 | 从 SEGGER 官网下载 `.pkg`，或用 Nordic DMG 提取方案 |
| `west` 命令找不到 | 确认 `pip3 show -f west` 输出的 bin 路径在 PATH 中（macOS: `~/Library/Python/3.x/bin`） |
| JLinkExe 在非标准路径 | Pre-flight P7 循环检测脚本会扫描 `~/tools/`、`~/.local/` 等目录兜底 |
| JLinkExe 是断裂符号链接 | P7 检测脚本已跳过 `-x` 失败的路径，继续查找下一个 |
