# CODEX RECOVERY TASK — FREEZE, AUDIT, SYNC UI `f11c6f7`, THEN REDO TRIP INVITATION
## GoMate — large integration recovery after UI branch was incomplete

> **Situation**
>
> The previous Phase 4.1 work was started against an outdated/incomplete Flutter UI because the UI owner had not yet pushed the latest code.
>
> The newest approved UI reference is:
>
> ```text
> repo: vangthaithanh/Gomate
> branch: xuanthu
> commit: f11c6f7
> ```
>
> Three newest business/UI handoff documents are now authoritative:
>
> ```text
> GOMATE_SETTINGS_TONG_HOP_NGHIEP_VU_BAN_GIAO_BACKEND.md
> GoMate_Tao_Bai_Viet_Tong_Hop_NGHIEP_VU_BAN_GIAO_BACKEND_20261015.md
> GOMATE_TONG_HOP_NGHIEP_VU_VA_BACKEND_CLEANUP.md
> ```
>
> **Do not discard the previous Phase 4.1 work.**
> It may contain useful backend/invitation logic, but it must be audited and re-integrated into the newest UI/business flow.
>
> This is a **recovery + synchronization task**, not permission to redesign the app.

---

# 0. ABSOLUTE SOURCE PRIORITY

Use this precedence when anything conflicts:

```text
1. User's newest explicit decisions in this task
2. The 3 newest business/UI handoff MD files
3. UI structure/layout/components at xuanthu commit f11c6f7
4. Existing backend contracts and stable functionality already completed in current branch
5. Older project docs
6. Demo/local-only code
```

Do NOT let an older API shape or older Flutter screen override newer business/UI requirements.

---

# 1. FREEZE CURRENT PARTIAL WORK FIRST

Before any more edits:

```bash
git status
git branch --show-current
git log --oneline --decorate -n 20
git stash list

git diff --stat
git diff --name-status
```

Then inspect the partial changes already created by the interrupted attempt.

**Do not use:**

```text
git reset --hard
git clean -fd
git checkout --force
```

Do not throw away the partial invitation/backend work.

The current dirty diff is evidence that must be audited.

---

# 2. IMPORTANT: LARGE DELETION COUNTS ARE NOT AUTOMATICALLY OK

The interrupted run showed files such as:

```text
trip_screen.dart
```

with large deletions.

Do not continue assuming this is safe merely because the new UI file is shorter.

For every heavily changed Flutter file:

```text
compare:
A. current pre-sync version
B. xuanthu f11c6f7 version
C. current dirty/integration version
```

Explicitly identify whether removed lines were:

```text
UI-only old layout
DEMO code
or
REAL business/repository/state/navigation hooks
```

If real Phase 1/2/3 functionality was removed:

```text
DO NOT accept the deletion.
Reattach the existing real functionality to the new UI.
```

The intended result is:

```text
NEW UI
+
EXISTING REAL FUNCTIONS
```

not:

```text
NEW UI
-
OLD REAL FUNCTIONS
```

---

# 3. VERIFY THE EXACT UI COMMIT

Before copying anything:

```bash
git show --stat --oneline f11c6f7
git show --name-status f11c6f7
```

Confirm that `f11c6f7` exists locally and belongs to the expected `xuanthu` history.

If needed:

```bash
git fetch origin xuanthu
```

Do not merge the entire branch blindly.

Use `f11c6f7` as the exact UI reference.

---

# 4. DO NOT BLIND-MERGE `xuanthu`

Do NOT run a broad merge that can overwrite stable backend-integrated Flutter logic.

Instead:

```text
inspect exact UI files changed by f11c6f7
→ bring approved visual/layout/navigation structure
→ reconnect current real repositories/services/actions
→ remove only demo state whose call-site has a real replacement
```

If a screen in `f11c6f7` is mostly UI/demo, do not replace a currently working integrated screen wholesale without reattaching its real business behavior.

---

# 5. BUSINESS LOCK — UI MUST NOT BE INVENTED

The three handoff documents are UI/business contracts.

Do not invent:
- new pages;
- new buttons;
- new actions;
- new colors;
- alternative navigation;
- alternative invitation location;
- duplicate Profile/Post/Place screens;
- a second Trip member invitation screen if the approved UI already defines the interaction.

Reuse existing approved components such as:

```text
GoMateMainTabHeader
GoMateBottomSheet
GoMateSnackBar
GoMateNotificationPopup
GoMateProfilePostFeedScreen
PublicProfileScreen
TripDetailScreen
PlaceDetailScreen
GoMateMapUiSession
```

