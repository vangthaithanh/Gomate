> Publication copy 2026-10-29: device/account identifiers redacted; test results and original limitations are unchanged.

# Post Likers and Android Notification Acceptance

Date: 2026-10-23. Owner requested a real Like long-press list and guided physical
notification tests. Preserve UI, media retention, existing permissions and delivery
policy; no schema migration or new business notifications.

## Like Long-Press

- New GET /api/v1/posts/{id}/likes?size=20&cursor= returns items[] with userId,
  displayName, nickname, avatarUrl, plus nextCursor. JWT + fresh Post authorization
  before/after read; denied/private/deleted Post is hidden with 404. No-store is
  supplied by the existing PostRequestPolicyFilter. Size 1..50.
- Active users only, newest Like time then UUID descending. Keyset cursor binds
  viewer and Post; no new index/table/migration. No notification from this read.
- Long-press existing heart/count in Home or protected Post viewer/Profile opens
  existing GoMateBottomSheet with real avatar/name rows, Xem thêm, loading/empty/
  retry/denied/session-change states. Tap a row opens its existing public Profile.
  No follow/DM action is added; tapping Like normally keeps its current behavior.
- Account switch clears rows/rejects late reads. Resume refreshes only the opened
  Like sheet; Post/media are not invalidated. No background preload or new polling.
- Files: PostDtos, PostFeedController/Service/Repository, PostRepository.dart,
  post_likers_content.dart, existing Home/Profile action callbacks; tests in
  PostFeedApiTest and test/post_likers_test.dart.
- Tests: 33 backend PASS in Docker (9 Feed including 3 new list tests, 9 Post
  notifications, 6 SSE, 9 push); 45 Flutter PASS (list, notification, Feed/Profile,
  media lifecycle/retention). Analyze 0 errors/15 old warnings. Initial widget
  long-press tests used an offscreen desktop-sized target; fixed test viewport/
  frame pumping, not app layout or gesture behavior.
- API 8081 updated. All 37 business-table counts match frozen before/after;
  Flyway max V24, all successful. No migrations/config/secret/dependency change.
  Backup DB/JAR/counts and logs: ignored backups/post-likers-device-acceptance/.
- Debug APK build PASS (181.1s), SHA256
  7822BF6A1EB45ECDD5A4FA8C6A9087284173C766353DF69E04C8EA595BC2E945.
  Owner authorized USB update: adb install -r succeeded on ANDROID_DEVICE_SERIAL;
  same app launched and API 8081 reverse restored. Installation is not yet
  confirmation of the signed-in account or delivery behavior. Real PostgreSQL
  GET /posts/2/likes returned an empty real list to the authorized test actor;
  no interaction sent at that preparation step.

## Physical Test Protocol

- User confirmed: current Google Thanh, PUBLIC for testing, phone USB connected
  ANDROID_DEVICE_SERIAL; authorized agent to install APK update preserving app data.
- Counterparty is the existing ACTIVE "GoMate Test Realtime" controlled account,
  authenticated via its pre-existing ignored fixture. Never extract or impersonate
  Thanh/Thu tokens. Read-only inspection verified it may read Thanh's Post 2 and
  had not yet Liked it. Do not change audience/follows/privacy to bypass access.
- scripts/diagnostics/post_notification_device_acceptance.ps1 uses only real
  business APIs; actor/recipient/Post checks guard deliberate fixture writes.
  Comments are labelled [TEST GoMate] with time. SQL is diagnostic READ-ONLY;
  it never inserts notifications or changes device tokens/business truth directly.
  Credentials and request state stay ignored, never printed into this report.
- Verify actual phone state BEFORE each send; do not open/relaunch during a
  background/killed test. FCM SENT alone is not a physical PASS. Count/popup/tag/
  server evidence and owner's confirmation are recorded separately.
- Like policy remains Inbox + SSE only, NO Android push. Comment/Reply may use
  Android push on gomate_social_v1 when eligible. Foreground delivery has one
  ordinary popup, no duplicate OS popup, no Trip Accept button. Keep 12s fallback.

## Device Matrix (Closed at Owner Request 2026-10-28)

