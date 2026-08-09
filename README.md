# App đo tốc độ GPS - Hướng dẫn build & cài lên iPhone 6s (jailbreak, không cần Mac, không cần cài Flutter)

Giờ đây bạn **không cần cài Flutter trên máy, không cần chạy lệnh gì hết** —
toàn bộ việc sinh khung project, gắn quyền GPS, build ra file .ipa đều để
GitHub Actions tự làm hết. Bạn chỉ cần đưa đúng mấy file này lên GitHub.

## Các file trong gói này
- `main.dart` — code chính của app (sẽ tự được đặt vào đúng vị trí `lib/main.dart`)
- `pubspec.yaml` — khai báo package cần dùng
- `Info.plist` — đã có sẵn khai báo quyền GPS, tránh app crash khi xin quyền
- `.gitignore`
- `.github/workflows/build-ios.yml` — kịch bản tự động build

## Bước 1: Tạo repo trên GitHub
Vào github.com → **New repository** → đặt tên (ví dụ `speedo_app`) → Create.

## Bước 2: Upload đúng cấu trúc thư mục
Cách dễ nhất nếu ngại dùng lệnh `git`: vào repo vừa tạo → **Add file** →
**Upload files** → kéo thả lần lượt:
- `main.dart`, `pubspec.yaml`, `Info.plist`, `.gitignore` vào **thư mục gốc**
- Riêng `build-ios.yml` phải nằm đúng đường dẫn `.github/workflows/build-ios.yml`
  (trên giao diện web GitHub, gõ thẳng đường dẫn đó vào ô tên file lúc tạo file
  mới, GitHub sẽ tự tạo thư mục con giúp bạn)

Hoặc dùng git dòng lệnh (nếu quen thuộc hơn):
```
git init
git add .
git commit -m "speedo app"
git branch -M main
git remote add origin https://github.com/<tên-bạn>/speedo_app.git
git push -u origin main
```

## Bước 3: GitHub tự động build — bạn không cần làm gì thêm
Ngay sau khi push/upload xong, workflow tự chạy theo thứ tự:
1. Cài Flutter trên máy macOS ảo (miễn phí do GitHub cấp)
2. Tự sinh khung project (`flutter create .`) — bước mà trước đây bạn phải tự chạy tay
3. Tự copy `main.dart` vào đúng `lib/main.dart`
4. Tự copy `Info.plist` (đã có quyền GPS) đè vào `ios/Runner/Info.plist`
5. Build ra app, đóng gói thành `.ipa` không cần chữ ký (vì máy đích đã jailbreak)

Xem kết quả:
1. Vào repo trên GitHub → tab **Actions**
2. Chờ workflow "Build iOS IPA" chạy xong (khoảng 5-10 phút), thấy dấu tích xanh ✅
   (nếu dấu ❌ đỏ, bấm vào xem log lỗi, gửi lại cho mình xem giúp)
3. Bấm vào lần chạy đó → kéo xuống mục **Artifacts** → tải file `speedo_app-ipa.zip`
4. Giải nén ra được file `speedo_app.ipa`

## Bước 4: Cài AppSync Unified trên iPhone (một lần duy nhất, nếu chưa có)
- Mở Cydia/Sileo → thêm nguồn AppSync Unified phù hợp với bản jailbreak đang dùng
- Cài gói AppSync Unified → cho phép cài .ipa không cần chữ ký Apple

## Bước 5: Cài .ipa lên iPhone qua USB
Trên Windows/Linux:
```
pip install --user libimobiledevice   # hoặc cài qua trình quản lý gói của distro
ideviceinstaller -i speedo_app.ipa
```
Hoặc dùng công cụ GUI như 3uTools (Windows) → kéo thả file .ipa vào mục "Cài ứng dụng".

## Bước 6: Chạy thử
Mở app trên iPhone, cấp quyền vị trí khi được hỏi, ra ngoài trời (GPS trong nhà
kém chính xác) để test tốc độ di chuyển thực tế.

## Ghi chú
- `position.speed` từ package geolocator trả về m/s, độ chính xác phụ thuộc tín hiệu GPS,
  thường sai số vài km/h ở tốc độ thấp.
- iPhone 6s tối đa chạy iOS 15.x — bản geolocator trong `pubspec.yaml` đã test ổn với iOS 12+.
- Vì mình không có môi trường Flutter thật để tự build-test trước khi gửi bạn,
  nếu workflow báo lỗi đỏ ở bước nào, chụp màn hình log lỗi gửi mình, mình sẽ
  sửa file tương ứng ngay.
