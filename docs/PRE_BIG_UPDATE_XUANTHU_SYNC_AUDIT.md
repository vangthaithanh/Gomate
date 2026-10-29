# PRE_BIG_UPDATE_XUANTHU_SYNC_AUDIT.md

Updated: 2026-10-10

## Goal

Prepare the repository for the next Trip/Maps/Group Messaging Big Update by checking the latest `origin/xuanthu` UI delta without regressing real integrations.

## Git Snapshot

Commands executed:

```text
git status --short
git branch --show-current
git log --oneline --decorate -n 20
git stash list
git remote -v
git fetch --all --prune
```

Result:

```text
current branch: master
current HEAD: 28a41b9
remote origin: https://github.com/vangthaithanh/Gomate.git
stash present: stash@{0}: On master: codex-before-xuanthu-global-coldstart-20261002
origin/xuanthu after fetch: 01b24f7
origin/buitrong after fetch: 0eb6e1a
```

The working tree is dirty and contains important local integration work for MongoDB, Moment, Direct Message, Social Relationship, User/Profile and recommendation. Those changes must be preserved.

## Latest Xuanthu Delta

`origin/xuanthu` has three commits after current `HEAD`:

```text
fdde38f không pull
5cc18e9 Cập nhật lịch trình, tạo lịch trình, liên kết mess
01b24f7 Cập nhật chính lịch trình, maps, mess
```

The delta is large:

```text
41 files changed
16664 insertions
7486 deletions
```

High-impact areas:

```text
lib/core/widgets
lib/features/home
lib/features/main
lib/features/map
lib/features/messages
lib/features/trip
```

## Overlap With Local Real Integrations

The latest xuanthu UI touches files that also have local uncommitted real integration edits:

```text
lib/features/home/screens/home_screen.dart
lib/features/main/screens/main_shell.dart
lib/features/map/screens/map_screen.dart
lib/features/messages/data/message_repository.dart
lib/features/messages/screens/message_screen.dart
lib/features/messages/widgets/message_widgets.dart
```

These files are not safe for blind checkout because they currently preserve:

- real Home recommendation and map focus wiring;
- real Place/Map/Route integration;
- real Direct Message repository behavior;
- Moment strip and related real API flow;
- Auth/current-user/profile integration boundaries.

## Merge Decision

Do not run a blind `git checkout origin/xuanthu -- lib/` or force merge over the dirty worktree.

Recommended safe path:

1. Create a named backup/stash or temporary merge worktree.
2. Apply the xuanthu UI commits through a real three-way merge.
3. Resolve the six overlapping files manually.
4. Preserve real repositories/API calls over demo repositories.
5. Run Flutter analyze/test before accepting the merge.

## Current Action In This Task

No large Flutter UI overwrite was applied in-place because it would be a high-risk merge over uncommitted real integration work. The latest xuanthu commit was fetched and audited, and this file records the exact conflict surface for the controlled merge step.

## Must Preserve In Any Later UI Merge

- Auth/Firebase/current user/profile/settings/change password.
- Real user search, follow/unfollow, mutual friend and public profile.
- Direct Message V1 APIs and Mongo message body flow.
- Moment Backend V1 API/Mongo/Cloudinary flow.
- Place API, Mapbox, real route and GPS-to-place routing.
- Trip Core V1 API.
- AI recommendation, global cold-start, Screen 3 rerank and `GAN_TOI` GPS boost.

## Remaining Risk

The latest xuanthu UI includes Trip/Map/Messaging screens that intentionally move toward the Big Update shape, but current backend Group Trip/Group Chat/Member Location is not implemented yet. Treat those UI surfaces as readiness work unless a later task explicitly opens the backend migration.