where the new source uses/requires them.

---

# 6. INTEGRATION PRINCIPLE

For each newest UI screen/component, classify every data/action as one of:

```text
REAL_EXISTING
DEMO_UI_ONLY
NEW_BUSINESS_NOT_IMPLEMENTED
```

Then apply:

### REAL_EXISTING

Reconnect to current repository/service/backend.

### DEMO_UI_ONLY

Keep only if needed to preserve the approved UI preview and no real API exists yet.

Never send demo IDs to the backend.

### NEW_BUSINESS_NOT_IMPLEMENTED

Keep approved UI structure but do not fake persistence/success.

Document as deferred.

---

# 7. DO NOT TURN THIS INTO “IMPLEMENT ALL 3 DOCUMENTS”

The three MD files define the approved UI/business universe.

This recovery task does **NOT** mean implementing every unfinished Settings/Post/Profile backend feature in one pass.

Primary scope:

```text
A. synchronize the approved UI at f11c6f7
B. reconnect functionality that already exists in the project
C. redo Trip Invitation correctly on the new Notifications UI
D. preserve approved UI for unfinished functionality without fake backend success
```

Examples:

```text
Post backend not yet present
→ DO NOT build the entire Post domain in this recovery task

Settings activity APIs not yet present
→ DO NOT invent all of them now

PIN password backend not ready
→ DO NOT wire an unrelated password API into the PIN UI
```

---

# 8. PRESERVE ALL COMPLETED CORE FUNCTIONALITY

Must preserve:

```text
Auth/Firebase login
Profile real data already implemented
User Search
Follow/Mutual
Direct Message
Moments
Trip Phase 1 membership/chat foundation
Trip Phase 2 stop/time/reorder/optimize
Trip Phase 3 pin/location snapshot
Mapbox route behavior
Map performance fixes
Place foundation
AI v13 integration
```

No regression is acceptable merely to match a new visual file.

---

# 9. MAP IS FROZEN FOR THIS TASK

Map has just undergone a safe performance audit.

Do not redesign/refactor Map.

Only make minimal navigation/model compatibility edits if required by the new UI.

Preserve:
- Mapbox;
- marker behavior;
- route;
- selected marker;
- Trip Stop marker;
- member LAST_KNOWN marker;
- performance improvements.

---

# 10. SETTINGS — LOCK THE PASSWORD DECISION

Newest explicit user decision:

```text
Keep the PIN UI.
Temporarily DO NOT activate password changing from that UI.
```

Therefore:

```text
ForgotPasswordScreen(changePasswordMode: true)
```

may remain as the approved UI/navigation basis, but:

```text
NO fake PIN success
NO real password mutation through an incompatible current-password API
NO pretending PIN/OTP backend exists
```

If the PIN backend is not implemented:

```text
PASSWORD_PIN_BACKEND = DEFERRED
```

Keep UI behavior safe and truthful.

Do not redesign the PIN screen.

---

# 11. CREATE POST — PRESERVE APPROVED UI, DO NOT FAKE BACKEND

The new Create Post UI/business document is authoritative for its UI.

Preserve:
- Profile `+` → Create Post;
- album-first UI;
- Camera cell;
- media order;
- up to 12 media;
- video rules;
- caption;
- hashtag;
- tag friends;
- one Place;
- audience UI;
- management UI.

But if the real Post backend is not yet built:

```text
DO NOT claim publish persistence
DO NOT create fake cross-screen server state
DO NOT implement an unrelated Post backend as side scope
```

Only reconnect already-existing real functionality.

---

# 12. CRITICAL BUSINESS UPDATE — ALL TRIP ADDITIONS NOW USE INVITATIONS

Newest user decision supersedes old Phase 1.2 direct-membership behavior:

```text
Member selected DURING Trip creation
→ SEND INVITATION

Member added AFTER Trip already exists
→ SEND INVITATION
```

A selected/invited user is **NOT a member until they accept**.

This is now canonical.

---

# 13. CREATE-TIME INVITATION NEW FLOW

Old behavior is obsolete:

```text
Create Trip + selectedMemberIds
→ directly insert selected users into trip_members
```

Do NOT keep that business behavior.

New flow:

```text
A creates Trip
selects B, C
        ↓
persist Trip
persist creator A only
        ↓
Trip remains PERSONAL
        ↓
create PENDING invitations for B, C
        ↓
create/link invitation notifications
        ↓
COMMIT
```

