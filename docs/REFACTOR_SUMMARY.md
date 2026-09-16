# Tom tat refactor GoMate Auth

Ngay thuc hien: 2026-09-12

## Da tiep thu va dua tri thuc vao repo

- Them `AGENTS.md` tai root.
- Them bo tai lieu compact vao `docs/`:
  - `CODEX_INDEX.md`
  - `PROJECT_CONTRACT.md`
  - `DATABASE_CONTRACT.md`
  - `AUTH_CURRENT_STATE.md`
  - `ROADMAP_AND_DONE.md`
  - `README_KNOWLEDGE_PACK.md`
- Cac tai lieu tren duoc dung lam ngu canh du an; chung khong ghi de yeu cau truc tiep cua nguoi dung trong cuoc trao doi.

## Da chinh cau truc thu muc

- Di chuyen Flutter tu `mobile/` len root:
  - `android/`
  - `ios/`
  - `lib/`
  - `assets/`
  - `test/`
  - `web/`
  - `windows/`
  - `linux/`
  - `macos/`
  - `pubspec.yaml`
  - `pubspec.lock`
  - `analysis_options.yaml`
- Giu Spring Boot trong `backend/`.
- Chuyen Compose entry point tu `backend/compose.yaml` thanh `docker-compose.yml` tai root.
- Cap nhat `docker-compose.yml` de build API tu `./backend`.
- Cap nhat `docker-compose.yml` de map API qua `${API_PORT:-8081}:8080`, vi cong `8080` tren may dang bi `AgentService` giu.
- Cap nhat `backend/scripts/setup-env.ps1` de tao/copy `.env` tai root va them `API_PORT=8081`.
- Cap nhat cac path Flutter/iOS/macOS sinh ra truoc do con tro ve `mobile`.
- Cap nhat `.gitignore` cho root, backend target, `.env`, crash log, Gradle cache va `mobile/` generated leftovers.

## Da them du lieu demo

Them `backend/src/main/resources/data.sql`.

Du lieu seed idempotent, chay nhieu lan khong tao trung email:

| Email | Mat khau | Vai tro |
|---|---|---|
| `admin@gomate.local` | `GoMate123!` | `ADMIN` |
| `demo@gomate.local` | `GoMate123!` | `USER` |

Mat khau duoc luu bang BCrypt hash, khong luu plaintext.

Seed khong chay trong test profile nho cau hinh `backend/src/test/resources/application-test.yml`.

## Da cap nhat tai lieu chay du an

- Viet lai `README.md` theo cau truc root moi.
- Viet lai `TESTING.md` theo lenh chay moi.
- Them `.env.example` tai root.

## Kiem tra da chay

- `docker compose config --quiet`: thanh cong sau khi tao/copy `.env` ve root.
- `docker compose up -d --build`: build backend thanh cong; Maven trong Docker bao `BUILD SUCCESS`.
- `docker compose ps`: `postgres` healthy, `api` running voi port `0.0.0.0:8081->8080/tcp`.
- `Invoke-RestMethod http://localhost:8081/api/v1/health`: tra ve `UP`.
- PostgreSQL co dung 4 bang hien tai: `users`, `user_profiles`, `user_settings`, `refresh_sessions`.
- Seed demo da co:
  - `admin@gomate.local` / `ADMIN`
  - `demo@gomate.local` / `USER`
- Dang nhap `demo@gomate.local` / `GoMate123!` thanh cong va `GET /users/me` tra ve profile.
- Auth regression nhanh:
  - register user moi thanh cong,
  - duplicate email/nickname tra `409`,
  - refresh token rotation thanh cong,
  - logout xong refresh token cu tra `401`.
- `flutter --version`: thanh cong, Flutter 3.38.7 / Dart 3.10.7.
- `flutter pub get`: thanh cong tu root repo.
- `flutter test`: thanh cong, 2/2 tests pass.
- `flutter analyze`: chay duoc nhung fail voi 151 warning/info lint cu trong Flutter code, chu yeu `withOpacity` deprecated, thieu braces, unused helper; khong phai loi import/path sau refactor.

## Chua xac nhan duoc

