# ROADMAP_AND_DONE.md — GoMate Build Order, Milestones, Tests

> Compact execution context for Codex. Read this file for sprint planning, sequencing, acceptance, stabilization, demo, or Code Freeze work.

## 1. Authoritative roadmap

Use the redesigned `Ke_Hoach_GoMate` roadmap together with the FIXED Master Spec.

Project context:
- Thesis topic: **Nghiên cứu và xây dựng hệ thống du lịch thông minh dựa trên kiến trúc đa tầng và mô hình khuyến nghị cá nhân hóa (GoMate)**.
- Team size: 3 students.
- Duration: 12 weeks, 1-week sprints.
- Week 8: end-to-end milestone.
- Week 10: Code Freeze.
- Weeks 11-12: evidence, report, defense.

Do **not** use the older `Ke_Hoach_12_Tuan_GoMate_HoanChinh` plan as authority for a Supabase 1:1 migration. It represents an older migration-oriented direction. The newer plan + Master Spec supersede it: build the new target architecture and reuse old business knowledge/UI/assets selectively.

## 2. Practical implementation order from Master Spec

Do not create all 40+ tables/features at once.

```text
Step 1
Repository/project foundation
Docker Compose + Spring skeleton + Flutter skeleton
Health check Flutter -> Spring

Step 2 / Flyway V1
Auth/User/Interest
Register/login/onboarding

Step 3 / Flyway V2
Place/category/tag/save/review/submission
Cloudinary adapter
Search/place/save/review
Start interaction logging

Step 4 / Flyway V3
Social/follow/post/comment/bookmark

Step 5 / Flyway V4
Conversation metadata
Mongo messages + WebSocket

Step 6 / Flyway V5
Trip/member/invite/stop/reminder/checkin
Mongo location

Step 7 / Flyway V6
Notification/device/report/admin/audit
FCM/admin moderation

Step 8
AI FastAPI + recommendation_logs + feature pipeline
Personal/group recommendation end-to-end
```

This sequence is both a scope-control mechanism and a database-migration strategy.

## 3. 12-week roadmap

### Week 1 — Discovery + Scope Freeze
Backend/Data:
- inspect old code/schema only as reference,
- finalize domain/scope,
- finalize target architecture and ERD baseline.

Flutter:
- audit current screens/assets,
- classify reuse/rewrite/remove,
- avoid premature full rewrite.

AI/Admin:
- audit dataset v11,
- lock problem, metrics and experiment plan.

Required output:
- Architecture v1,
- Domain Map,
- ERD v1,
- MVP scope,
- UI audit,
- AI plan.

### Week 2 — Foundation
Backend/Data:
- Spring Boot,
- PostgreSQL,
- MongoDB,
- Spring Security/JWT,
- Flyway,
- Swagger/OpenAPI,
- Docker Compose.

Flutter:
- project foundation,
- theme/router/network,
- secure storage,
- error handling.

AI/Admin:
- validate/clean dataset,
- Association Rules skeleton/baseline preparation.

### Week 3 — Auth/User/Place foundation
Goal:
- Auth API works,
- user/profile/onboarding works,
- Place/search begins,
- Flutter integrates new API,
- AI baseline work continues.

Codex should not jump ahead to unrelated FCM/AI infrastructure when working on Foundation/Auth unless explicitly requested.

### Week 4 — Milestone 1
Must demonstrate:
- Auth/User/Place/Favorite/Review end-to-end,
- interaction event appears,
- Association vs Content-based has measurable evidence.

Evidence must include more than code:
- API response,
- screenshots,
- sample DB/event data,
- test/evaluation result.

### Week 5 — Trip core
- create/update Trip,
- add/remove/reorder stops,
- Flutter Trip builder,
- route/routing contract,
- SVD/Collaborative work progresses.

### Week 6 — Milestone 2
Must demonstrate:
- personal Trip,
- group Trip basics,
- map/route,
- Leader/Member permission differences,
- model comparison report,
- stable AI API contract/prototype.

### Week 7 — Realtime Location + Check-in + Hybrid
Backend/Data:
- `current_locations`, location history, retention policy,
- check-in distance/idempotency,
- member permission.

