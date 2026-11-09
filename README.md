# TweakIOSVIET (Free Fire Dylib & TIPA)

Dự án mod/tweak menu Free Fire iOS được phát triển và duy trì bởi **Zhee Dev** (`zheedevVn`).

- Đã loại bỏ hoàn toàn hệ thống check key / xác thực từ xa.
- Khởi tạo trực tiếp overlay sau khi host game sẵn sàng.
- Hỗ trợ cả Free Fire thường (`GAME_VARIANT=th`) và Free Fire MAX (`GAME_VARIANT=max`).
- Tích hợp GitHub Actions tự động build ra file dylib và đóng gói `.tipa`.

## Hướng dẫn Build với Theos

Cần Theos và iPhoneOS SDK 16.5 trên macOS / Linux:

```bash
# Build bản Free Fire thường:
make clean package FINALPACKAGE=1 FOR_RELEASE=1

# Build bản Free Fire MAX:
make clean package GAME_VARIANT=max FINALPACKAGE=1 FOR_RELEASE=1
```

## Tác giả / Bản quyền
- **Developer:** Zhee Dev
- **GitHub:** [zheedevVn/TweakIOSVIET](https://github.com/zheedevVn/TweakIOSVIET)
