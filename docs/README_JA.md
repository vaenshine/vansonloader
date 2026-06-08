# VansonLoader

**VansonLoader は VansonMod の dylib 版です。VansonMod のランタイムから派生したパッケージで、選択された VM ワークフローを注入先プロセス内のフローティングパネルとして提供します。**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | **日本語** | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | [Tiếng Việt](./README_VI.md)

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Package](https://img.shields.io/badge/Package-Theos%20dylib-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)

---

## 概要

**VansonMod** は TrollStore 向けのメインアプリです。プロセス選択、メモリ検索、高度なポインタワークフロー、RVA パッチ、スクリプトツール、アーカイブ管理、設定を含む完全なスタンドアロンワークフローを提供します。

**VansonLoader** は注入型ランタイム環境向けの派生プロダクトです。選択された VM 機能を dylib としてまとめ、対象プロセス内のオーバーレイパネルから利用できるようにします。

## VansonMod との関係

- **VansonMod** はメインアプリであり、主要なリリース入口です: [vaenshine/VansonMod](https://github.com/vaenshine/VansonMod)。
- **VansonLoader** は同じプロジェクト方向から派生した dylib 版です。
- VM からエクスポートされた mod と script データは、Loader が対応するランタイムワークフローで利用できます。
- VansonMod は高度なポインタワークフロー、アプリ選択、アーカイブ管理、グローバル設定の完全な編集環境です。

## 現在の範囲

- 注入先プロセス内のフローティングパネルとクイックオープンボタン。
- メモリ検索パネル、検索結果、メモリブラウズ、値編集。
- VM/VL `.vm` と `.vmsc` データのインポートと保存。
- インポート済み pointer 項目の値表示、値書き込み、lock 形式の制御、結果ごとの UI モード。
- インポート済み RVA 項目のランタイム patch と restore。
- インポート済み signature 項目の scan、結果表示、任意のランタイム patch。
- H5GG 風ヘルパーエイリアスと VM/VL メモリ API を備えた JavaScript 実行。
- ランタイム環境が対応する場合の watch overlay、instruction inspector、RVA 連携。

## ビルド

```sh
make clean package FINALPACKAGE=1 DEBUG=0
```

## リリース

VansonLoader には独立したリリーススクリプトがあります。

```sh
./scripts/release.sh
```

## 免責事項

本プロジェクトは、セキュリティ研究、リバースエンジニアリング学習、準拠した技術テストを目的としています。

合法的な環境で使用し、対象アプリとシステムの適用ルールを尊重してください。使用に伴う操作上のリスクと法的責任はユーザーが負います。

## ライセンス

GPL-3.0。詳しくは [LICENSE](./LICENSE) を参照してください。
