---
name: "nrf-528xx"
description: "nRF528xx 系列单片机开发入口 skill。自动索引子 skill 完成环境部署、项目初始化、调试排错全流程。当用户进行 nRF52/nRF52840/nRF52832 等芯片开发时调用。"
---

# nRF-528xx 开发 Skill

针对 Nordic nRF528xx 系列（nRF52832, nRF52840, nRF52810 等）的端到端开发技能集。

## 子 Skill 索引

| Skill | 文件 | 功能 |
|-------|------|------|
| **nrf-connect-sdk-setup** | [SKILL.md](nrf-connect-sdk-setup/SKILL.md) | 从零安装 nRF Connect SDK、交叉编译器、J-Link 驱动 |
| **nrf-connect-project-init** | [SKILL.md](nrf-connect-project-init/SKILL.md) | 芯片侦测、硬件资源确认、项目框架搭建、编译烧录验证 |
| **nrf-528xx-debug** | [SKILL.md](nrf-528xx-debug/SKILL.md) | 协助调试 nRF528xx 应用代码，排查编译/运行/连接问题 |

## 开发流程

```
nrf-connect-sdk-setup          nrf-connect-project-init         nrf-528xx-debug
(环境安装)          ──→        (项目初始化)            ──→       (调试排错)
```

1. **nrf-connect-sdk-setup**：检查所需工具链，安装缺失的组件，配置环境变量
2. **nrf-connect-project-init**：检测芯片型号，收集硬件配置，生成 CMake 项目，编译烧录
3. **nrf-528xx-debug**：在开发过程中排查编译错误、运行时崩溃、外设驱动等问题

## 使用方式

直接描述你的开发需求，系统会自动按需调用对应的子 skill。例如：

- "帮我搭建 nRF52840 的开发环境" → 调用 `nrf-connect-sdk-setup`
- "创建一个用 SPI 驱动 OLED 的项目" → 调用 `nrf-connect-project-init`
- "代码编译报错 undefined reference to gpio_pin_configure" → 调用 `nrf-528xx-debug`
