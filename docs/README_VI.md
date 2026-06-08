# VansonLoader

**VansonLoader là phiên bản dylib của VansonMod. Đây là gói runtime phái sinh đưa một số workflow VM vào bảng nổi được inject trong tiến trình mục tiêu.**

[English](../README.md) | [简体中文](./README_CN.md) | [繁體中文](./README_TW.md) | [العربية](./README_AR.md) | [Deutsch](./README_DE.md) | [Español](./README_ES.md) | [Français](./README_FR.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md) | [Português](./README_PT.md) | [Русский](./README_RU.md) | [ไทย](./README_TH.md) | **Tiếng Việt**

![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-black)
![Package](https://img.shields.io/badge/Package-Theos%20dylib-blue)
![License](https://img.shields.io/badge/License-GPL--3.0-green)

---

## Giới Thiệu

**VansonMod** là ứng dụng chính cho TrollStore. Nó cung cấp workflow độc lập đầy đủ: chọn tiến trình, tìm kiếm bộ nhớ, workflow pointer nâng cao, patch RVA, công cụ script, quản lý archive và cài đặt.

**VansonLoader** là sản phẩm phái sinh cho môi trường runtime được inject. Nó đóng gói một số tính năng VM thành dylib và hiển thị qua bảng overlay trong tiến trình mục tiêu.

## Quan Hệ Với VansonMod

- **VansonMod** là ứng dụng chính và điểm phát hành chính: [vaenshine/VansonMod](https://github.com/vaenshine/VansonMod).
- **VansonLoader** là bản phái sinh dạng dylib của cùng hướng dự án.
- Dữ liệu mod và script xuất từ VM có thể dùng trong các workflow runtime được Loader hỗ trợ.
- VansonMod vẫn là trình chỉnh sửa đầy đủ cho workflow pointer nâng cao, chọn app, quản lý archive và cài đặt toàn cục.

## Phạm Vi Hiện Tại

- Bảng nổi và nút mở nhanh trong tiến trình được inject.
- Bảng tìm kiếm bộ nhớ, kết quả, duyệt bộ nhớ và chỉnh sửa giá trị.
- Import và lưu dữ liệu VM/VL `.vm` và `.vmsc`.
- Mục pointer đã import để hiển thị giá trị, ghi giá trị, điều khiển kiểu lock và chế độ UI theo kết quả.
- Mục RVA đã import để patch và restore trong runtime.
- Mục signature đã import để scan, hiển thị kết quả và patch runtime tùy chọn.
- Chạy JavaScript với alias kiểu H5GG và API bộ nhớ VM/VL.
- Watch overlay, instruction inspector và đường dẫn chuyển sang RVA khi môi trường runtime hỗ trợ.

## Build

```sh
make clean package FINALPACKAGE=1 DEBUG=0
```

## Release

VansonLoader có script release riêng:

```sh
./scripts/release.sh
```

## Tuyên Bố Miễn Trừ

Dự án này dành cho nghiên cứu bảo mật, học reverse engineering và kiểm thử kỹ thuật tuân thủ.

Hãy sử dụng trong môi trường hợp pháp và tôn trọng quy tắc áp dụng của app và hệ thống mục tiêu. Rủi ro vận hành và trách nhiệm pháp lý từ việc sử dụng thuộc về người dùng.

## Giấy Phép

GPL-3.0. Xem [LICENSE](./LICENSE).
