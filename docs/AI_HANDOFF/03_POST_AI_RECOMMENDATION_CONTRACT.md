# Place AI hiện có / Post AI chưa triển khai

## Đã có: Place cold-start

Spring [controller](../../backend/src/main/java/vn/gomate/recommendation/controller/RecommendationController.java): JWT GET `/api/v1/recommendations/home` và `/me`, query destinationKey/latitude/longitude/topK. [Service](../../backend/src/main/java/vn/gomate/recommendation/service/RecommendationService.java) lấy semantic/context survey codes, gọi [AI client](../../backend/src/main/java/vn/gomate/recommendation/client/AiRecommendationClient.java), map external_id về ACTIVE PostgreSQL Place, rerank context ở Spring và fallback PG khi lỗi/thiếu dữ liệu. Destination trống→null/global, không mặc định Đà Lạt cũ. CandidateK50/homeLimit10/timeout2500ms là cấu hình mặc định **Place**.

FastAPI [source](../../KPDL/api_service.py): POST `/recommend`, GET `/health`. Request thật: destination_key, selected_interest_codes (min1), context_codes, top_k1–100, include_runtime_ineligible (Spring gửi false). Response thật: model_version, selected_strategy, destination_key, selected_interest_codes, context_codes_received, context_note, total_candidates, items; item có external_id/name/destination_key/category/semantic status/score bounds/coverage. Không phải Post DTO.

Runtime ưu tiên `KPDL/training_output_research_final/gomate_ranker_research_v13.joblib`; v12/semantic assets giữ nguyên. AI Place identity ổn định là external_id, business Place là places.id BIGINT; không Mapbox feature ID/numeric ID local hay dùng model này làm Post model. Xem [v13](../AI_RANKER_V13_INTEGRATION.md), [semantic training guide](../../KPDL/GOMATE_AI_ML_SEMANTIC_V1_TRAINING_GUIDE.md).

## Chưa có: Post Home AI

Home Post thật: [GET /api/v1/feed](../../backend/src/main/java/vn/gomate/social/post/PostFeedController.java), [service](../../backend/src/main/java/vn/gomate/social/post/PostFeedService.java), chronological `(created_at,id)` có privacy/block. Chưa có Post model/AI endpoint/feature exporter/seed importer được bật. Không sửa Place recommendation để làm Post AI.

**Phần sau là ĐỀ XUẤT CHỜ DUYỆT, không phải API tồn tại.**

Luồng: Spring lấy candidate viewer đọc được → lọc deleted/account/audience/accepted follow/mutual/block → features tối thiểu đã duyệt → AI rank opaque IDs → Spring bỏ unknown/duplicate/invalid score, recheck quyền → project DTO hiện có. AI không tự query PG/Mongo để mở rộng candidates, không cấp nội dung thẳng cho client.

Internal route đề xuất `POST /rank-posts` (chưa tạo):
```json
{"request_id":"opaque-request","feature_version":"PROPOSED-post-v1","candidates":[{"candidate_id":"request-scoped-opaque-id","features":{}}]}
```
Response đề xuất:
```json
{"request_id":"opaque-request","model_version":"PROPOSED","items":[{"candidate_id":"request-scoped-opaque-id","score":0.5}]}
```

Features cố ý để trống đến review data/consent. Không gửi caption/title/hashtag/author/media URL chưa được phép tới model ngoài hệ thống. Không raw viewerId/email/session/DM/GPS/notification/report/media riêng tư. Không xuất likes/saves/comments/follows cá nhân hoặc tái dùng survey cho mục đích Post mới khi chưa duyệt phạm vi. ID chỉ map server trong request, không cấp quyền media; synthetic và tương tác thật tách riêng.

Owner phải duyệt trước code:
- data/features/consent/retention, model trong hệ thống hay bên thứ ba;
- candidate pool/horizon, seen policy/diversity/cold-start; chưa triển khai hide-seen;
- snapshot/cursor gắn actor, model/features/query/policy. Không reuse chronological cursor để giả stable AI ordering;
- đề xuất AI budget200ms/tổng fallback250ms (chưa là SLA đo được); không copy Place2500ms;
- rollout/metrics và thay đổi `/feed` nếu có; UI/DTO/media identity phải ổn định.

Timeout/error/NaN/unknown IDs/thiếu candidates→visible chronological fallback, dedup/fill theo trang và tái authorize. Home không phụ thuộc AI để mở. Xóa/đổi audience/block giữa ranking và response, cursor/deeplink/cache/thumbnail/Range không được bypass. Không auto Like/Save/Follow từ score.

Acceptance tương lai: offline/shadow so chronological; privacy/block race trước/sau rank; missing model/timeout/malformed/empty response; cursor ổn định/dedup; account-switch cache; latency thực và không reload ảnh/video vô cớ. Không benchmark trên dữ liệu thật ngoài phạm vi duyệt.
