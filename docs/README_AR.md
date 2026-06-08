# VansonLoader

**VansonLoader هو إصدار dylib من VansonMod. إنه حزمة runtime مشتقة تنقل بعض تدفقات VM إلى لوحة عائمة محقونة داخل العملية المستهدفة.**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | **العربية** | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Package](https://img.shields.io/badge/Package-Theos%20dylib-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)

---

## المقدمة

**VansonMod** هو التطبيق الرئيسي لبيئة TrollStore. يوفر سير عمل مستقلًا كاملًا يشمل اختيار العملية، بحث الذاكرة، تدفقات المؤشرات المتقدمة، تصحيحات RVA، أدوات السكربت، إدارة الأرشيفات، والإعدادات.

**VansonLoader** هو منتج مشتق لبيئات runtime المحقونة. يقوم بتجميع ميزات مختارة من VM كملف dylib ويعرضها عبر لوحة overlay داخل العملية المستهدفة.

## العلاقة مع VansonMod

- **VansonMod** هو التطبيق الأساسي ومدخل الإصدارات الرئيسي: [vaenshine/VansonMod](https://github.com/vaenshine/VansonMod).
- **VansonLoader** هو اشتقاق dylib من نفس اتجاه المشروع.
- يمكن استخدام بيانات mod و script المصدرة من VM ضمن تدفقات runtime التي يدعمها Loader.
- يبقى VansonMod المحرر الكامل لتدفقات المؤشرات المتقدمة، اختيار التطبيقات، إدارة الأرشيفات، والإعدادات العامة.

## النطاق الحالي

- لوحة عائمة وزر فتح سريع داخل العملية المحقونة.
- لوحة بحث الذاكرة، النتائج، تصفح الذاكرة، وتعديل القيم.
- استيراد وتخزين بيانات VM/VL بصيغ `.vm` و `.vmsc`.
- عناصر pointer المستوردة لعرض القيم، كتابة القيم، تحكم شبيه بالقفل، وأنماط UI لكل نتيجة.
- عناصر RVA المستوردة من أجل patch و restore أثناء runtime.
- عناصر signature المستوردة من أجل scan، عرض النتائج، و patch اختياري أثناء runtime.
- تشغيل JavaScript مع أسماء مساعدة بأسلوب H5GG وواجهات VM/VL للذاكرة.
- Watch overlay و instruction inspector ومسارات تسليم إلى RVA عندما تدعمها بيئة runtime.

## البناء

```sh
make clean package FINALPACKAGE=1 DEBUG=0
```

## الإصدار

يملك VansonLoader سكريبت إصدار مستقل:

```sh
./scripts/release.sh
```

## إخلاء المسؤولية

هذا المشروع مخصص لأبحاث الأمان، تعلم الهندسة العكسية، والاختبارات التقنية المتوافقة.

استخدمه في بيئات قانونية واحترم القواعد المطبقة على التطبيقات والأنظمة المستهدفة. يتحمل المستخدم مخاطر التشغيل والمسؤوليات القانونية الناتجة عن الاستخدام.

## الترخيص

GPL-3.0. راجع [LICENSE](./LICENSE).
