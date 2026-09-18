# Google/Firebase local setup

Ngay cap nhat: 2026-09-17

## File cau hinh da dat vao may local

Hai file nay khong commit Git vi chua secret/cau hinh rieng cua Firebase:

- `android/app/google-services.json`
- `backend/secrets/firebase-service-account.json`

`.env` local da bat Firebase backend:

```dotenv
FIREBASE_ENABLED=true
FIREBASE_PROJECT_ID=gomate-498319
API_PORT=8081
```

Root `docker-compose.yml` da mount:

```text
backend/secrets -> /run/secrets
```

Backend doc token Google hien dung luong:

```text
Flutter Google/Firebase Auth -> Firebase ID token -> POST /api/v1/auth/google -> Spring verify bang Firebase Admin
```

## Kiem tra da chay

- `google-services.json` project id: `gomate-498319`.
- `google-services.json` Android package: `com.example.gomate`.
- `firebase-service-account.json` project id: `gomate-498319`.
- Docker API nhan:
  - `FIREBASE_ENABLED=true`
  - `FIREBASE_PROJECT_ID=gomate-498319`
  - `GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/firebase-service-account.json`
- `GET http://localhost:8081/api/v1/health`: `UP`.
- Login email/password seed thanh cong.
- `POST /auth/google` voi token gia tra `INVALID_FIREBASE_TOKEN`, nghia la backend da bat Firebase verifier.
- `flutter build apk --debug` qua `scripts/run-android-dev.ps1 -InstallOnly`: thanh cong.
- APK debug da cai va mo tren thiet bi `RF8N32408EN`.
- `flutter test`: pass 2/2.

## Can cap nhat trong Firebase Console neu Google login van loi OAuth

SHA-1 debug hien tai cua may nay:

```text
38:E8:7A:5B:1C:B6:2E:2A:BB:D3:12:D2:B3:35:80:04:59:8A:2D:08
```

SHA-256 debug hien tai cua may nay:

```text
42:80:59:B0:3D:19:1C:31:3A:B8:D8:F6:1C:13:91:56:91:6D:22:4B:90:96:37:4F:A5:03:A2:4B:30:DA:EA:7A
```

`google-services.json` hien tai dang co Android OAuth certificate hash:

```text
92e7b6042aab10e9493de4db1b4d79134302e527
```

Hash nay khong khop SHA-1 debug cua may hien tai. Vi vay neu bam Google login van bao loi OAuth, can vao Firebase Console/Google Cloud cua project `gomate-498319`, them SHA-1/SHA-256 debug cua may nay vao Android app package `com.example.gomate`, sau do tai lai `google-services.json` moi va dat vao:

```text
android/app/google-services.json
```

Sau do chay lai:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android-dev.ps1 -DeviceId RF8N32408EN -InstallOnly
```

Lua chon khac la dung dung debug keystore cua nguoi da tao file `google-services.json`, nhung cach chuan hon la them SHA cua may hien tai vao Firebase project.