Flutter:
- realtime member map,
- GPS permission states,
- reconnect/offline states,
- check-in UI.

AI:
- Hybrid v1,
- spatial/temporal experiment,
- group aggregation experiment.

### Week 8 — Milestone 3: AI Service + FCM + End-to-End
Backend/Data:
- Spring recommendation client,
- notification records/device targets,
- FCM integration,
- audit integration.

Flutter:
- recommendation UI,
- push/deep-link behavior,
- final core integration.

AI:
- FastAPI service,
- model version,
- personal/group endpoints.

Must demonstrate:
```text
Flutter -> Spring -> AI -> recommendation
Group Trip -> location/check-in
Business event -> PostgreSQL notification -> push transport
```

### Week 9 — Stabilization + Evaluation
- full integration tests,
- indexes and query review,
- security/permission testing,
- latency measurement,
- Flutter regression/device tests,
- GPS/network/failure tests,
- AI metrics P@K/R@K/NDCG/Coverage and P50/P95 latency,
- Release Candidate 1 + bug list.

### Week 10 — Code Freeze
Allowed:
- bug fixes,
- data consistency fixes,
- deployment/backup,
- API/documentation completion,
- APK release,
- final AI experiment artifacts.

Not allowed by default:
- large new features,
- large new model families,
- major scope changes.

### Week 11 — Evidence + Report
- API/load tests,
- DB/API/architecture documentation,
- device tests,
- screenshots/video evidence,
- reproducibility check,
- AI tables/charts,
- near-final report.

### Week 12 — Defense
Prepare:
- architecture/database/security/performance Q&A,
- mobile/map/group demo,
- AI dataset/model/metrics/ablation/limitations,
- failure/fallback demo,
- slides/script/mock defense/final submission.

## 4. Milestones and acceptance evidence

### M1 — end Week 4
Required:
```text
Auth/User/Place/Favorite/Review end-to-end
Mongo interaction event
Association vs Content-based metric
```
Evidence:
- live API response,
- mobile screenshot/video,
- DB/event sample,
- evaluation table.

### M2 — end Week 6
Required:
```text
Personal Trip + Group Trip basic
Route/map
Leader/Member permission test
Model comparison
AI contract stable
```

### M3 — end Week 8
Required:
```text
Realtime location
Auto check-in
Notification/FCM demo
AI microservice
Recommendation screen
Spring calls AI for real
```

### M4 — Week 10
Required:
```text
Code Freeze
APK
Demo server/local fallback
Saved model/result artifacts
```

### Final — Week 12
Required:
- stable demo,
- complete documentation/evidence,
- architecture explanation,
- AI result explanation,
- fallback plan.

## 5. Mandatory demo flow

The final system should be able to demonstrate this story:

1. Register/login.
2. Home -> search/filter Place -> Place detail.
3. Save or review -> PostgreSQL business state + interaction event.
4. Personal recommendation with reason.
5. Create Trip -> add Places -> reorder stops -> route/map.
6. Convert/become Group Trip through member flow -> invite member -> shared plan.
7. Enable location sharing -> members appear on map -> one member auto check-ins at a stop.
8. Trigger group event such as invite/reminder/check-in -> another device receives notification/push.
9. Admin reviews/manages required user/place/report/audit state.

Fallback assets should exist for defense:
- release APK,
- deterministic seed/demo data,
- saved model artifact,
- Docker/local server,
- screenshot/video/mock for external service outages.

## 6. Acceptance test baseline

### Auth
```text
TC-AUTH-001 valid register
-> users/profile/settings created, nickname unique, password not exposed

TC-AUTH-002 duplicate email/nickname
-> 409, no partial record

TC-AUTH-003 wrong password
-> 401, no refresh session

TC-AUTH-004 LOCKED user
-> 403

TC-AUTH-005 revoked refresh
-> revoked/old token cannot refresh
```

### Follow/privacy/block
```text
PUBLIC account follow -> active follows immediately
PRIVATE account follow -> PENDING request
reciprocal active follows -> friendship semantics
block -> no new follow/request/DM
```

