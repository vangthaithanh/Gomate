# Khóa Firebase chỉ dùng trên backend

Đặt file service account tải từ Firebase Console vào đây với tên:

`firebase-service-account.json`

File thật không được đóng gói sẵn. Không đưa file này vào Flutter, Git hoặc ảnh Docker.
Compose gắn thư mục này vào `/run/secrets` ở chế độ chỉ đọc.

Sau đó điền `.env`:

```dotenv
FIREBASE_ENABLED=true
FIREBASE_PROJECT_ID=project-id-cua-ban
```

`project_id` trong file JSON phải giống `FIREBASE_PROJECT_ID` và dự án Firebase của Flutter.