| Case | Expected | Status |
|---|---|---|
| Install/update; Thanh at Home; real session and device registration | No login data loss; API tunnel works | PASS: user confirmed Thanh Home; 1 eligible Android binding |
| Foreground fresh Like | One Inbox + popup, red dot, no OS push/repeat | PASS popup/Inbox/no OS/no repeat; red dot not separately confirmed yet |
| Unlike / Like again / retry | Same notification ID/read state; no extra popup | PASS: owner confirmed no new popup/row; SQL preserved ID/read state |
| Long-press Like in Home/Profile | Name/avatar list; no Like/Unlike write | PASS in notification-opened viewer: owner saw GoMate Test Realtime; Home path automated PASS, physical not separate yet |
| Fresh Like while background | No OS push; durable Inbox on return | PASS: owner confirmed no OS and Like in Inbox after return |
| Foreground root Comment | Correct owner, one popup, real Post/comment sheet | PASS: owner confirmed popup/no OS/no repeat/red dot/real Post + sheet; request retry same IDs |
| Reply and reply-to-reply | Actual target only, no extra owner/self notice | PASS 2026-10-28: actual recipient verified, owner confirmed one Reply popup/no OS/no repeat/correct open |
| Background Comment | Generic OS push, tap authorized Post once | PASS 2026-10-28: Launcher verified before send, owner confirmed Android push/correct Post + sheet/no Accept/no duplicate open |
| Process-dead Comment (non-Force-stop) | Cold start opens authorized Post once | PASS 2026-10-28: no PID / stopped=false before send; owner confirmed Android push, Thanh session retained, correct Post/sheet once |
| Delete Comment after push, before tap | Permitted Post + unavailable Comment notice | PASS 2026-10-28 after modal notice hotfix: owner confirmed correct Post/sheet, visible inline unavailable notice, deleted Comment absent |
| Push preference/permission off | No OS push, Inbox/SSE retained | SKIPPED physical at owner's request 2026-10-28; automated coverage only, not native PASS |
| Logout/account switch/stale tap | No old-account content or navigation | PASS 2026-10-28: owner switched Thanh -> Thu; old Android notification remained, tap kept Thu and opened no Thanh notification content |
| Self Like/Comment/Reply | No self notification | PASS 2026-10-28: owner confirmed no self notices; SQL verified own Likes, root 17, self Reply 18 and 0 self notifications |
| Privacy/deleted Post; offline/re-login | Fresh authorization/error, no stale content | Automated PASS; physical PENDING |

Do not mark remaining rows PASS without a real run/owner confirmation. Ordinary
swipe from Recents is NOT Force stop. iOS, Force-stop delivery, DM realtime and
new Save/Share/Report/comment-like notifications are not part of this work.

## Physical Evidence Log

- 20:08:39 +07, Post 2, notification REDACTED_UUID:
  controlled actor Like -> exactly 1 POST_LIKE row for Thanh. Device was
  GoMate TOP before send; native log received CREATED/reconcile at 20:08:40.
  No FCM delivery entry or matching Android tray record. Owner confirmed all
  four: one in-app popup, no Android notification, no repeat after 15s and one
  correct Inbox row. Read state was still false at initial diagnostic snapshot.
- Owner then confirmed the Like row opens the correct Post and long-press heart
  shows GoMate Test Realtime. Opening row set is_read=true on the real server.
  At 20:11:06/10/13, API Unlike -> Like -> repeat Like retained exactly the same
  notification UUID, original created_at and is_read=true. UI no-new-popup/no-new-
  row confirmation is pending the next owner response.
- Owner confirmed no new popup/Inbox row after Unlike/re-Like/retry, then pressed
  phone Home. Launcher TOP was verified before fresh Like on Post 1 at 20:12:36;
  notification REDACTED_UUID has exactly one durable row.
  After 15 seconds there was no matching Android tray entry or FCM delivery log.
  Owner confirmation of background Like/no OS/Inbox return is pending.
