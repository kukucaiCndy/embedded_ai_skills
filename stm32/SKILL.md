---
name: "stm32"
description: "STM32 系列单片机开发入口 skill。自动索引子 skill 完成环境部署、项目初始化、调试排错全流程。当用户进行 STM32 开发时调用。"
---

# STM32 开发 Skill

针对 STM32 全系列（F1/F4/L4/G0/H7 等）的端到端开发技能集。

## 子 Skill 索引

| Skill | 文件 | 功能 |
|-------|------|------|
| **stm32-dev-setup** | [SKILL.md](stm32-dev-setup/SKILL.md) | 环境检测 + 工具链安装（gcc/cmake/ninja/st-link/openocd），CLI/CubeIDE 双路径支持 |
| **stm32-project-init** | [SKILL.md](stm32-project-init/SKILL.md) | 芯片选型 → 开发模式（HAL/CMSIS, C/C++）→ 外设配置 → CMakeLists 生成 → 编译 → 烧录 |
| **stm32-debug** | [SKILL.md](stm32-debug/SKILL.md) | 串口日志 + ST-Link 调试，根因分析，HardFault 排查 |

## 开发流程

```
stm32-dev-setup               stm32-project-init             stm32-debug
(环境安装)          ──→        (项目初始化)            ──→    (调试排错)
```

1. **stm32-dev-setup**：检测 Shell 环境，安装交叉编译工具链、st-link、openocd
2. **stm32-project-init**：收集芯片型号、开发模式、时钟方案、外设需求，生成 CMake 项目
3. **stm32-debug**：开发过程中排查编译错误、运行时 crash、外设驱动问题

## 使用方式

直接描述你的开发需求，系统会自动按需调用对应的子 skill。例如：

- "帮我搭建 STM32 开发环境" → 调用 `stm32-dev-setup`
- "创建一个 STM32L431 用 HAL 库驱动 UART 的项目" → 调用 `stm32-project-init`
- "代码烧进去不运行，帮忙看看" → 调用 `stm32-debug`