- Chua chay duoc Maven test truc tiep ngoai Docker vi lenh `mvn` khong co trong PATH. Maven trong Docker da chay qua `clean verify` thanh cong khi build image.
- Thu muc `mobile/` chi con cache/build cu (`.dart_tool`, `.idea`, `build`), nhung thao tac xoa de quy bi policy cong cu chan. No da duoc `.gitignore` bo qua va khong con chua source chay thuc te.
- Chua test Google OAuth that vi can OAuth client cua du an Google Cloud va thiet bi/emulator phu hop.

## Lenh nen chay tiep tren may

Sau khi mo/restart Docker Desktop:

```powershell
docker compose up -d --build
docker compose ps
Invoke-RestMethod http://localhost:8081/api/v1/health
```

Neu Flutter bao can Developer Mode:

```powershell
start ms-settings:developers
```

Bat Developer Mode, roi chay lai:

```powershell
flutter pub get
flutter test
flutter run
```

## Cap nhat sua ket noi dang nhap tren dien thoai that

Ngay cap nhat: 2026-09-12

Nguoi dung da chay duoc Docker va app, nhung app bao can kiem tra backend/ket noi khi dang nhap. Nguyen nhan kha nang cao la app Android dang goi sai dia chi backend:

- Backend Docker expose ra host o `http://localhost:8081`.
- Dien thoai Android that khong nhin thay `localhost` cua PC neu khong co `adb reverse`.
- Cau hinh cu trong app uu tien `10.0.2.2:8080`, phu hop emulator va cong cu, khong phu hop backend hien tai dang o `8081` tren dien thoai that.

Da cap nhat:

- `lib/core/config/api_config.dart`
  - Android debug mac dinh goi `http://127.0.0.1:8081/api/v1`.
  - Co fallback `http://10.0.2.2:8081/api/v1` cho Android Emulator.
  - Van cho phep override bang `--dart-define=API_BASE_URL=...`.
- `lib/core/services/auth_service.dart`
  - Thu cac base URL ung vien khi gap loi network.
  - Thong bao loi network noi ro can kiem tra backend, cong `8081`, va `adb reverse` neu chay tren dien thoai that.
- `lib/core/services/google_auth.dart`
  - Them fallback Web Client ID dang co trong `.env`, de nut Google khong bi thieu `GOOGLE_WEB_CLIENT_ID` khi chay local.
  - Van cho phep override bang `--dart-define=GOOGLE_WEB_CLIENT_ID=...`.

Da cau hinh tren thiet bi dang cam:

```powershell
& "C:\Users\PC\AppData\Local\Android\sdk\platform-tools\adb.exe" -s RF8N32408EN reverse tcp:8081 tcp:8081
& "C:\Users\PC\AppData\Local\Android\sdk\platform-tools\adb.exe" -s RF8N32408EN reverse --list
```

Ket qua `reverse --list` co:

```text
UsbFfs tcp:8081 tcp:8081
```

Kiem tra da chay sau cap nhat:

- `flutter test`: pass 2/2.
- `flutter build apk --debug`: thanh cong, tao `build/app/outputs/flutter-apk/app-debug.apk`.
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`: cai ban debug moi len thiet bi `RF8N32408EN` thanh cong.
- Mo app tren thiet bi bang package `com.example.gomate` thanh cong.
- `flutter analyze`: van fail voi 144 warning/info lint cu trong UI, chu yeu deprecated `withOpacity`, unused helper/import, braces. Khong con loi compile trong cac file auth/config vua sua.
- Backend health va email login seed da duoc xac nhan truoc do:
  - `GET http://localhost:8081/api/v1/health` tra `UP`.
  - `demo@gomate.local` / `GoMate123!` dang nhap thanh cong tu host.

Lenh chay nen dung voi dien thoai `RF8N32408EN`:

```powershell
docker compose up -d
& "C:\Users\PC\AppData\Local\Android\sdk\platform-tools\adb.exe" -s RF8N32408EN reverse tcp:8081 tcp:8081
flutter run -d RF8N32408EN
```

Luu y Google:

- Backend da co `GOOGLE_CLIENT_IDS`; request token gia tra `401`, nghia la backend co cau hinh Google va dang reject token khong hop le dung cach.
- Neu Google that van loi, can kiem tra Google Cloud OAuth Android Client co package `com.example.gomate` va SHA-1 debug cua may hien tai.