- Owner confirmed background Like had no Android notification and was present in
  Inbox on return, then held Thanh Home open. GoMate TOP verified before root
  Comment 7 on Post 2 at 20:14:12, notification REDACTED_UUID.
  SSE CREATED/reconcile at 20:14:13; FCM SENT to Thanh's eligible device, no matching
  OS tray record while foreground. Retried the same request at 20:14:36: same
  Comment ID / notification UUID, exactly one row. Physical popup/open confirmation
  pending; FCM SENT by itself does not establish foreground/background acceptance.
- Owner confirmed foreground Comment: exactly one popup, no Android duplicate,
  no repeat, red bell dot, correct real Post and Comment sheet opening. Next
  instruction asks Thanh to reply to controlled root 7, not to Like/comment self.

## Resume 2026-10-28

- Owner resumed at Thanh Home. Verified USB ANDROID_DEVICE_SERIAL, GoMate TOP, reverse
  8081->8081, API health UP and one eligible Android push binding. No APK install,
  rebuild, API restart, configuration change or business-rule change in this resume.
- Existing root 7 and Thanh reply 8 on Post 2 remain ACTIVE. Reply 8 correctly
  targets the controlled test user; its one POST_REPLY Inbox record is
  REDACTED_UUID, recipient GoMate Test Realtime, not Thanh.
- Before sending the reply-to-reply, the helper's authorized GET /posts/2 returned
  controlled 404. Current owner settings are PRIVATE; Post 2 uses ACCOUNT audience.
  No new Reply/notification was written. Preserve authorization; do not mutate
  privacy, create accepted follows directly or bypass it with fixture SQL.
- Asked owner whether to keep PRIVATE and authorize only the test account through
  the existing follow request UI, or temporarily switch PUBLIC personally. Waiting
  for that choice before continuing native Reply/background/cold-start checks.
- Owner chose keeping PRIVATE and allowing the controlled account to follow.
  Real PUT follow returned followingByMe=false / followRequestPending=true;
  owner then accepted in the app and returned to Home. Authorized GET /posts/2
  succeeded afterward. No accepted edge was written through SQL or impersonation.
- At 15:06:07 +07, controlled actor replied to Thanh Comment 8: new Comment 11,
  root 7, reply target Thanh. Exactly one POST_REPLY notification for Thanh:
  REDACTED_UUID. FCM SENT; GoMate TOP before sending and
  SSE CREATED/reconcile observed at 15:06:08. No matching OS tray record while
  foreground. Physical one-popup/no-repeat/correct-open confirmation pending.
- Owner confirmed all foreground Reply checks: one correct Reply popup, no Android
  duplicate, no repeat, correct Post + real Comment sheet. This closes the interrupted
  reply-to-reply case; no extra POST_COMMENT was emitted for Comment 11.
- Background Comment 12 at 15:07:49 +07: notification
  REDACTED_UUID; Launcher TOP verified BEFORE send, FCM SENT.
  Owner confirmed one Android notification, correct Post/Comment sheet opening,
  no Accept action and no duplicate open. No agent app launch during this test.
- Owner then swiped GoMate from Recents. Launcher TOP was confirmed, but process
  24114 remained alive. This is not evidence of a true process-dead cold start.
  Asked permission for ADB background-process termination (not Force stop), which
  may temporarily interrupt background work. No process termination or next push
  was performed while waiting for that choice. Cold-start case remains PENDING.
- Resume read-only Flyway check: max V24, all history rows successful. No code,
  migration, configuration or deployment change was needed for these native tests.
- Owner approved non-force-stop process termination for a true cold-start test.
  am kill did not remove the live process; scoped run-as signalling was denied.
  Diagnostics identified an ACTIVE foreground GeolocatorLocationService, matching
  the pinned-Trip location runtime. Package stopped=false remained unchanged.
  No Force stop/root/permission changes, no GPS-coordinate read and no new push.
  Asked owner to temporarily unpin via existing UI, then close GoMate, or retain
  the pin and leave the true process-dead variant unverified. Never unpin via SQL
  or silently alter the location business flow for a notification test.
- Owner temporarily unpinned in UI: server pin count=0. Android still showed a
  foreground Geolocator service; this observation alone does not establish that
  coordinates were still being published. No GPS architecture change was made.
  Android 13 `cmd activity stop-app --user 0 com.example.gomate` then stopped the
  process/services; PID absent and package stopped=false verified. This is the
  documented Task Manager stop action, not Force stop:
  https://developer.android.com/develop/background-work/services/fgs/handle-user-stopping