At this point:

```text
trip_members = {A}
B/C NOT members
NO linked Group Chat yet
```

Selection in creation means:

```text
invite these users after successful Trip creation
```

not:

```text
make them members now
```

---

# 14. FIRST ACCEPT TRANSITIONS PERSONAL → GROUP

Example:

```text
Trip X
members = {A}
PENDING invitation for B
```

B presses Accept in Notifications:

```text
backend verifies invitation
→ B inserted into trip_members
→ membership count becomes 2
→ Trip becomes GROUP
→ create exactly one linked GROUP conversation
→ conversation_members = {A,B}
→ invitation ACCEPTED
→ COMMIT
```

Only now is B a member.

---

# 15. SECOND/LATER ACCEPT REUSES GROUP CHAT

If C later accepts:

```text
same Trip
same linked Group Chat
trip_members = {A,B,C}
conversation_members = {A,B,C}
```

Never create a second chat.

---

# 16. EXISTING TRIP INVITE FLOW

For an already-existing Trip:

```text
LEADER chooses user B
→ create PENDING invitation
→ create/link notification
→ B remains non-member
```

Only Accept adds membership.

Do not local-add B to member avatars/list before server acceptance.

---

# 17. INVITATION UI LOCATION — NOT THE TRIP TAB

The previous self-created invitation acceptance area in the Trip tab is wrong for the new approved UI.

Remove/avoid that UI.

Invitation acceptance belongs to:

```text
GoMate Notification screen
```

according to the newest handoff.

---

# 18. PENDING INVITATION NOTIFICATION — EXACT UI CONTRACT

For:

```text
tripInvitation
status = PENDING
```

must carry real:

```text
notificationId
invitationId
tripId
```

Never confuse the IDs.

### Popup

`GoMateNotificationPopup`:

```text
top overlay
non-modal
no dim
NO green/blue Accept action inside popup
whole popup is tappable
```

Before user taps popup:

```text
NO route change
NO inbox reorder
NO accept
```

### Tap popup while still PENDING

```text
DO NOT open TripDetail
DO NOT auto-accept
→ open/focus Notifications
```

The specific notification becomes:

```text
#1 in notification list
before private follow-request section
before date groups
```

It must appear once only.

---

# 19. ACCEPT ACTION — ONLY ON NOTIFICATION ROW

For pending invitation:

```text
tap notification ROW BODY
→ remain in Notifications
→ focus the invitation
→ DO NOT open Trip Detail
```

Only:

```text
tap "Chấp nhận" action on the notification row
```

calls the Accept API.

Only after backend success:

```text
status = ACCEPTED
remove spotlight priority
return notification to normal time grouping
```

After ACCEPTED:

```text
tap row
→ open exact TripDetailScreen(tripId)
```

---

# 20. DO NOT INVENT A DECLINE BUTTON IN THE APPROVED UI

The newest UI/business file explicitly defines:

```text
Chấp nhận
```

as the pending invitation row action.

`Decline/Cancel` is future backend/business expansion unless separately approved.

Therefore:

```text
DO NOT add "Từ chối" button
DO NOT add a second action in the row
DO NOT create a separate accept/decline Trip screen
```

If a backend decline endpoint already exists from the interrupted Phase 4.1:
- it may remain unused safely if not harmful;
- do not surface it in the new UI;
- document it as non-UI/deferred or remove only if safe and truly unused.

---

# 21. NOTIFICATION PERSISTENCE — ALLOWED, BUT MINIMAL AND AUDITED

The interrupted work began adding PostgreSQL notification records.

This direction can be valid because the approved Notification inbox requires server-backed, cross-session state.

BUT before creating/changing schema:

```text
audit existing notification persistence first
```

Do not create a duplicate `notifications` source of truth if one already exists.

If no durable notification storage exists and Phase 4.1 requires an in-app inbox:

```text
a minimal PostgreSQL notification model is acceptable
```

because notification/invitation state is durable relational business data.

Keep:

```text
trip_invitations = invitation business truth
notifications = inbox/event record
```

Do not make notification row the authority for whether user is a Trip member.

---

# 22. TRANSACTION BOUNDARY — CREATE-TIME INVITATIONS

Creation with invitees must be atomic for durable business records:

```text
validate Trip
validate invitees
create Trip
insert creator only
create PENDING invitation rows
create/link durable notification rows if notification storage is part of this implementation
COMMIT
```

No Group Chat.

