# Android dev network setup

Ngay cap nhat: 2026-09-16

## Van de da gap

Khi chay app tren dien thoai Android that, `localhost`/`127.0.0.1` tren dien thoai khong phai la `localhost` cua PC. Truoc do app co luc phu thuoc `adb reverse`, nhung tren thiet bi hien tai `adb reverse` hien rule dung ma goi health qua `127.0.0.1:8081` van khong on dinh.

Dung IP LAN cua PC thi dien thoai goi duoc backend. Tuy nhien khong nen hardcode IP nay vao source, vi doi Wi-Fi, doi PC, doi dien thoai se lai hong.

## Giai phap da cau hinh

- Source Flutter khong con chua IP Wi-Fi co dinh.
- `lib/core/config/api_config.dart` ho tro:
  - `API_BASE_URL` cho mot URL cu the.
  - `API_BASE_URLS` cho nhieu URL fallback.
- Them `scripts/run-android-dev.ps1` de tu dong:
  - khoi dong Docker service,
  - ep Docker dev API dung cong `8081`,
  - chon Android device,
  - do IPv4 LAN cua PC,
  - cau hinh `adb reverse` lam fallback,
  - chay/build Flutter voi danh sach API URL phu hop may hien tai.

## Lenh nen dung hang ngay

Tu root repo:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android-dev.ps1
```

Neu dang cam nhieu device/emulator:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android-dev.ps1 -DeviceId RF8N32408EN
```

Neu chi muon build va cai lai APK debug:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android-dev.ps1 -DeviceId RF8N32408EN -InstallOnly
```

Neu PC moi khong tu do duoc IP, truyen thu cong:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android-dev.ps1 -HostIp <IP-LAN-cua-PC>
```

## Ket qua kiem tra

- `flutter test`: pass 2/2.
- Script moi da chay `docker compose up -d` thanh cong.
- Backend health tren host tra `UP`.
- Script tu do LAN API URL hien tai: `http://192.168.1.6:8081/api/v1`.
- Script cau hinh `adb reverse tcp:8081 tcp:8081` lam fallback.
- `flutter build apk --debug` qua script thanh cong.
- `adb install -r app-debug.apk` qua script thanh cong.
- Script mo app `com.example.gomate` thanh cong.
- Kiem tra tu shell Android goi LAN health tra `HTTP 200` va `{"status":"UP"}`.

## Luu y quan trong

- Moi lan doi PC, doi Wi-Fi, doi dien thoai, hoac cai lai APK debug, hay chay lai script.
- `API_BASE_URL`/`API_BASE_URLS` duoc gan luc `flutter run`/`flutter build`, nen APK cu van giu cau hinh cu.
- Windows Firewall phai cho phep thiet bi trong cung Wi-Fi truy cap cong `8081` neu dung duong LAN.
- Khong sua IP truc tiep trong `lib/core/config/api_config.dart`.
- Neu chua co `android/app/google-services.json`, debug APK van build duoc de test email/password; Google/Firebase sign-in chi chay sau khi them file Firebase that.
- Android Gradle dang tat `kotlin.incremental` de tranh loi Kotlin cache khi project o o `F:` con Pub cache o o `C:` tren Windows.
- Script tu dong xoa rule `adb reverse tcp:8080` cu khi dang chay dev port `8081`, de tranh nham lan voi loi cong `8080` da bi `AgentService` giu.
- Script chay `docker compose up -d --build` de sau khi pull code moi thi API image duoc build lai, tranh backend chay image cu.
- Google/Firebase sign-in tren backend can `FIREBASE_ENABLED=true`, `FIREBASE_PROJECT_ID=...`, va file `backend/secrets/firebase-service-account.json`; root `docker-compose.yml` da mount file nay vao `/run/secrets`.
