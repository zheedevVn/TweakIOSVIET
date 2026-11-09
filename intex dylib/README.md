# Free Fire dylib source no key

Source được xuất từ 33e-git. Đây là menu Free Fire, không phải Honor.

- Bỏ màn nhập key, phiên xác thực, thông báo khóa và endpoint Firebase.
- Không kèm web quản lý key, Database Secret, token hoặc tài khoản.
- Menu khởi tạo trực tiếp sau khi host sẵn sàng, giữ cơ chế chờ startup và quản lý overlay gốc.
- Bỏ dịch vụ offset từ xa; GameFacade.static_fields dùng 0xB8 theo Il2CppClass_1 trong dump 1.132.1. Không có yêu cầu mạng lấy offset.
- Không kèm TIPA, IPA game, dump, SDK hay dylib build sẵn.

## Build

Cần Theos và iPhoneOS SDK16.5 trên macOS/Linux. Đặt THEOS phù hợp máy.

```sh
make clean package FINALPACKAGE=1 FOR_RELEASE=1
# Free Fire MAX với profile hiện có:
make clean package GAME_VARIANT=max FINALPACKAGE=1 FOR_RELEASE=1
```

Kết quả: packages/libsubsystem.dylib. Source hỗ trợ profile game có sẵn; cập nhật OB cần xác minh lại offset.
Đã kiểm tra source và gói ZIP; không khẳng định chạy trên OB mới hay mọi thiết bị.
Chi tiết thay đổi và SHA-256 nằm trong source-manifest.json.