- Owner interrupted immediately before the cold-start send. No Comment/push was
  sent in that stopped interval, so cold-start delivery remains UNVERIFIED, not PASS.
  Owner subsequently relaunched GoMate and confirmed Thanh signed in. API health,
  USB reverse and GoMate TOP were checked again; asked owner to close for a fresh
  controlled cold-start send. Do not count an app-open send as a killed-app test.
- Owner closed GoMate again and explicitly confirmed readiness. Before the next
  send: Launcher TOP, no GoMate PID, package stopped=false. At 15:29:56 +07,
  controlled root Comment 13 on Post 2 created exactly one Inbox notification:
  REDACTED_UUID. FCM SENT to Thanh's eligible device.
  No agent app launch. Awaiting owner confirmation of Android delivery and
  correct single cold-start navigation with Thanh session retained.
- Owner confirmed cold-start Comment 13 all checks: Android push received,
  tap reopened GoMate, retained Thanh login, opened correct Post/Comment sheet
  exactly once. The matched tray entry was no longer present when sampled after
  the user could have tapped; do not claim a tray observation that was not made.
  Process-dead condition is proven before send, delivery/navigation by owner.
- Stale-Comment test: owner confirmed Launcher/background and agreed to wait before
  tapping. Controlled root Comment 14 on Post 2 at 15:32:48 +07 created one
  notification REDACTED_UUID; FCM SENT. Deleted only
  Comment 14 through its author's real DELETE API before asking the owner to tap.
  Read-only SQL confirms publication_status=DELETED and original unread Inbox
  row retained. Physical stale-notification navigation remains PENDING.
- Owner requested a repeat; the Comment 14 attempt has no physical verdict.
  Verified Launcher TOP again before controlled Comment 15 at 15:40:06 +07,
  notification REDACTED_UUID, one row, FCM SENT.
  Deleted only Comment 15 through its own API before the tap instruction;
  SQL confirms DELETED and unread notification retained. Owner confirmed correct
  Post/Comment sheet and Comment 15 absent, but no unavailable notice was visible.
  Record this as PARTIAL, not PASS. Investigating the modal notice presentation.
- Root cause reproduced by strengthening the existing widget assertion: the
  unavailable text existed in a page SnackBar but failed hit-testing because the
  modal Comment sheet covered it. The old text-only assertion had passed.
  Replace only initialNotice presentation with an accessible inline notice inside
  the existing Comment sheet, using existing colors/type and fixed sheet bounds.
  Normal sheets have no extra row; permission, API, media/player and notification
  delivery are unchanged. No backend/schema/migration/config/dependency edit.
- Follow-up Flutter tests: 42 PASS across post_interaction_notification,
  post_comment_report, notification_push and notification_ui_sync. Includes
  visible notice above the modal after 11s, no warning for an available Comment,
  and existing composer keyboard regression. Red-before / green-after observed.
  Physical retest remains pending installation of the new APK.
- Targeted analyze of the edited widget/test: 0 errors, 0 warnings, 26 existing
  info-level lints (exit 1). Not a lint-clean result; no broad formatting cleanup.
- Hotfix debug APK build PASS (170.6s), SHA256
  79CC701D3209124D555251FBD3F09E83F3AE2FB425E9F509C49FC2B6FBA52E57.
  Installed via the previously authorized USB update (`adb install -r`: Success),
  restored 8081->8081 and launched GoMate. Waiting for owner readiness before
  a fresh background send/delete/tap; do not treat installation as physical PASS.
- Hotfix native retest: owner confirmed Thanh and pressed Home. Launcher TOP
  verified before controlled Comment 16 on Post 2 at 15:53:26 +07, notification
  REDACTED_UUID, one Inbox row, FCM SENT.
  Deleted only Comment 16 via its author's API before asking the owner to tap.
  SQL confirms DELETED and original unread Inbox retained. No agent app launch
  during background send/delete. Awaiting owner confirmation of inline notice.
