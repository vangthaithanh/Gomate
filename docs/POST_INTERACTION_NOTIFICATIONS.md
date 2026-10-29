# Post Interaction Notifications

Date: 2026-10-23. Scope ends after Like / root Comment / Reply notifications.
User also requested unread red dots on notification/message icons and the honest
outgoing message label "Đã gửi", not an unsupported "Đã xem" receipt.

## Audit and Existing Contracts

- Actual local PostgreSQL: V1-V24 successful, 37 business tables. notifications
  already has JSONB data and UNIQUE(user_id,type,entity_type,entity_id); no type
  enum CHECK requiring a migration. post_likes has composite PK(post_id,user_id),
  not a durable separate Like ID. No V25 or schema/config/dependency change.
- Reuse NotificationService/Repository, after-commit EventPublisher, authenticated
  SSE, account-scoped NotificationRepository and unchanged 12s polling, Android
  device/session/push preference validation. No parallel notification subsystem.
- Reuse P2 Post permission/transaction locks and P3 idempotent Comment writes.
  Reply-to-reply already flattens to root and retains the real replyToUserId.
  Existing DM reference Share policy remains untouched: delivery grants no access.
- Older P2/P3/DM phase notes saying Post notifications are deferred describe their
  historical scope, not the rule after this extension.

## Recipient and Delivery Matrix

| New committed interaction | Recipient (never actor themself) | Inbox | SSE | Eligible Android FCM |
|---|---|---|---|---|
| POST_LIKE | Post owner | Yes | Yes | NO |
| POST_COMMENT | Post owner | Yes | Yes | Yes |
| POST_REPLY | Actual reply target only | Yes | Yes | Yes |

- Reply to another user on one's own Post still notifies that user; no second
  Comment notification. Root Comment/Like on one's own Post and self-replies do
  not notify. Reads, count updates, Save, Share, Report and comment-like do not.
- Like identity: POST_LIKE / "<postId>:<actor UUID>" under the existing unique
  recipient/type/entity key. Unlike -> Like never replaces/reset/re-emits an old
  row. Existing pre-phase Likes are not backfilled by reads or retry.
- Comment/reply identity: POST_COMMENT entity + committed numeric comment ID;
  existing actor/clientRequestId/payload hash prevents duplicate submit. Return
  of a committed retry does not create a new event or reattach media.
- Business write + Inbox insert share the PostgreSQL transaction. Only the INSERT
  winner publishes Change. Existing AFTER_COMMIT listener emits SSE/enqueues FCM;
  rollback emits neither. Transport failure keeps committed Inbox and interaction.
- FCM Comment/Reply uses the separate gomate_social_v1 Android channel, generic
  text + existing opaque notificationId/recipient hint. No private comment/caption/
  Post thumbnail/Cloudinary URL enters payload. Like is excluded before FCM calls.
  Existing valid Android device/session/account/notifications_enabled checks stay.

## API and UI

- Existing GET list/detail and PATCH read DTOs add nullable postId/commentId.
  No invitationId is fabricated. Existing Trip reminder/invitation fields remain.
- New GET /api/v1/notifications/{id}/post-target: JWT recipient-only, no-store,
  current Post authorization; returns postId/commentId/rootCommentId and
  commentAvailable. Deleted thread is unavailable even if its child row remains.
  Forbidden/deleted Post or another user's Inbox ID -> controlled 404.
- Tap resolves durable notification, marks read only on ACK, resolves target,
  then opens the existing protected Post viewer. Viewer/media recheck permission
  again. Denied content uses the existing unavailable layout, with "Quay lại
  thông báo"; DM's existing back wording stays unchanged.
- Comments open the existing real Comment sheet. It does NOT yet support safe
  arbitrary-thread scrolling, so this phase opens the sheet rather than inserting
  a fake thread, scanning all pages or inventing a comment focus UI. A deleted
  Comment yields "Bình luận không còn khả dụng" while permitted Post stays usable.
  Android follow-up 2026-10-28 found the original page SnackBar hidden underneath
  the modal sheet. This notice now renders inside the existing Comment sheet,
  with no timer; normal Comment openings remain unchanged. Acceptance details
  and physical retest status are in POST_LIKERS_AND_ANDROID_ACCEPTANCE.md.
- Parser has real ordinary POST_LIKE/COMMENT/REPLY types, safe copy, no Accept/
  Decline actions. One account-scoped receiver deduplicates SSE/FCM/polling by ID.
  Account switch clears store/seen/pending opens; delayed work cannot open old data.
- Home bell dot follows durable server unreadCount. Message dot follows real
  conversation unread counts, updated through the existing inbox refresh/read
  mechanisms. No new DM notification/push/realtime transport or polling is added.
  No inferred "seen by recipient" state: last acknowledged own message says
  "Đã gửi". Existing account display-name fix and inbox recency are preserved.
- Only icon subtrees listen for badge changes; no Feed/PostChanges broadcast,
  metadata refresh or player/image invalidation is triggered by notification ticks.
  Home retention, protected media, no-store/Range and 30s upload rules are unchanged.

## Files

- Backend: notification repository/service/DTO/controller, new
  NotificationPostTargetService; NotificationPushDelivery/FcmGateway/
  FirebaseFcmGateway; social post PostFeedRepository/Service and comment
  CommentRepository/Service. No Auth/Profile/Relationship/Trip/Map change.
- Android: MainActivity creates gomate_social_v1 alongside the unchanged invitation
  channel. No new permission, plugin, dependency, Manifest or secret config.