## Cap nhat Google login auto-register/auto-link

Ngay cap nhat: 2026-09-12

Nguoi dung yeu cau Google login khong bi gioi han vao mot tai khoan Gmail cu. Ket qua mong muon: bat cu Google account hop le nao cung co the dang nhap; neu email chua co trong he thong thi tu dong dang ky, neu da co thi dang nhap.

Da cap nhat code:

- `backend/src/main/java/vn/gomate/auth/AuthService.java`
  - Neu `google_subject` da ton tai: dang nhap user do.
  - Neu `google_subject` chua ton tai nhung email Google da co account trong `users`: tu dong gan `google_subject` vao account do, sau do tao GoMate session.
  - Neu email Google chua co trong `users`: tao user Google-only, tao `user_profiles`, tao `user_settings`, sau do tao GoMate session.
  - Neu email da link voi Google subject khac: tra `409 GOOGLE_EMAIL_ALREADY_LINKED`.
  - Van giu rule LOCKED -> `403`.
- `backend/src/test/java/vn/gomate/GoogleFlowTest.java`
  - Doi test cu tu "bat buoc link thu cong" thanh "auto-link verified Google email".
  - Them test reject khi cung email nhung Google subject khac.
- `docs/AUTH_CURRENT_STATE.md`, `README.md`, `TESTING.md`
  - Cap nhat lai tai lieu theo flow Google moi.

Kiem tra da chay:

- `docker compose build api`: thanh cong.
- Dockerfile da chay `mvn --batch-mode clean verify` trong build: 20 tests, 0 failures, 0 errors.
- `docker compose up -d api`: recreate va start API container moi thanh cong.
- `docker compose ps`: `api` dang Up voi port `0.0.0.0:8081->8080`, `postgres` healthy.
- `GET http://localhost:8081/api/v1/health`: tra `UP`.
- `flutter test`: pass 2/2.

Ghi chu quan trong:

- Code backend bay gio khong con chan password account bang loi `GOOGLE_LINK_REQUIRED`.
- Backend van chi chap nhan Google ID token co audience nam trong `GOOGLE_CLIENT_IDS`.
- Neu van chi mot Gmail dang nhap duoc, kha nang nam o Google Cloud Console: OAuth consent screen dang Testing hoac Android OAuth Client/SHA-1/package chua dung. Can publish OAuth app hoac them tester, va dam bao package `com.example.gomate` + SHA-1 debug/release dung voi may build.

## Cap nhat luong vao Survey/Home sau dang nhap

Ngay cap nhat: 2026-09-12

Nguoi dung yeu cau: tai khoan dang nhap lan dau hoac chua lam khao sat phai vao trang Survey truoc; tai khoan da hoan thanh Survey thi vao thang Home.

Da cap nhat:

- Them `lib/features/auth/navigation/auth_flow.dart`
  - Gom logic quyet dinh sau auth vao mot noi.
  - Neu `AuthService.instance.onboardingCompleted == true` -> `MainShell`.
  - Neu `onboardingCompleted != true` -> `SurveyScreen`.
  - Sau khi luu Survey thanh cong -> vao `MainShell` va xoa stack dieu huong cu.
- Cap nhat `lib/features/auth/screens/login_screen.dart`
  - Email login va Google login cung dung `AuthFlow.goAfterAuth(...)`.
  - Khong con dieu huong rieng le/ten ham cu `_goToSurvey`.
- Cap nhat `lib/features/auth/screens/register_screen.dart`
  - Register xong di qua cung helper. Account moi mac dinh `onboardingCompleted=false`, nen se vao Survey.
- Cap nhat `lib/features/auth/screens/session_gate.dart`
  - Khi restore session cu, dung cung logic Survey/Home.
- Cap nhat `lib/features/onboarding/screens/survey_screen.dart`
  - Luu `PUT /users/me/onboarding` thanh cong thi vao Home bang helper va clear navigation stack.

Kiem tra da chay:

- `flutter test`: pass 2/2.
- `flutter build apk --debug`: thanh cong.
- `adb reverse tcp:8081 tcp:8081`: da gan lai cong backend cho thiet bi.
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`: cai ban debug moi thanh cong.
- Mo app tren thiet bi `RF8N32408EN` thanh cong.
- `docker compose ps`: API dang Up, PostgreSQL healthy.
- `GET http://localhost:8081/api/v1/health`: tra `UP`.

Luu y:

- `flutter analyze` van fail voi 138 warning/info lint cu trong UI, chu yeu `withOpacity` deprecated, unused helper, unnecessary underscores. Khong co loi build/compile trong luong auth-onboarding vua sua.
- Nut Skip trong Survey van goi backend voi danh sach lua chon rong; backend set `onboarding_completed=TRUE`, nen lan sau user vao thang Home.

## Kiem tra hien tuong login/register phan hoi lau

Ngay cap nhat: 2026-09-16

Nguoi dung bao app chay duoc nhung thao tac dang nhap/dang ky bi do, bao may chu phan hoi lau.

Ket qua kiem tra:

- `docker compose ps`: `api` dang Up, `postgres` healthy.
- Docker stats thap: API ~0.16% CPU, Postgres ~0.04% CPU tai thoi diem kiem tra.
- Goi truc tiep tu Windows vao backend:
  - `GET /api/v1/health`: ~682 ms o lan dau sau khi servlet khoi tao.
  - `POST /api/v1/auth/login`: ~597 ms o lan dau; sau do 5 lan lap lai la `[410, 99, 101, 115, 96] ms`, trung binh ~164 ms.
  - `POST /api/v1/auth/register`: ~343 ms.
- Log API khong co loi DB hay exception lien quan login/register.

Nguyen nhan kha nang cao:

- Thiet bi Android that khong co `adb reverse tcp:8081 tcp:8081` tai thoi diem kiem tra ban dau.
- App Android mac dinh goi `http://127.0.0.1:8081/api/v1`; tren dien thoai that dia chi nay chi cham duoc backend PC khi da co `adb reverse`.
- Neu reverse mat do rut cap/restart adb/restart may, app se cho timeout/fallback nen co cam giac "may chu phan hoi lau".

Da xu ly:

- Gan lai reverse:

```powershell
& "C:\Users\PC\AppData\Local\Android\sdk\platform-tools\adb.exe" -s RF8N32408EN reverse tcp:8081 tcp:8081
& "C:\Users\PC\AppData\Local\Android\sdk\platform-tools\adb.exe" -s RF8N32408EN reverse --list
```

Ket qua can co:

```text
UsbFfs tcp:8081 tcp:8081
```

- Sua `lib/core/services/auth_service.dart`:
  - Giam timeout moi lan thu ket noi tu 20 giay xuong 6 giay.
  - Neu mot URL local bi timeout thi ghi nhan loi va tiep tuc thu URL ung vien tiep theo.
  - Thong bao loi cuoi van nhac kiem tra backend, cong `8081`, va `adb reverse`.
- Build va cai lai APK debug moi:
  - `flutter test`: pass 2/2.
  - `flutter build apk --debug`: thanh cong.
  - `adb install -r build/app/outputs/flutter-apk/app-debug.apk`: thanh cong.
  - Mo app tren thiet bi `RF8N32408EN` thanh cong.

Ghi chu van hanh:

- Moi lan rut/cam lai USB, restart ADB, restart PC, hoac doi thiet bi, hay chay lai `adb reverse tcp:8081 tcp:8081`.
- Neu muon tranh phu thuoc `adb reverse`, co the chay app voi `--dart-define=API_BASE_URL=http://<IP-LAN-cua-PC>:8081/api/v1` va mo firewall Windows cho cong 8081.

Cap nhat sau khi nguoi dung van gap loi ket noi du da co reverse:

- Da test tu chinh shell Android:
  - Goi `http://192.168.1.6:8081/api/v1/health` tra `{"status":"UP"}`.
  - Goi qua `127.0.0.1:8081`/`localhost:8081` bang reverse khong tra body on dinh tren thiet bi nay.
- Ket luan: voi may hien tai, duong on dinh la IP LAN cua PC (`192.168.1.6`), khong phai `adb reverse`.
- Da cap nhat `lib/core/config/api_config.dart`:
  - Android debug mac dinh goi `http://192.168.1.6:8081/api/v1`.
  - Fallback giu `http://127.0.0.1:8081/api/v1` va `http://10.0.2.2:8081/api/v1`.