- Owner confirmed Comment 16 native retest: correct Post and Comment sheet,
  inline "Bình luận không còn khả dụng" visible, deleted Comment absent.
  This closes the stale-deleted-Comment case as physical PASS after the fix;
  the earlier missing-notice observation remains recorded above.
- Owner explicitly skipped physical push-permission testing. Read-only Android
  check confirms POST_NOTIFICATIONS granted=true; no OS permission or server
  push-preference mutation was necessary. Keep normal notifications enabled.
  Do not count this skipped variant as a physical PASS.
- Owner confirmed performing self Like/Comment/Reply with no self notification.
  Read-only diagnostics: self notification count remains 0 (baseline 0), two
  current Likes on own Posts, new ACTIVE root Comment 17 on own Post 2.
  No new self Reply row was present at this snapshot; clarify that it was
  successfully sent/persisted before claiming complete server verification.
  Initial diagnostic used nonexistent posts.user_id and failed read-only;
  inspected actual columns, corrected to posts.author_id. No data was mutated.
- Owner confirmed the self Reply was sent/visible. Follow-up SQL now verifies
  ACTIVE Comment 18 on Thanh's own Post 6, parent 5, reply_to_user_id=Thanh.
  Self POST_LIKE/POST_COMMENT/POST_REPLY notification count remains exactly 0.
  Together with owner confirmation, the self-notification case is physical PASS.
- Account-switch test preparation: owner kept Thanh signed in and pressed Home;
  Launcher TOP verified before controlled Comment 19 on Post 2 at 16:09:52 +07.
  Notification REDACTED_UUID: one durable row, FCM SENT.
  Asked owner not to tap until switching to Thu via the app's normal logout/login.
  No agent app launch, token impersonation or device-binding mutation.
  Old-account notification navigation remains PENDING physical confirmation.
- Android diagnostics observed the exact notification tag
  REDACTED_UUID on gomate_social_v1 before switching.
  Owner then logged out Thanh, logged in Thu and tapped that old notification.
  Owner confirmed it remained in the tray, kept the Thu account and did not open
  content from Thanh's notification. Account-switch/stale-tap is physical PASS.
  No app restart/reinstall or agent account impersonation during this scenario.

## Acceptance Closure — 2026-10-28

Owner explicitly chose to close the current physical test session and document
the remaining cases. No further interactions, permission changes, account changes,
Post audience changes or test-data cleanup were performed as part of closure.

Physically confirmed PASS:
- Foreground Like/Comment/Reply delivery and deduplication; Like has no Android push.
- Unlike/re-Like/retry does not create duplicate Like notifications.
- Long-press Like list in the notification-opened Post viewer.
- Background Comment push and true process-dead cold-start opening once.
- Deleted-Comment notification opens the permitted Post and real sheet, with a
  visible unavailable notice after the modal presentation hotfix.
- Self Like/Comment/Reply produces no self notification, with persisted interactions.
- Old Thanh notification tapped after switching to Thu does not open old-account
  content or switch the signed-in account.

Remaining physical coverage, explicitly not claimed PASS:
- Push preference/Android permission disabled: skipped at owner's request;
  automated coverage only. Android POST_NOTIFICATIONS remained granted.
- Post privacy/audience/access changes or Post deletion before notification tap:
  automated PASS, native run not performed. Deleted Comment was tested separately.
- Offline/reconnect/re-login notification handling: automated PASS, native variant
  not performed; the completed account-switch case is not proof of every variant.
- Home-specific long-press Like list and Like-specific red-dot observation were
  not independently confirmed. Viewer Like list and Comment red dot were confirmed.

Hotfix validation actually run: 42 targeted Flutter tests PASS; targeted analyze
0 errors / 0 warnings / 26 existing info lints (exit 1); debug APK build PASS and
USB install succeeded. No backend rerun was needed for this Flutter-only notice
fix, and no new backend/full-suite PASS is claimed. No migration/config/dependency
change; last verified Flyway remains V24. Physical acceptance is limited to Android.

Controlled test Comments/Like records, accepted test follower and Inbox history
remain; no silent cleanup of user data. Owner temporarily unpinned for cold-start
testing and may manually pin again. Notification navigation never pins a Trip.