- Flutter: notification model/repository/screen; optional unavailable notice in
  existing Comment sheet/viewer; GoMateUnreadIndicator; Home bell/MainShell message
  icons; MessageRepository.hasUnread and chat sent label.
- Tests: PostInteractionNotificationTest, revised historical P2/P3 assertions,
  post_interaction_notification_test.dart and direct_message_privacy_test.dart.
- Repeatable PostgreSQL HTTP/restart check:
  backend/scripts/verify-post-interaction-notifications.ps1. It rejects the normal
  API/DB, accepts only port 18096 and gomate_post_notifications_verify, and stores
  synthetic sessions only under ignored backups. No provider upload is involved.

## Verification

- Targeted backend: 38 PASS (new phase 9, push 9, SSE 6, P2 6, P3 8).
  Covers concurrent writers/retries, self suppression, exact root/reply recipients,
  after-commit/rollback, stable Like identity/read state, transport outages,
  permission/deleted targets, push preference and separate social channel.
- Targeted Flutter: 115 PASS across notification Post/realtime/push/UI, DM,
  Comment/Report, Share/Search, Activity and Home retained media lifecycle.
- Analyze: 0 errors, 15 existing warnings, 340 infos; exit 1 due baseline lint.
  Not a lint-clean PASS, no new warning.
- Initial verification caught and fixed a test helper name shadowing Java's MockMvc
  post builder and a caption assertion that ignored the existing word-by-word
  layout. No business rule or UI was changed to satisfy those failed assertions.
- Additional backend regression: 104 PASS (Auth/Profile, privacy/relationships,
  Google/Firebase, DM/Group/Moments, Post publish/activity/share/search, Trip
  reminders). Total 142 UNIQUE backend tests in two targeted runs; Docker build
  rechecks the same 38, not 38 additional tests. These are not full-suite totals
  or a claim that an older baseline suite was rerun in its entirety.
- Root `docker compose build api` PASS with TESTS selecting the 38 phase/direct
  dependency tests. Main image contains the new service and separate FCM channel.
- Actual PostgreSQL restored V24 database: startup/Flyway validation PASS; HTTP
  test PASS for Like retry/Unlike/re-Like/self, Comment retry, exact Reply recipient,
  reply-to-reply root, recipient-only Inbox/read/target, privacy/ONLY_ME/thumbnail
  denial, deleted thread fallback and read ACK. Restart/relogin PASS: same Inbox
  IDs, read state and JSONB references; retry does not create another Like row.
  Synthetic users/Post/media metadata exist ONLY in this disposable database;
  push/provider upload were disabled. No new real Cloudinary asset was created.
- No schema migration was needed, so a new clean PostgreSQL schema rollout is
  N/A for this phase. H2 test contexts run existing V1-V24; actual PostgreSQL
  restored and main V24 startup validate existing schema without migration.
- Main API 8081 cutover: health UP, unauthenticated Inbox 401, max/history V24 /
  24 successful rows. All 37 business-table counts match the frozen before/after
  snapshot. No fixture write/backfill into main DB, no reset/repair/down-volume.
- Backups/logs under ignored backups/post-interaction-notifications: initial and
  frozen custom DB dumps, previous JAR/image ID, table counts, migration hashes,
  test/build/analyze logs and synthetic smoke sessions. Do not commit these.
  Recovery is deliberate old-image deployment/fix-forward after investigation,
  not Flyway repair or restoring a dump over new writes. Schema is unchanged.
- Temporary API and scoped PostgreSQL/Mongo verification DBs were removed after
  restart test. Maven containers auto-removed. Only standard api/postgres/mongo/ai
  remain; normal API port/ADB tunnel configuration is unchanged.
- Debug APK build PASS (218.0s), build/app/outputs/flutter-apk/app-debug.apk;
  SHA256 B2B6C6114C97891066ACCC1B967ED9ABCD0B1D17B2AD9D4F9063079FCC6411D2.
  NOT installed or tested on Android by the agent. Do not infer actual Android
  delivery from mocked FCM or widget tests. Native tests below remain PENDING.

## Android Acceptance: PENDING

Guided native follow-up and Like-list extension are tracked separately in
POST_LIKERS_AND_ANDROID_ACCEPTANCE.md. Its explicit owner confirmations supersede
PENDING rows here only for scenarios actually completed there; do not infer all
native cases PASS from the owner saying general two-account testing worked.

Build only; do not install/restart the phone without the owner's request.
Use Thanh and Thu, with an authorized Post (not a hidden ONLY_ME Post):
1. A Like B: B gets one ordinary Inbox/popup and a red bell dot; no OS Like push.
   Unlike/re-Like/retry do not reset unread or produce another popup.
2. Root Comment, Reply, reply-to-reply: verify exact recipient, no duplicate owner
   notification, no Accept button. Tap opens authorized Post/real Comment sheet.
3. Background and normal swipe-termination: Comment/Reply generic Android push,
   cold-start opens once after current server verification. Foreground has no
   duplicate OS popup. Permission denied/push off still keeps Inbox.
4. Delete Comment/root or Post; change privacy/audience/follow; tap old notification:
   no stale/private content. Account switch must not show old user's Inbox/open.
5. Read ACK clears bell dot when no unread remain; message unread dot follows the
   real inbox. Outgoing chat says "Đã gửi" and still uses real display name.
6. Scroll/Like/Comment/popup/tab return: preserve video position/player/image reuse.

No iOS push claim, delivery SLA, Global Block, moderation, AI Feed, Save/Share/
Report/comment-like notifications, new DM realtime, or other phase is included.
