# REAL USER SEARCH + FOLLOW UI V1

Updated: 2026-10-08

## Scope

This step wires the existing real Account/Profile, Social Relationship, and Direct Message V1 backend APIs into the Flutter Search/Profile UI.

No schema change was needed.

## Search Sources

| Surface | Source | Status |
|---|---|---|
| Discovery Place | `RecommendationRepository` / `/api/v1/recommendations/home` | REAL |
| Live Place | cached recommendation places filtered in Flutter | REAL source, client filter |
| Live User | `GET /api/v1/users/search?q=&page=&size=` | REAL |
| Live Post | existing demo post list | MOCK |
| Submitted Place | cached recommendation places filtered in Flutter | REAL source, client filter |
| Submitted User | `GET /api/v1/users/search?q=&page=&size=` | REAL |
| Submitted Post | existing demo post list | MOCK |

## User API Contract Reused

| API | Usage |
|---|---|
| `GET /api/v1/users/search?q=&page=&size=` | Search real active users, excluding current user. |
| `GET /api/v1/users/{userId}` | Public profile detail. |
| `PUT /api/v1/users/{userId}/follow` | Follow / follow back. |
| `DELETE /api/v1/users/{userId}/follow` | Unfollow. |
| `POST /api/v1/conversations/direct` | Open direct message from public profile. |
| `PATCH /api/v1/users/me/profile` | Edit current nickname/full name/city/bio/avatar URL. |
| `POST /api/v1/auth/change-password` | Change password, then require login again. |

## Relationship Mapping

| Backend fields | Flutter state | UI label |
|---|---|---|
| `mutualFriend=true` | `friend` | `Bạn bè` |
| `followingByMe=true`, `followsMe=false` | `following` | `Đang theo dõi` |
| `followingByMe=false`, `followsMe=true` | `followsYou` | `Theo dõi lại` |
| both false | `none` | `Theo dõi` |
| follow request not implemented | no `pending` emitted | deferred |

## UI Flow

Search remains the same three-tab UI: Place, User, Post.

User live search and submitted User tab now use real backend data. Tapping a user opens a real public profile by `userId`. Follow/unfollow actions call backend APIs and refresh search/profile state instead of only changing local UI state.

Public profile includes a Direct Message action that reuses the existing real direct-message repository. Group chat is unchanged/deferred.

Current account profile/settings now expose existing API-backed actions:
- edit profile fields;
- update avatar by URL through `avatarUrl`;
- change password.

Real image-file avatar upload is not implemented in this step because there is no user-avatar media upload contract yet.

## Boundary Preserved

- No Flyway migration.
- No new table.
- No new MongoDB collection.
- No Moment backend.
- No Group Chat implementation.
- Place recommendation/search source preserved.
- Post search remains mock/deferred.

## Validation

Commands run:

```text
dart format ...
flutter test
flutter analyze --no-fatal-warnings --no-fatal-infos
docker compose build api
docker compose up -d api
REST smoke: register A/B -> search -> follow -> follow back -> mutual
```

Results:
- `flutter test`: passed.
- `flutter analyze --no-fatal-warnings --no-fatal-infos`: completed with existing baseline warnings/infos; no compile error.
- `docker compose build api`: passed.
- `docker compose up -d api`: api/postgres/mongo running.
- REST smoke: passed; temporary users were removed from local PostgreSQL after the test.
- Maven backend tests were not run locally because `mvn` is not installed on this PC and the repo has no Maven wrapper.

## Deferred

- Backend Post Search.
- Real recent search persistence.
- Home user recommendation source/ranking.
- Followers/following/mutual list screens if product wants tappable lists.
- Private follow requests.
- Global social block.
- User avatar binary upload through Cloudinary/media flow.
- Moment Backend V1.
 
