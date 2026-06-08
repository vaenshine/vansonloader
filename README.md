# VansonLoader

**VansonLoader is the dylib edition of VansonMod. It is a derived runtime package that brings selected VM workflows into an injected in-process floating panel.**

**English** | [简体中文](./docs/README_CN.md) | [繁體中文](./docs/README_TW.md) | [العربية](./docs/README_AR.md) | [Deutsch](./docs/README_DE.md) | [Español](./docs/README_ES.md) | [Français](./docs/README_FR.md) | [日本語](./docs/README_JA.md) | [한국어](./docs/README_KO.md) | [Português](./docs/README_PT.md) | [Русский](./docs/README_RU.md) | [ไทย](./docs/README_TH.md) | [Tiếng Việt](./docs/README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Package](https://img.shields.io/badge/Package-Theos%20dylib-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)

---

## Introduction

**VansonMod** is the main TrollStore application. It provides the full standalone workflow: process selection, memory search, advanced pointer workflows, RVA patching, script tools, archive management, and settings.

**VansonLoader** is a companion derived product for injected runtime environments. It packages selected VM features as a dylib and exposes them through an overlay panel inside the target process.

## Relationship With VansonMod

- **VansonMod** is the primary app and release entry point: [vaenshine/VansonMod](https://github.com/vaenshine/VansonMod).
- **VansonLoader** is the dylib-style derivative built from the same project direction.
- VM-exported mod and script data can be consumed by Loader in supported runtime workflows.
- VansonMod remains the full editor for advanced pointer workflows, app selection, archive management, and global settings.

## Current Scope

- Floating overlay panel and quick open button inside the injected process.
- Memory search panel, memory results, memory browsing, and value editing.
- Import and storage for VM/VL `.vm` and `.vmsc` data.
- Imported pointer items for value display, value write, lock-style controls, and per-result UI modes.
- Imported RVA items for runtime patch and restore.
- Imported signature items for scan, result display, and optional runtime patch handling.
- JavaScript script execution with H5GG-style helper aliases and VM/VL memory APIs.
- Watch overlay, instruction inspector, and RVA handoff paths where supported by the runtime environment.

## Build

```sh
make clean package FINALPACKAGE=1 DEBUG=0
```

## Release

VansonLoader has its own release script:

```sh
./scripts/release.sh
```

## Disclaimer

This project is intended for security research, reverse engineering learning, and compliant technical testing scenarios.

Use it in lawful environments and respect applicable rules for target apps and systems. Operational risks and legal responsibilities from use are borne by the user.

## License

GPL-3.0. See [LICENSE](./LICENSE).
