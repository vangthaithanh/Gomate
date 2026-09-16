# Kiem thu

## Da ghi nhan tu goi Auth ban dau

- Backend tung chay `mvn verify` thanh cong tren Java 17; lan moi nhat qua Docker build: 20 tests, 0 failures, 0 errors.
- Cac test bao phu dang ky/rollback khi trung, khong lo password hash, input khong hop le, sai mat khau, refresh rotation, logout, doi mat khau thu hoi phien, user LOCKED, token bi sua chu ky.
- Google flow dung RSA test key, khong phai dang nhap Google that.
- Flutter co test tai `test/auth_service_test.dart`.

## Cach chay lai sau refactor cau truc

Backend:

```powershell
cd backend
mvn test
```

Neu Windows chua co `mvn` trong PATH, co the de Docker build backend:

```powershell
cd ..
docker compose up -d --build
docker compose logs --tail 100 api
```

Flutter tu root repo:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Neu test tren dien thoai Android that qua USB:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android-dev.ps1
```

Neu co nhieu device, truyen ro device:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android-dev.ps1 -DeviceId RF8N32408EN
```

Neu login/register tren app bao may chu phan hoi lau, chay lai script nay truoc. Backend tu host da duoc do nhanh: login lap lai trung binh khoang 164 ms, register khoang 343 ms trong lan kiem tra 2026-09-16.

Cap nhat 2026-09-16: tren thiet bi `RF8N32408EN`, `adb reverse` hien rule dung nhung health qua `127.0.0.1:8081`/`localhost:8081` khong tra body on dinh. Health qua IP LAN cua PC tra `UP`, nen cau hinh debug hien dung `scripts/run-android-dev.ps1` de tu do IP LAN cua PC va truyen vao Flutter bang `API_BASE_URLS`.

Neu script khong tu do duoc IP tren PC moi, lay IP bang:

```powershell
Get-NetIPAddress -AddressFamily IPv4
```

Sau do chay:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android-dev.ps1 -HostIp <IP-LAN-cua-PC>
```

Neu da build APK debug va chi muon cai lai app:

```powershell
& "C:\Users\PC\AppData\Local\Android\sdk\platform-tools\adb.exe" -s RF8N32408EN install -r "build\app\outputs\flutter-apk\app-debug.apk"
```

Docker/PostgreSQL:

```powershell
powershell -ExecutionPolicy Bypass -File .\backend\scripts\setup-env.ps1
docker compose up -d --build
docker compose ps
Invoke-RestMethod http://localhost:8081/api/v1/health
```

## Kiem tra thu cong tren PostgreSQL

Mac dinh `.env` hien dat `API_PORT=8081` vi cong 8080 co the bi dich vu Windows khac giu.

1. Dang nhap seed `demo@gomate.local` / `GoMate123!`.
2. Goi `/api/v1/users/me` bang Bearer token vua nhan.
3. Dang ky email moi, xac nhan tao du `users`, `user_profiles`, `user_settings`, `refresh_sessions`.
4. Thu trung email/biet danh, ket qua phai la 409 va khong co user do dang.
5. Dang nhap sai mat khau phai 401; logout xong refresh token cu khong dung lai duoc.
6. Chay `docker compose down` neu can dung container; khong them `-v` neu muon giu account.

## Trang thai kiem tra moi nhat

- Docker dang chay `postgres` va `api`; API expose ra host o `http://localhost:8081`.
- Health check `http://localhost:8081/api/v1/health` tra `UP`.
- Email login seed `demo@gomate.local` / `GoMate123!` da test thanh cong tu host.
- `GET /api/v1/users/me` voi access token login seed da test thanh cong.
- `adb reverse tcp:8081 tcp:8081` da gan thanh cong cho thiet bi `RF8N32408EN`.
- `flutter test` pass 2/2.
- `flutter build apk --debug` build thanh cong.
- Cai APK debug len thiet bi `RF8N32408EN` bang `adb install -r ...app-debug.apk`: thanh cong.
- Da mo app tren thiet bi bang package `com.example.gomate`.
- `flutter analyze` van fail do 144 warning/info lint cu trong UI (`withOpacity` deprecated, unused helper/import, braces). Khong con loi compile/path lien quan den auth service/config moi.
- Google backend da co `GOOGLE_CLIENT_IDS`; request token gia tra 401 thay vi loi cau hinh. Google that van phu thuoc OAuth Android Client dung package `com.example.gomate` va SHA-1 debug.
- Google service test moi da xac nhan:
  - Google email moi tu tao account.
  - Google email trung voi password account se tu link va dang nhap.
  - Email da link voi Google subject khac tra 409.
- Auth/onboarding flow moi:
  - Login/register/Google/restore session cung dung `AuthFlow`.
  - `onboardingCompleted=true` vao `MainShell`.
  - `onboardingCompleted=false` vao `SurveyScreen`.
  - Luu Survey thanh cong thi vao `MainShell` va xoa stack dieu huong cu.
  - APK debug moi da build, cai va mo tren thiet bi `RF8N32408EN` thanh cong.
