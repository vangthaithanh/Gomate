# Cloudinary media setup

Ngay cap nhat: 2026-09-18

## Muc tieu

GoMate dung Cloudinary de luu binary anh/video. PostgreSQL sau nay chi luu URL, `public_id`, `resource_type` va metadata can thiet. Flutter khong giu Cloudinary API Secret.

## Cau hinh da them

- `.env` local da co `CLOUDINARY_ENABLED=true` va `CLOUDINARY_URL=cloudinary://...@w7i2jm4f`.
- `.env.example` chi giu placeholder, khong chua secret.
- `docker-compose.yml` truyen `CLOUDINARY_ENABLED` va `CLOUDINARY_URL` vao service `api`.
- `backend/pom.xml` them Cloudinary Java SDK `com.cloudinary:cloudinary-http5:2.2.0`.
- `backend/src/main/resources/application.yml` them `app.cloudinary.enabled` va `app.cloudinary.url`.
- `.gitignore` them `.m2-cache/` vi qua trinh kiem tra Docker Maven co the tao cache local.

## Code backend da them

```text
backend/src/main/java/vn/gomate/media/
├── config/CloudinaryConfig.java
├── dto/MediaUploadResult.java
├── model/MediaResourceType.java
├── provider/MediaProvider.java
├── provider/CloudinaryMediaProvider.java
└── service/MediaService.java
```

Vai tro:

- `CloudinaryConfig`: tao Cloudinary client tu `CLOUDINARY_URL`, chi bat khi `CLOUDINARY_ENABLED=true`.
- `MediaProvider`: interface de business module khong phu thuoc truc tiep Cloudinary SDK.
- `CloudinaryMediaProvider`: upload image/video va delete asset bang `public_id`.
- `MediaService`: wrapper service de module User/Place/Post/Review sau nay goi chung.

## Chua lam trong phase nay

- Chua tao API upload public.
- Chua tao migration/table media.
- Chua upload file test that len Cloudinary.
- Chua gan vao User avatar, Place media, Review media hoac Post media.

Ly do: day la phase foundation. Khi lam Place/User/Post, business endpoint se quyet dinh permission/context va goi `MediaService`.

## Nguyen tac can giu

- Khong commit `.env` hoac Cloudinary API Secret.
- Khong dua Cloudinary credential vao Flutter.
- DB chi luu `secure_url`, `public_id`, `resource_type`, metadata.
- Khi delete/replace sau nay phai xu ly ca Cloudinary va PostgreSQL; Cloudinary khong rollback chung voi DB transaction.
- Folder nen theo convention:

```text
gomate/users/{userId}/avatar/
gomate/places/{placeId}/
gomate/reviews/{reviewId}/
gomate/posts/{postId}/
gomate/trips/{tripId}/
```

## Lenh kiem tra

Da chay:

```powershell
docker compose config --quiet
```

Ket qua: hop le, khong bao loi compose.

Da kiem tra Cloudinary dependency:

```powershell
docker run --rm -v ${PWD}\backend:/work -w /work maven:3.9.9-eclipse-temurin-17 mvn -q org.apache.maven.plugins:maven-dependency-plugin:3.8.1:get "-Dartifact=com.cloudinary:cloudinary-http5:2.2.0"
```

Ket qua: dependency resolve thanh cong.

Luu y kiem tra Maven ngay 2026-09-18:

- May nay chua co `mvn` local.
- `mvn test` bang Docker va `mvn -DskipTests compile` bang Docker deu bi dung chu dong vi mat qua lau o buoc tai dependency Firebase/Google Cloud BOM; chua ghi nhan loi compile tu code Cloudinary.

Lenh nen chay tiep khi mang Maven on dinh hon:

```powershell
docker compose config
docker compose up -d --build api
Invoke-RestMethod http://localhost:8081/api/v1/health
```

Neu chi kiem tra backend test va may da cai Maven:

```powershell
cd backend
mvn test
```

Tren may chua co Maven, co the de Docker build API chay Maven trong image, nhung lan dau co the rat lau vi Firebase Admin keo nhieu dependency Google Cloud.
