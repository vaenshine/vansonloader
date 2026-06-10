# VansonLoader

**VansonLoader ist die dylib-Edition von VansonMod. Es ist ein abgeleitetes Runtime-Paket für ein injiziertes Floating Panel im Zielprozess.**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | **Deutsch** | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Package](https://img.shields.io/badge/Package-Theos%20dylib-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)

---

## Einführung

**VansonMod** ist die Haupt-App für TrollStore und bietet den vollständigen eigenständigen Workflow: Prozessauswahl, Speichersuche, erweiterte Pointer-Workflows, RVA-Patching, Skriptwerkzeuge, Archivverwaltung und Einstellungen.

**VansonLoader** ist ein abgeleitetes Produkt für injizierte Laufzeitumgebungen. Es bündelt ausgewählte VM-Funktionen als dylib und zeigt sie als Overlay-Panel im Zielprozess an.

## Beziehung Zu VansonMod

- **VansonMod** ist die primäre App und der Haupt-Release-Einstieg: [vaenshine/VansonMod](https://github.com/vaenshine/VansonMod).
- **VansonLoader** ist die dylib-Ableitung derselben Projektrichtung.
- Aus VM exportierte Mod- und Skriptdaten können in unterstützten Loader-Workflows verwendet werden.
- VansonMod bleibt der vollständige Editor für erweiterte Pointer-Workflows, App-Auswahl, Archivverwaltung und globale Einstellungen.

## Aktueller Umfang

- Floating Panel und Schnellöffnungsbutton im injizierten Prozess.
- Speichersuche, Ergebnisliste, Speicherbrowser, Wertbearbeitung, Such-Timeline-Wiederherstellung und Undo für die letzte manuelle Wertänderung.
- Import und Speicherung von VM/VL `.vm`- und `.vmsc`-Daten.
- Importierte Pointer-Elemente für Wertanzeige, Wertschreiben, Lock-ähnliche Steuerung und Ergebnis-UI-Modi.
- Importierte RVA-Elemente für Runtime-Patch und Restore.
- Importierte Signature-Elemente für Scan, Ergebnisanzeige und optionales Runtime-Patching.
- JavaScript-Ausführung mit H5GG-ähnlichen Aliasfunktionen und VM/VL Memory APIs.
- Watch Overlay, Instruction Inspector und RVA-Übergabe, sofern die Runtime-Umgebung sie unterstützt.

## Build

```sh
make clean package FINALPACKAGE=1 DEBUG=0
```

## Release

VansonLoader hat ein eigenes Release-Skript:

```sh
./scripts/release.sh
```

## Haftungsausschluss

Dieses Projekt ist für Sicherheitsforschung, Reverse-Engineering-Lernen und konforme technische Tests gedacht.

Verwenden Sie es in rechtmäßigen Umgebungen und respektieren Sie die geltenden Regeln der Ziel-Apps und Systeme. Betriebsrisiken und rechtliche Verantwortung trägt der Benutzer.

## Lizenz

GPL-3.0. Siehe [LICENSE](./LICENSE).
