# Kiến trúc và runbook

```text
Flutter → Spring Boot /api/v1 + JWT + authorization/transactions
  → PostgreSQL business state, Flyway V1–V26
  → MongoDB messages/moments/events/trip_current_locations
  → Cloudinary binary; Post authenticated qua Spring proxy
  → Firebase Google Auth extension/FCM, không phải business DB
  → KPDL FastAPI Place ranking; chưa có Post AI
```

Source: [Compose chuẩn](../../docker-compose.yml), [Spring config](../../backend/src/main/resources/application.yml), [pom](../../backend/pom.xml), [Flutter](../../pubspec.yaml), [ApiConfig](../../lib/core/config/api_config.dart). Java17/Spring Boot3.5.11, Dart constraint ^3.10.7. Giữ lockfile; không mass-upgrade.

## Máy mới

**PRIVATE FILE REQUIRED:** nhận `lib/main.dart` từ owner qua kênh riêng và đặt đúng đường dẫn trước mọi lệnh Flutter bên dưới. Git-only clone không build/chạy Flutter được. Không sửa/commit lại file này; `.gitignore` phải giữ `/lib/main.dart`. Kiểm tra `git check-ignore lib/main.dart` và `git ls-files lib/main.dart` (không có output). Không đưa token vào log. Dùng staging/scoped credentials thay dữ liệu thật.

Tạo **root** `.env` từ [.env.example](../../.env.example), thay `DB_PASSWORD=<NEW_RANDOM_PASSWORD>` và `JWT_SECRET=<NEW_RANDOM_SECRET_AT_LEAST_32_BYTES>` bằng giá trị riêng; không dùng placeholder làm credential thật. Script setup-env cũ tạo backend-local env là lịch sử; Compose chuẩn đọc root env.

Tên biến và placeholder:

| Nhóm | Biến |
|---|---|
| API | `API_PORT=<PORT>` (template8081), `CORS_ORIGINS=<ALLOWED_ORIGINS>` |
| Google/FCM | `FIREBASE_ENABLED=<BOOL>`, `FIREBASE_PROJECT_ID=<PROJECT_ID>`, `GOOGLE_CLIENT_IDS=<CLIENT_ID_LIST>`, `NOTIFICATION_PUSH_ENABLED=<BOOL>` |
| Media/Map | `MAPBOX_SERVER_TOKEN=<SERVER_TOKEN>`, `CLOUDINARY_ENABLED=<BOOL>`, `CLOUDINARY_URL=cloudinary://<API_KEY>:<API_SECRET>@<CLOUD_NAME>` |
| Mongo | `MONGO_DATABASE=<DATABASE>`, `MONGO_URI=<CONNECTION_STRING>` |
| Place AI | `AI_PORT=<PORT>` (8000), `AI_SERVICE_BASE_URL=<INTERNAL_URL>`, `AI_RECOMMENDATION_CANDIDATE_K=<COUNT>` (50), `AI_RECOMMENDATION_HOME_LIMIT=<COUNT>` (10), `AI_RECOMMENDATION_TIMEOUT_MS=<MS>` (2500), `RECOMMENDATION_*` theo template |
| Import | `PLACE_SEED_ENABLED=false`; không tự bật importer/startup seed |

Google/FCM cần cấu hình riêng `android/app/google-services.json` với package/SHA đúng và `backend/secrets/firebase-service-account.json`; không lấy từ Git/history/chat. Xem [Firebase setup](../GOOGLE_FIREBASE_LOCAL_SETUP.md). `lib/main.dart` bàn giao riêng vẫn chứa Mapbox token; không chuyển startup sang build configuration trong release này. Bàn giao riêng không tự bảo mật token: khuyến nghị token AI/dev riêng, quyền tối thiểu và review rotation/restrictions với owner; không rotate ngay, không đưa server token vào Flutter hoặc vượt Push Protection.

```powershell
docker compose up -d --build
docker compose ps
Invoke-RestMethod http://127.0.0.1:8081/api/v1/health
Invoke-RestMethod http://127.0.0.1:8000/health
flutter pub get
flutter analyze
flutter test
```

Services: postgres (host127.0.0.1:5432), mongo (127.0.0.1:27017), api (8081→8080), ai (8000). Flutter từ root. Android USB:

```powershell
adb devices
adb -s ANDROID_DEVICE_SERIAL reverse tcp:8081 tcp:8081
flutter run -d ANDROID_DEVICE_SERIAL --dart-define=API_BASE_URL=http://127.0.0.1:8081/api/v1
```

Emulator có 10.0.2.2 fallback; máy thật dùng reverse/LAN reachable. Release cần API_BASE_URL HTTPS riêng. [Dev script](../../scripts/run-android-dev.ps1) nhận DeviceId/HostIp, không dùng IP máy bàn giao.

Flyway: [SQL](../../backend/src/main/resources/db/migration), [Java migrations](../../backend/src/main/java/db/migration). Clean DB chạy từ đầu, existing DB validate/apply missing versions. **38 business tables + history**; không sửa V1–V26/down -v/reset/repair. Máy mới không tự có user/Post/media thật của máy cũ; không copy production dump/volume. [Contract](../DATABASE_CONTRACT.md) phân biệt actual schema và roadmap.

Backend smoke Java17: `mvn -f backend/pom.xml -Dtest=GlobalBlockApiTest,PostFeedApiTest,ContextualRecommendationRerankerTest test`. Không có Maven thì dùng Maven Docker bind backend + Maven cache. Smoke không phải toàn baseline.

AI [source](../../KPDL/api_service.py) ưu tiên [v13 joblib](../../KPDL/training_output_research_final/gomate_ranker_research_v13.joblib), giữ [v12 bundle](../../KPDL/training_output/gomate_ranker_v12_semantic_v1.joblib) cùng semantic scorer/CSV. Không train lại/download model khi nhận baseline.
