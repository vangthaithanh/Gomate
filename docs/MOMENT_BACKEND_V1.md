# MOMENT_BACKEND_V1.md

Updated: 2026-10-08

## Scope Implemented

Moment V1 is now wired end-to-end for the current product scope:

- Flutter Moment strip/viewer/my-moments uses real API data.
- Spring Boot owns permission checks and API validation.
- MongoDB stores Moment content, views, reactions, and mutes.
- Cloudinary stores Moment images.
- PostgreSQL remains source of truth for users and mutual-friend relationships.

No Flyway migration was added. No PostgreSQL table was created for Moment V1.

## Mongo Collections

```text
moments
moment_views
moment_reactions
moment_mutes
```

Indexes are created idempotently at application startup. There is no TTL index on `expiresAt`; expired moments are hidden from friends but remain in owner history until the owner deletes them.

## API Contract

```text
POST   /api/v1/moments/media
POST   /api/v1/moments
GET    /api/v1/moments/home
GET    /api/v1/moments/me
GET    /api/v1/moments/users/{userId}/available
GET    /api/v1/moments/{momentId}
POST   /api/v1/moments/{momentId}/view
POST   /api/v1/moments/{momentId}/reactions
POST   /api/v1/moments/{momentId}/message
DELETE /api/v1/moments/{momentId}
DELETE /api/v1/moments
POST   /api/v1/moment-mutes/{userId}
DELETE /api/v1/moment-mutes/{userId}
```

## Business Rules

- Moment V1 supports image media only.
- Moment visibility is mutual-friends only.
- Viewer availability requires: mutual friend, not muted, not deleted, not expired, and not already viewed.
- `/view` is explicit and idempotent from the user experience side.
- A user may react once per moment. Repeating the same reaction is idempotent; changing reaction type returns conflict.
- Owner-only hard delete marks the moment deleted, removes views/reactions, and attempts Cloudinary cleanup.
- Moment-to-message reuses Direct Message V1 and includes a `context.type=MOMENT` payload.
- Report UI is still a hook only; no Moment report storage was added because shared Report/Admin backend is not implemented yet.

## Flutter Notes

`ApiMomentsRepository` replaced the active Home Moment data source. The old `DemoMomentsRepository` remains as a development fallback class but is no longer used by Home.

Moment image/avatar widgets now accept asset paths, local file paths, and HTTP(S) URLs so Cloudinary media renders without redesigning the UI.

Home Moment visibility after the UX adjustment:

- the current user entry stays visible so they can create/open their own Moment library;
- friends only appear when they have at least one unviewed active Moment;
- after the current user views all active Moments from a friend, that friend is hidden from the strip.

Moment camera UX:

- the camera preview stays live inside the square Moment frame;
- center shutter captures the current camera frame and uploads that photo;
- left control keeps the original flash icon and toggles flash/torch when supported;
- right control keeps the original camera-switch icon and switches front/back camera;
- Moment creation does not allow gallery/photo-library upload;
- Android/iOS camera permission is declared in platform config.

Upload note:

- Flutter sends captured files with an explicit `image/*` multipart content type so Spring's Moment media validation can accept the upload.

## Validation

Executed:

```text
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test
docker compose build api
```

Results:

- Flutter analyze: passed with existing non-fatal warnings/infos.
- Flutter tests: passed.
- Docker API build: passed; Maven verify completed successfully.

During Docker build tests, MongoDB was not running inside the build environment, so existing event/index startup code logged controlled Mongo timeout warnings. The build still passed.