Any external/realtime/push event should occur only after commit.

If one invitee is invalid:
- follow current validation policy;
- do not silently create a false membership.

Document exact all-or-nothing behavior chosen.

---

# 23. TRANSACTION BOUNDARY — ACCEPT

Accept must atomically cover:

```text
lock/read invitation
verify current user is invitee
verify PENDING
insert trip_members
derive PERSONAL/GROUP

if first non-creator member:
    set GROUP
    create exactly one linked Group Chat
else:
    reuse existing Group Chat

sync conversation_members
mark invitation ACCEPTED
update notification state
COMMIT
```

Failure:

```text
NO partial member
NO partial chat
NO false ACCEPTED notification
```

---

# 24. INVITER ACCEPTED NOTIFICATION

Approved business includes:

```text
tripInvitationAccepted
```

for the inviter.

After B successfully accepts:

```text
A may receive a durable notification:
"B accepted your Trip invitation"
```

Tapping it may open A's Trip detail if access still exists.

Do not fake this before Accept transaction succeeds.

---

# 25. NOTIFICATION FOCUS RULE

For multiple pending invitations:

```text
tap popup B
→ B notification pinned #1

tap popup A
→ A notification pinned #1
→ B returns to normal group
```

No duplicated rows.

Use:

```text
notificationId
```

as focus/spotlight key.

Accept mutation uses:

```text
invitationId
```

Navigation uses:

```text
tripId
```

Never interchange them.

---

# 26. NO FAKE REALTIME CLAIM

If there is no actual WebSocket/SSE/push delivery yet:

```text
DO NOT claim realtime notification delivery is complete
```

Server-backed inbox can still be implemented.

Preserve `GoMateNotificationPopup` contract for future/available event transport.

Final report must distinguish:

```text
INBOX_PERSISTENCE_REAL
REALTIME_DELIVERY_REAL / DEFERRED
PUSH_REAL / DEFERRED
```

---

# 27. DEMO CLEANUP SAFETY

Do not mass-delete:

```text
ProfileUiPreview
SettingsUiDemo
DemoMessageRepository
DemoPostInteractionRepository
Notification demo fixtures
```

just because some call-sites now have backend data.

Safe order:

```text
real repository/adapter
→ replace one production call-site
→ test
→ search references
→ only remove demo field/class when zero required call-sites remain
```

Some QA screens may still depend on them.

---

# 28. REQUIRED INTEGRATION MATRIX BEFORE FINALIZING

Create:

```text
docs/UI_F11C6F7_INTEGRATION_MATRIX.md
```

For every major module touched:

| Module | f11c6f7 UI | Existing real function | Demo still present | Integration result |
|---|---|---|---|---|
| Profile | ... | ... | ... | ... |
| Settings | ... | ... | ... | ... |
| Create Post | ... | ... | ... | ... |
| Notifications | ... | ... | ... | ... |
| Trip | ... | ... | ... | ... |
| Map | ... | ... | ... | ... |

This is mandatory.

---

# 29. LARGE DIFF AUDIT

Final report must explicitly explain every file with substantial deletion/replacement.

Example:

```text
trip_screen.dart
before: X lines
after: Y lines
reason for deletion:
what real behavior was reattached:
what was UI-only/demo:
```

No unexplained large deletions.

---

# 30. TESTS — UI SYNC

At minimum verify:

```text
Profile opens and real current profile state still works
Settings opens with new approved layout
PIN password UI remains but does not fake password change
Create Post new UI opens from Profile +
Messages still opens
Trip list/detail still opens
Map still opens and retains performance fixes
Notifications new UI opens
```

---

# 31. TESTS — CREATE-TIME INVITATION

A creates Trip and selects B/C.

Immediately after create:

```text
Trip exists
trip_members = {A}
Trip = PERSONAL
B/C invitations = PENDING
B/C notification inbox contains real invitation
NO linked Group Chat
```

This test is mandatory because it deliberately replaces old Phase 1.2 behavior.

---

# 32. TESTS — PENDING UI

For B:

```text
pending invitation exists
```

Verify:

```text
popup has NO Accept button
tap popup → Notifications
selected invitation is #1
tap row body → stays Notifications
NO TripDetail
```

---

# 33. TESTS — ACCEPT FIRST MEMBER

B taps `Chấp nhận`.

Verify:

```text
invitation = ACCEPTED
B added to trip_members
Trip = GROUP
exactly one linked Group Chat
A+B in conversation_members
notification leaves spotlight
accepted row can open correct TripDetail
```

