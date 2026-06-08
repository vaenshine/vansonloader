# VansonLoader

**VansonLoader — это dylib-редакция VansonMod. Это производный runtime-пакет, который переносит выбранные VM-сценарии в плавающую панель внутри внедренного процесса.**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | **Русский** | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Package](https://img.shields.io/badge/Package-Theos%20dylib-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)

---

## Введение

**VansonMod** — основное приложение для TrollStore. Оно предоставляет полный автономный рабочий процесс: выбор процесса, поиск в памяти, расширенные сценарии работы с указателями, RVA-патчи, инструменты скриптов, управление архивами и настройки.

**VansonLoader** — производный продукт для внедренных runtime-сред. Он упаковывает выбранные функции VM как dylib и предоставляет их через overlay-панель внутри целевого процесса.

## Связь С VansonMod

- **VansonMod** — основное приложение и главный вход для релизов: [vaenshine/VansonMod](https://github.com/vaenshine/VansonMod).
- **VansonLoader** — dylib-производная той же проектной линии.
- Данные mod и script, экспортированные из VM, могут использоваться в поддерживаемых runtime-сценариях Loader.
- VansonMod остается полным редактором для расширенных сценариев работы с указателями, выбора приложений, управления архивами и глобальных настроек.

## Текущий Объем

- Плавающая панель и кнопка быстрого открытия внутри внедренного процесса.
- Панель поиска памяти, результаты, просмотр памяти и редактирование значений.
- Импорт и хранение данных VM/VL `.vm` и `.vmsc`.
- Импортированные pointer-элементы для отображения значений, записи значений, lock-управления и UI-режимов результата.
- Импортированные RVA-элементы для runtime patch и restore.
- Импортированные signature-элементы для scan, отображения результатов и опционального runtime patch.
- Выполнение JavaScript с H5GG-подобными alias-функциями и VM/VL memory API.
- Watch overlay, instruction inspector и передача в RVA при поддержке runtime-среды.

## Сборка

```sh
make clean package FINALPACKAGE=1 DEBUG=0
```

## Релиз

У VansonLoader есть собственный релизный скрипт:

```sh
./scripts/release.sh
```

## Отказ От Ответственности

Проект предназначен для исследований безопасности, изучения reverse engineering и совместимых технических тестов.

Используйте его в законных средах и соблюдайте применимые правила целевых приложений и систем. Операционные риски и юридическая ответственность за использование лежат на пользователе.

## Лицензия

GPL-3.0. См. [LICENSE](./LICENSE).
