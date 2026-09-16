# GoMate Auth Foundation

Repo hien tai da duoc dua ve cau truc GoMate target: Flutter o root, Spring Boot trong `backend/`, Docker Compose o root.

```text
GoMate/
├── android/ ios/ lib/ assets/ test/ web/ windows/ linux/ macos/
├── backend/
├── docs/
├── docker-compose.yml
├── pubspec.yaml
├── .env.example
└── AGENTS.md
```

## Pham vi hien tai

- Backend: Spring Boot Java 17 + PostgreSQL.
- Mobile: Flutter.
- Auth dang hoat dong: email/password, refresh token, logout, change password, Google sign-in auto-register/auto-link extension, `GET /users/me`, onboarding dang luu trong `user_settings`.
- Database runtime hien tai van la 4 bang auth dang chay: `users`, `user_profiles`, `user_settings`, `refresh_sessions`.
- Tai lieu chuan cua du an da nam trong `AGENTS.md` va `docs/`.

Chua chuyen sang Flyway trong lan refactor nay de tranh tron thay doi cau truc thu muc voi thay doi schema/business. Canonical target van duoc ghi trong `docs/DATABASE_CONTRACT.md`.

## Chay backend bang Docker

Mo PowerShell tai root repo:

```powershell
powershell -ExecutionPolicy Bypass -File .\backend\scripts\setup-env.ps1
docker compose up -d --build
docker compose ps
Invoke-RestMethod http://localhost:8081/api/v1/health
```

Logs:

```powershell
docker compose logs --tail 100 api
docker compose logs --tail 100 postgres
```

Neu cong `8080` tren Windows da bi dich vu khac giu, repo nay dung `API_PORT=8081` trong `.env`. Khi do health URL la:

```powershell
Invoke-RestMethod http://localhost:8081/api/v1/health
```

Swagger: http://localhost:8081/swagger-ui/index.html

Database local:

```text
database: gomate_auth
user: gomate
host: localhost
port: 5432
password: xem file .env o root
```

Khong dung `docker compose down -v` neu muon giu du lieu.

## Du lieu demo

`backend/src/main/resources/data.sql` seed du lieu mau idempotent khi backend khoi dong voi PostgreSQL:

| Email | Mat khau | Vai tro |
|---|---|---|
| `admin@gomate.local` | `GoMate123!` | `ADMIN` |
| `demo@gomate.local` | `GoMate123!` | `USER` |

Seed nay khong chay trong profile test, de test backend van dung database sach.

## Chay Flutter

Flutter hien chay tu root repo:

```powershell
flutter pub get
flutter analyze
flutter test
```

Neu dung dien thoai Android that qua USB, dung script dev de tranh loi do doi IP/may/dien thoai:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android-dev.ps1
```

Script se:

- khoi dong Docker service neu chua chay,
- tu chon Android device neu chi co mot device,
- tu do IPv4 LAN cua PC,
- cau hinh them `adb reverse` lam fallback,
- chay Flutter voi `--dart-define=API_BASE_URLS=http://<IP-LAN-PC>:8081/api/v1,http://127.0.0.1:8081/api/v1,http://10.0.2.2:8081/api/v1`.

Neu co nhieu dien thoai/emulator dang ket noi:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android-dev.ps1 -DeviceId RF8N32408EN
```

Neu chi muon build va cai APK debug len dien thoai:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android-dev.ps1 -DeviceId RF8N32408EN -InstallOnly
```

Neu script khong tu do duoc IP tren PC moi, truyen thu cong:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android-dev.ps1 -HostIp 192.168.1.x
```

Neu dung Android Emulator, app co fallback sang:

```text
http://10.0.2.2:8081/api/v1
```

Neu muon chi dinh thu cong API URL:

```powershell
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8081/api/v1
```

Luu y: `API_BASE_URL`/`API_BASE_URLS` duoc gan luc build/run Flutter. Neu mo lai APK debug cu da build truoc do, no van giu cau hinh cu; hay chay lai script khi doi PC, doi Wi-Fi, doi dien thoai, hoac cai lai app.

## Google sign-in

Google la extension cua goi Auth hien tai, khong phai core canonical MVP. Neu dung Google that:

1. Tao OAuth Web Client ID trong Google Cloud.
2. Tao OAuth Android Client voi package `com.example.gomate`.
3. Lay SHA-1 trong root repo:

```powershell
cd android
.\gradlew.bat signingReport
```

4. Dien Web Client ID vao `.env`:

```dotenv
GOOGLE_CLIENT_IDS=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

5. Chay lai API va Flutter:

```powershell
docker compose up -d --force-recreate api
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

Khong dua Google Client Secret vao Flutter.

Ban hien tai da co Web Client ID trong `.env` va Flutter da co fallback trung voi ID do. Neu doi Google Cloud project, cap nhat ca `.env` backend va `GOOGLE_WEB_CLIENT_ID` khi chay Flutter. Neu Google van loi tren Android, kiem tra Android OAuth Client trong Google Cloud co dung package `com.example.gomate` va SHA-1 debug cua may nay hay khong.

Flow backend hien tai:

- Google token hop le + email chua co trong GoMate -> tu tao user moi, tao profile/settings, dang nhap.
- Google token hop le + email da co account password nhung chua link -> tu gan `google_subject`, dang nhap.
- Google token hop le + email da link dung Google subject -> dang nhap.
- Google token hop le + email da link voi Google subject khac -> tu choi `409`.

Neu Google Cloud OAuth consent screen dang o trang thai Testing, Google co the chi cho cac tester duoc add trong Google Cloud dang nhap. De bat cu Gmail nao dang nhap duoc, can cau hinh OAuth consent screen phu hop va publish app, dong thoi Android OAuth Client phai dung package `com.example.gomate` + SHA-1 debug/release tu may build app.

## API chinh

Base path: `/api/v1`.

| Method | Path | Tac dung |
|---|---|---|
| POST | `/auth/register` | Dang ky email/password/nickname |
| POST | `/auth/login` | Dang nhap email/password |
| POST | `/auth/google` | Dang nhap Google bang ID token |
| POST | `/auth/refresh` | Xoay refresh token |
| POST | `/auth/logout` | Thu hoi phien hien tai |
| POST | `/auth/google/link` | Lien ket Google voi tai khoan dang dang nhap |
| POST | `/auth/change-password` | Doi mat khau va thu hoi phien |
| GET | `/users/me` | Ho so user hien tai |
| PUT | `/users/me/onboarding` | Luu lua chon onboarding |

Vi du dang nhap seed:

```powershell
$body = @{ email='demo@gomate.local'; password='GoMate123!' } | ConvertTo-Json
$session = Invoke-RestMethod -Method Post -Uri http://localhost:8081/api/v1/auth/login -ContentType 'application/json' -Body $body
Invoke-RestMethod http://localhost:8081/api/v1/users/me -Headers @{Authorization="Bearer $($session.accessToken)"}
```
