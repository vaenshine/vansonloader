# VansonLoader

**VansonLoader est l'édition dylib de VansonMod. C'est un paquet runtime dérivé qui apporte certains flux VM dans un panneau flottant injecté dans le processus cible.**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | **Français** | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Package](https://img.shields.io/badge/Package-Theos%20dylib-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)

---

## Introduction

**VansonMod** est l'application principale pour TrollStore. Elle fournit le flux autonome complet : sélection de processus, recherche mémoire, flux avancés de pointeurs, patch RVA, outils de script, gestion d'archives et réglages.

**VansonLoader** est un produit dérivé pour les environnements runtime injectés. Il empaquette certaines fonctions VM en dylib et les expose via un panneau superposé dans le processus cible.

## Relation Avec VansonMod

- **VansonMod** est l'application principale et le point d'entrée des releases : [vaenshine/VansonMod](https://github.com/vaenshine/VansonMod).
- **VansonLoader** est la dérivation dylib de la même direction de projet.
- Les données mod et script exportées par VM peuvent être utilisées dans les flux runtime pris en charge par Loader.
- VansonMod reste l'éditeur complet pour la flux avancés de pointeurs, la sélection d'apps, la gestion d'archives et les réglages globaux.

## Périmètre Actuel

- Panneau flottant et bouton d'ouverture rapide dans le processus injecté.
- Recherche mémoire, résultats, navigation mémoire et édition de valeurs.
- Importation et stockage des données VM/VL `.vm` et `.vmsc`.
- Éléments pointer importés pour affichage de valeur, écriture de valeur, contrôles de type lock et modes UI par résultat.
- Éléments RVA importés pour patch et restore au runtime.
- Éléments signature importés pour scan, affichage des résultats et patch runtime optionnel.
- Exécution JavaScript avec alias de style H5GG et APIs mémoire VM/VL.
- Watch overlay, inspecteur d'instructions et chemins vers RVA lorsque l'environnement runtime les prend en charge.

## Build

```sh
make clean package FINALPACKAGE=1 DEBUG=0
```

## Release

VansonLoader dispose de son propre script de release :

```sh
./scripts/release.sh
```

## Avertissement

Ce projet est destiné à la recherche en sécurité, à l'apprentissage de l'ingénierie inverse et aux tests techniques conformes.

Utilisez-le dans des environnements légaux et respectez les règles applicables des apps et systèmes ciblés. Les risques opérationnels et responsabilités légales liés à l'utilisation relèvent de l'utilisateur.

## Licence

GPL-3.0. Voir [LICENSE](./LICENSE).
