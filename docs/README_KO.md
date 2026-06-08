# VansonLoader

**VansonLoader는 VansonMod의 dylib 에디션입니다. VansonMod 런타임에서 파생된 패키지로, 선택된 VM 워크플로를 주입된 프로세스 안의 플로팅 패널로 제공합니다.**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | **한국어** | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Package](https://img.shields.io/badge/Package-Theos%20dylib-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)

---

## 소개

**VansonMod**는 TrollStore용 메인 앱입니다. 프로세스 선택, 메모리 검색, 고급 포인터 워크플로, RVA 패치, 스크립트 도구, 아카이브 관리, 설정을 포함한 전체 독립 워크플로를 제공합니다.

**VansonLoader**는 주입 런타임 환경을 위한 파생 제품입니다. 선택된 VM 기능을 dylib로 패키징하고 대상 프로세스 안의 오버레이 패널에서 사용할 수 있게 합니다.

## VansonMod와의 관계

- **VansonMod**는 기본 앱이자 주요 릴리스 진입점입니다: [vaenshine/VansonMod](https://github.com/vaenshine/VansonMod).
- **VansonLoader**는 같은 프로젝트 방향에서 파생된 dylib 버전입니다.
- VM에서 내보낸 mod 및 script 데이터는 Loader가 지원하는 런타임 워크플로에서 사용할 수 있습니다.
- VansonMod는 고급 포인터 워크플로, 앱 선택, 아카이브 관리, 전역 설정을 위한 전체 편집기입니다.

## 현재 범위

- 주입된 프로세스 안의 플로팅 패널과 빠른 열기 버튼.
- 메모리 검색 패널, 검색 결과, 메모리 브라우징, 값 편집.
- VM/VL `.vm` 및 `.vmsc` 데이터 가져오기와 저장.
- 가져온 pointer 항목의 값 표시, 값 쓰기, lock 스타일 제어, 결과별 UI 모드.
- 가져온 RVA 항목의 런타임 patch 및 restore.
- 가져온 signature 항목의 scan, 결과 표시, 선택적 런타임 patch.
- H5GG 스타일 헬퍼 alias와 VM/VL 메모리 API를 포함한 JavaScript 실행.
- 런타임 환경이 지원하는 watch overlay, instruction inspector, RVA 전달 경로.

## 빌드

```sh
make clean package FINALPACKAGE=1 DEBUG=0
```

## 릴리스

VansonLoader에는 독립 릴리스 스크립트가 있습니다.

```sh
./scripts/release.sh
```

## 면책 조항

이 프로젝트는 보안 연구, 리버스 엔지니어링 학습, 규정을 준수하는 기술 테스트를 위한 것입니다.

합법적인 환경에서 사용하고 대상 앱과 시스템의 적용 규칙을 존중하십시오. 사용으로 인한 운영상 위험과 법적 책임은 사용자에게 있습니다.

## 라이선스

GPL-3.0. [LICENSE](./LICENSE)를 참조하십시오.