- Kiem tra sau cap nhat:
  - `flutter test`: pass 2/2.
  - `POST /api/v1/auth/login` tu host: ~260 ms.
  - `flutter build apk --debug`: thanh cong.
  - `adb install -r build/app/outputs/flutter-apk/app-debug.apk`: thanh cong.
  - Mo app tren thiet bi `RF8N32408EN`: thanh cong.

Luu y moi:

- Neu IP Wi-Fi cua PC doi, chay Flutter voi:

```powershell
flutter run -d RF8N32408EN --dart-define=API_BASE_URL=http://<IP-LAN-cua-PC>:8081/api/v1
```

## Cap nhat cau hinh ket noi Android ben vung hon

Ngay cap nhat: 2026-09-16

Nguoi dung yeu cau giai quyet dut diem loi ket noi khi doi dien thoai, doi PC, hoac chay code tren may khac.

Da cap nhat:

- `lib/core/config/api_config.dart`
  - Bo IP co dinh `192.168.1.6` khoi source code.
  - Android debug mac dinh quay ve URL local chung `http://127.0.0.1:8081/api/v1`.
  - Them `API_BASE_URLS` de Flutter co the nhan nhieu URL ung vien khi run/build.
  - `API_BASE_URL` van duoc ho tro cho truong hop chi muon ep mot URL.
- Them `scripts/run-android-dev.ps1`
  - Tu khoi dong Docker service bang `docker compose up -d`.
  - Tu tim Android device neu chi co mot thiet bi.
  - Tu do IPv4 LAN cua PC, bo qua cac card ao nhu Docker/WSL/Hyper-V.
  - Tu cau hinh `adb reverse tcp:8081 tcp:8081` lam fallback.
  - Chay `flutter run` voi `API_BASE_URLS` gom: IP LAN PC, `127.0.0.1`, `10.0.2.2`.
  - Co mode `-InstallOnly` de build/cai APK debug voi cau hinh IP hien tai.
- `lib/core/services/auth_service.dart`
  - Thong bao loi network gio nhac chay `scripts/run-android-dev.ps1`, thay vi chi phu thuoc `adb reverse`.
- `README.md`, `TESTING.md`
  - Cap nhat lenh Android dev moi.
  - Ghi ro khi doi PC/Wi-Fi/dien thoai thi chay lai script, vi `dart-define` duoc bake vao ban build Flutter.

Lenh nen dung tu nay:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android-dev.ps1
```

Neu co nhieu device:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android-dev.ps1 -DeviceId RF8N32408EN
```

Neu chi muon cai lai APK debug:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android-dev.ps1 -DeviceId RF8N32408EN -InstallOnly
```

Y nghia:

- Khong con phu thuoc vao IP Wi-Fi cu trong code.
- Sang PC khac script se do IP cua PC do.
- Sang dien thoai khac script se chon device moi, hoac yeu cau `-DeviceId` neu co nhieu device.
- Neu `adb reverse` loi tren mot thiet bi, app van co URL LAN de goi backend.

Kiem tra da chay sau cap nhat:

- `dart format lib\core\config\api_config.dart lib\core\services\auth_service.dart`: thanh cong.
- `flutter test`: pass 2/2.
- `powershell -ExecutionPolicy Bypass -File .\scripts\run-android-dev.ps1 -DeviceId RF8N32408EN -InstallOnly`: thanh cong.
  - Docker service dang chay.
  - Backend health tren host tra `UP`.
  - Script tu do `LAN API URL: http://192.168.1.6:8081/api/v1`.
  - `adb reverse tcp:8081 tcp:8081` duoc cau hinh fallback.
  - `flutter build apk --debug`: thanh cong.
  - `adb install -r`: thanh cong.
  - Mo app `com.example.gomate`: thanh cong.
- Kiem tra tu shell Android goi `http://192.168.1.6:8081/api/v1/health`: tra `HTTP 200` va `{"status":"UP"}`.

File ghi chu rieng cho van hanh Android network: `docs/ANDROID_NETWORK_SETUP.md`.
