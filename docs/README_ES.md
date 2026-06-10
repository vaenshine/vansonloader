# VansonLoader

**VansonLoader es la edición dylib de VansonMod. Es un paquete derivado de runtime que lleva flujos seleccionados de VM a un panel flotante inyectado dentro del proceso objetivo.**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | **Español** | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Package](https://img.shields.io/badge/Package-Theos%20dylib-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)

---

## Introducción

**VansonMod** es la aplicación principal para TrollStore y ofrece el flujo independiente completo: selección de procesos, búsqueda de memoria, flujos avanzados de punteros, parches RVA, herramientas de script, gestión de archivos y ajustes.

**VansonLoader** es un producto derivado para entornos de runtime inyectados. Empaqueta funciones seleccionadas de VM como dylib y las muestra en un panel superpuesto dentro del proceso objetivo.

## Relación Con VansonMod

- **VansonMod** es la aplicación principal y el punto de publicación principal: [vaenshine/VansonMod](https://github.com/vaenshine/VansonMod).
- **VansonLoader** es la derivación dylib de la misma línea de proyecto.
- Los datos mod y script exportados desde VM pueden usarse en flujos de runtime compatibles con Loader.
- VansonMod conserva la edición completa para flujos avanzados de punteros, selección de apps, gestión de archivos y ajustes globales.

## Alcance Actual

- Panel flotante y botón de apertura rápida dentro del proceso inyectado.
- Panel de búsqueda de memoria, resultados, exploración de memoria, edición de valores, restauración desde la línea de tiempo y deshacer la última escritura manual.
- Importación y almacenamiento de datos VM/VL `.vm` y `.vmsc`.
- Elementos pointer importados para mostrar valores, escribir valores, controles tipo lock y modos UI por resultado.
- Elementos RVA importados para patch y restore en runtime.
- Elementos signature importados para scan, visualización de resultados y patch opcional en runtime.
- Ejecución de JavaScript con alias estilo H5GG y APIs de memoria VM/VL.
- Watch overlay, inspector de instrucciones y rutas hacia RVA cuando el entorno de runtime lo soporte.

## Compilación

```sh
make clean package FINALPACKAGE=1 DEBUG=0
```

## Publicación

VansonLoader tiene su propio script de publicación:

```sh
./scripts/release.sh
```

## Aviso Legal

Este proyecto está destinado a investigación de seguridad, aprendizaje de ingeniería inversa y pruebas técnicas compatibles.

Úselo en entornos legales y respete las reglas aplicables de las apps y sistemas objetivo. Los riesgos operativos y responsabilidades legales derivados del uso corresponden al usuario.

## Licencia

GPL-3.0. Consulte [LICENSE](./LICENSE).
