# VansonLoader

**VansonLoader 是 VansonMod 的 dylib 版本，是从 VansonMod 运行时派生出的注入环境浮窗工具。**

[English](../README.md) | **简体中文** | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Package](https://img.shields.io/badge/Package-Theos%20dylib-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)

---

## 简介

**VansonMod** 是主 TrollStore 应用，提供完整的独立工作流：进程选择、内存搜索、高级指针工作流、RVA 补丁、脚本工具、归档管理和设置。

**VansonLoader** 是面向注入运行环境的派生产物，把 VM 的部分运行时能力打包为 dylib，并在目标进程内提供浮窗面板。

## 与 VansonMod 的关系

- **VansonMod** 是主应用和主发布入口：[vaenshine/VansonMod](https://github.com/vaenshine/VansonMod)。
- **VansonLoader** 是同一项目方向下的 dylib 派生版本。
- VM 导出的 mod 和脚本数据可在 Loader 支持的运行时流程中使用。
- VansonMod 负责完整编辑能力，包括高级指针工作流、应用选择、归档管理和全局设置。

## 当前范围

- 注入进程内的浮窗面板和快速打开按钮。
- 内存搜索面板、搜索结果、内存浏览、值编辑、搜索时间线恢复，以及上一次手动写入撤回。
- 导入和存储 VM/VL `.vm` 与 `.vmsc` 数据。
- 已导入 pointer 项的数值显示、写入、锁定式控制和结果 UI 模式。
- 已导入 RVA 项的运行时 patch 与 restore。
- 已导入 signature 项的扫描、结果显示和可选运行时 patch。
- 带 H5GG 风格辅助别名和 VM/VL 内存 API 的 JavaScript 脚本执行。
- 受运行环境支持时提供 watch 浮窗、指令 inspector 和 RVA 转交路径。

## 构建

```sh
make clean package FINALPACKAGE=1 DEBUG=0
```

## 发布

VansonLoader 有独立的发布脚本：

```sh
./scripts/release.sh
```

## 免责声明

本项目用于安全研究、逆向工程学习及合规技术测试场景。

请在合法环境中使用，并尊重目标应用与系统的适用规则。使用产生的操作风险和法律责任由使用者自行承担。

## 开源协议

GPL-3.0。详见 [LICENSE](./LICENSE)。