---

# 34. TESTS — ACCEPT SECOND MEMBER

C accepts.

Verify:

```text
same linkedConversationId
A+B+C trip_members
A+B+C conversation_members
no second Group Chat
```

---

# 35. TESTS — APP RESTART / OTHER DEVICE STATE

Pending invitation must come from backend after restart.

If invitation was accepted elsewhere:

```text
refresh state
→ do not still show active Accept
```

Do not rely on RAM `acceptedTripIds`.

---

# 36. TESTS — NO DECLINE UI

Verify approved Notifications screen:

```text
PENDING trip invitation
→ exactly approved "Chấp nhận" action
→ no invented "Từ chối"
```

---

# 37. REGRESSION — CORE

Must pass:

```text
Phase 1 Group Chat invariants
Phase 2 Trip Stop/time/reorder/optimize
Phase 3 pin/location snapshot
Map route
Map performance improvements
Direct Message
Moments
Follow/User Search
Auth
```

---

# 38. BUILD / VERIFY

Flutter:

```bash
flutter test
flutter analyze --no-fatal-warnings --no-fatal-infos
```

Backend:

```bash
docker compose build api
docker compose up -d api
docker compose ps
```

Run full Maven verify if backend/schema changed.

Run Flyway and report actual version.

---

# 39. DOCS TO CREATE/UPDATE

Create:

```text
docs/UI_F11C6F7_INTEGRATION_MATRIX.md
docs/BIG_UPDATE_PHASE4_1_TRIP_INVITATION_UI_SYNC_FINAL.md
```

Update:

```text
docs/PROJECT_CONTRACT.md
docs/DATABASE_CONTRACT.md
docs/CODEX_INDEX.md
```

Update older Phase 1.2 docs to clearly mark the old direct create-time membership rule as superseded.

Do not leave contradictory canonical docs.

---

# 40. FINAL REPORT — REQUIRED

Report:

## A. UI source

```text
xuanthu commit verified:
files integrated:
```

## B. Dirty-work recovery

```text
previous Phase 4.1 code reused:
previous Phase 4.1 code discarded:
why:
```

## C. Large deletions

Explain them file by file.

## D. Existing-function preservation

```text
Auth:
Profile:
Messages:
Moments:
Trip Phase 1:
Trip Phase 2:
Trip Phase 3:
Map performance:
```

## E. Settings

```text
PIN UI preserved:
password backend activated: NO
fake success: NO
```

## F. Create Post

```text
approved UI preserved:
real backend status:
demo/deferred status:
```

## G. Invitation

```text
create-time selection → PENDING invite: YES
existing-trip add → PENDING invite: YES
pending user is member: NO
first accept → GROUP: YES
first accept → linked chat: YES
later accept → same chat: YES
```

## H. Notifications

```text
PENDING popup Accept button: NO
popup tap opens Notifications: YES
pending notification pin #1: YES
row body opens TripDetail while pending: NO
Accept action location: notification row
Decline UI invented: NO
notificationId/invitationId/tripId separated: YES
```

## I. Persistence

```text
invitation source of truth:
notification source of truth:
new Flyway migrations:
Mongo changes:
```

## J. Delivery reality

```text
Inbox persistence:
Realtime popup transport:
Push:
```

Do not overclaim.

## K. Tests

List exact PASS/FAIL.

---

# 41. STOP CONDITIONS

Stop and report instead of inventing behavior if:

```text
f11c6f7 cannot be verified
new UI conflicts with one of the 3 authoritative MD files
a large deletion would remove stable Phase 1/2/3 behavior and cannot be safely reattached
notification persistence already exists but conflicts with the partial implementation
a required invitation state cannot be represented safely without a schema decision
```

---

# 42. DONE CONDITION

Only conclude:

```text
UI_F11C6F7_SYNC_COMPLETE
EXISTING_FUNCTIONS_REATTACHED
TRIP_INVITATION_REBUILT_ON_APPROVED_NOTIFICATION_UI
SAFE_TO_CONTINUE
```

when all of the following are true:

```text
new approved UI is present
existing stable functions still work
no major unexplained deletion remains
create-time selected users are invitations, not direct members
existing-trip additions are invitations
pending invitations live in Notifications UI
only approved Accept action is exposed
membership/chat happen only after server Accept
Map performance fixes survive
Settings PIN is visually preserved but backend-disabled
unfinished Post/Settings functions are not faked
tests pass
docs no longer contradict the new invitation business
```
