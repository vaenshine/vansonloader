# VansonLoader

**VansonLoader คือรุ่น dylib ของ VansonMod เป็นแพ็กเกจ runtime ที่แยกออกมาเพื่อนำ workflow บางส่วนของ VM ไปใช้ในแผงลอยที่ถูก inject อยู่ใน process เป้าหมาย**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | **ไทย** | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Package](https://img.shields.io/badge/Package-Theos%20dylib-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)

---

## บทนำ

**VansonMod** คือแอปหลักสำหรับ TrollStore มี workflow แบบ standalone ครบถ้วน เช่น เลือก process, ค้นหา memory, workflow pointer ขั้นสูง, patch RVA, เครื่องมือ script, จัดการ archive และตั้งค่า

**VansonLoader** คือผลิตภัณฑ์ที่แยกออกมาสำหรับ runtime environment แบบ inject โดยรวมความสามารถบางส่วนของ VM เป็น dylib และแสดงผ่าน overlay panel ภายใน process เป้าหมาย

## ความสัมพันธ์กับ VansonMod

- **VansonMod** คือแอปหลักและจุดหลักสำหรับ release: [vaenshine/VansonMod](https://github.com/vaenshine/VansonMod)
- **VansonLoader** คือรุ่น dylib ที่แยกออกมาจากแนวทางเดียวกันของโปรเจกต์
- ข้อมูล mod และ script ที่ export จาก VM สามารถใช้ใน workflow runtime ที่ Loader รองรับ
- VansonMod ยังเป็น editor แบบครบถ้วนสำหรับ advanced pointer workflows, app selection, archive management และ global settings

## ขอบเขตปัจจุบัน

- Floating panel และปุ่มเปิดเร็วภายใน process ที่ถูก inject
- Memory search panel, ผลลัพธ์, memory browser และการแก้ไขค่า
- Import และจัดเก็บข้อมูล VM/VL `.vm` และ `.vmsc`
- รายการ pointer ที่ import แล้วสำหรับแสดงค่า เขียนค่า ควบคุมแบบ lock และ UI mode ต่อผลลัพธ์
- รายการ RVA ที่ import แล้วสำหรับ runtime patch และ restore
- รายการ signature ที่ import แล้วสำหรับ scan, แสดงผลลัพธ์ และ runtime patch แบบเลือกใช้
- รัน JavaScript พร้อม alias แบบ H5GG และ VM/VL memory APIs
- Watch overlay, instruction inspector และเส้นทางส่งต่อไป RVA เมื่อ runtime environment รองรับ

## Build

```sh
make clean package FINALPACKAGE=1 DEBUG=0
```

## Release

VansonLoader มีสคริปต์ release ของตัวเอง:

```sh
./scripts/release.sh
```

## ข้อจำกัดความรับผิด

โปรเจกต์นี้มีไว้สำหรับงานวิจัยด้านความปลอดภัย การเรียนรู้ reverse engineering และการทดสอบเชิงเทคนิคที่สอดคล้องกับกฎระเบียบ

ใช้งานในสภาพแวดล้อมที่ถูกต้องตามกฎหมาย และเคารพกฎที่เกี่ยวข้องของแอปและระบบเป้าหมาย ความเสี่ยงจากการใช้งานและความรับผิดชอบทางกฎหมายเป็นของผู้ใช้

## License

GPL-3.0. ดู [LICENSE](./LICENSE)