### Place/review
```text
internal search -> ACTIVE Place only
external provider down -> internal results still returned
external Place used for business action -> controlled match/import, no duplicate
review without check-in -> allowed, not verified
later valid check-in -> verified signal can update
second active review attempt -> update flow, not second active row
```

### Post/chat
```text
PRIVATE account cannot leak truly PUBLIC Post
Archive -> hidden from feed/profile/search
Bookmark -> does not bypass privacy/archive/moderation
Share -> link/deep-link only, no repost
mutual friend DM -> ACTIVE
non-mutual DM -> Message Request/PENDING
Trip member kicked/left -> cannot read new/send Trip chat messages
```

### Trip/invite/location
```text
Create Trip -> Trip + Leader member in one transaction
Member attempts stop edit -> 403
Leader reorder -> unique/consistent order
Member invites B -> B accepts -> WAITING_LEADER_APPROVAL, not member yet
Leader approves -> B ACTIVE, Trip GROUP, Trip chat sync
Leader invites B -> B acceptance joins without second approval
Kick -> member/location/chat privileges revoked

Trip not ACTIVE -> reject/no location write
sharing OFF -> no location write/check-in
inside radius + good accuracy -> exactly one check-in
poor GPS accuracy -> no auto check-in
raw >7 days -> archive success before purge
```

### AI/notification/admin
```text
new user -> interest/CBF/popular fallback available
AI down -> controlled backend fallback
Group recommendation -> no hidden/deleted/ineligible/already-added candidate
recommendation interaction -> requestId/modelVersion traceable

FCM failure -> business notification remains
push switch OFF -> no push, Notification Center row remains

place submission approval -> Place + link + audit
moderation hide -> normal user blocked from content + audit before/after
report resolution -> report/target/audit remain consistent
```

## 7. Required test categories

Unit:
- permission helpers/services,
- check-in distance/idempotency,
- recommendation helper/aggregation,
- event/DTO mapping.

Integration:
- register/login/refresh/logout,
- Trip + Leader transaction,
- invite workflow,
- save/review,
- recommendation gateway/fallback.

Permission:
- outsider cannot read Trip location,
- Member cannot perform Leader-only actions,
- privacy/block gates.

Device:
- GPS permission denied,
- GPS off,
- network disconnect/reconnect,
- push on 2-3 devices where available.

Performance:
- Place search,
- Trip detail,
- recommendation P50/P95.

Failure:
- AI service unavailable,
- FCM/Firebase unavailable,
- map/routing provider unavailable.

Security:
- password hash,
- JWT expiry/refresh,
- secrets server-side,
- upload validation,
- reasonable rate limiting where relevant.

## 8. Definition of Ready

Before starting a meaningful feature, Codex/team should know:
- Use Case,
- actor/permission,
- business rules,
- API request/response draft,
- table/collection/event,
- error/edge cases,
- minimum acceptance test.

If one of these is genuinely unknown and matters to correctness, do not invent it silently.

## 9. Definition of Done

A feature is **not done** just because:
- a screen exists,
- endpoint compiles,
- a table was created.

Done means the relevant end-to-end slice works:
```text
UI
+ API
+ service/business rule
+ persistence
+ permission
+ test data
+ error state
+ event/audit/notification when applicable
+ acceptance/regression test
```

## 10. Team workflow expectations

- One-week Sprint.
- Beginning of week: lock goals.
- End of week: real demo/review.
- Daily standup: done / doing / blocked.
- PRs should map to issue/feature and avoid giant end-of-week changes.
- DB migrations use Flyway.
- Mongo indexes/config need reproducible scripts/config.
- Save evidence each week: screenshots, JSON, test results, AI metrics, short video if useful.

## 11. Scope protection / what to cut first if late

Do not sacrifice P0 Trip/Group/Map/Check-in/Recommendation just to fit optional extras.

Older planning material lists examples of optional/bonus work that can be cut first:
- CI/CD,
- Redis cache,
- social OAuth2,
- advanced offline cache,
- NCF/LightGCN,
- nonessential dashboard/animation.

OAuth note: the current teammate Auth package already has Google sign-in as an extension. Existing working code is not automatically deleted because it appears on an optional list; scope changes require explicit decision. See `AUTH_CURRENT_STATE.md`.
