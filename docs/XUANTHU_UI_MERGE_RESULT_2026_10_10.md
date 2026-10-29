# Xuanthu UI Merge Result - 2026-10-10

## Muc tieu

Merge latest `origin/xuanthu` UI vao code hien tai, dong thoi giu cac luong that da lam:

- Auth/Firebase/Google login.
- Home recommendation + Search/Place integration.
- Moment API/Mongo/Cloudinary flow.
- Direct Message V1.
- Profile/User/Search/Follow wiring.
- Map/Place real data va Home -> Map focus bridge.

## Git safety

- Tao backup branch truoc merge: `codex/pre-xuanthu-ui-merge-backup-20261010`.
- Stash local work truoc khi fast-forward: `stash@{0}: codex-pre-xuanthu-ui-merge-20261010`.
- Fast-forward len `origin/xuanthu` commit `01b24f7`.
- Apply lai stash va resolve conflict bang tay.

## Conflict da resolve

Resolved 6 conflict files:

- `lib/features/home/screens/home_screen.dart`
  - Giu UI header noi moi cua xuanthu.
  - Giu `ApiMomentsRepository` thay vi quay ve demo.
  - Giu refresh Moment khi app resume va periodic refresh.
- `lib/features/main/screens/main_shell.dart`
  - Giu logic hide bottom nav moi cua Map UI.
  - Giu bridge `HomeScreen.onOpenPostLocation -> MapFocusTarget`.
- `lib/features/map/screens/map_screen.dart`
  - Giu UI Map/Trip moi cua xuanthu.
  - Them lai `focusTarget` de Map co the focus Place/coordinate that.
  - Khong tao subsystem location moi.
- `lib/features/messages/data/message_repository.dart`
  - Giu contract UI moi cho group invite/itinerary hook.
  - Giu Direct Message V1 real repository.
  - Real Direct Message tra empty `inviteableItineraries` vi group itinerary/chat chua production.
- `lib/features/messages/screens/message_screen.dart`
  - Giu layout list moi.
  - Giu loading/error/empty/refresh state cho repository that.
- `lib/features/messages/widgets/message_widgets.dart`
  - Giu `GoMateSearchField` chung cua UI moi.

## Diem can luu y

- Group chat / group itinerary trong UI moi van la readiness/mock surface, chua production backend day du.
- Direct Message V1 van la real cho one-to-one conversation.
- Map UI moi tap trung vao Place/Trip surface; Home -> Map focus van duoc giu.
- Normal `flutter analyze` van bao nhieu warning/info style/deprecation co san tu UI moi va code cu. Khong xu ly trong task nay de tranh mass-refactor.

## Kiem tra da chay

```text
dart format <6 conflict files>
git diff --check
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test
docker compose build api
```

Result:

- `git diff --check`: pass.
- `flutter analyze --no-fatal-warnings --no-fatal-infos`: pass, khong con Dart error.
- `flutter test`: pass, 2 tests passed.
- `docker compose build api`: pass, Maven `clean verify` trong Docker chay 64 tests, build jar thanh cong.

## Canh bao con lai

- Khong co Maven global tren may dev, nen backend verify duoc chay qua Docker Compose.
- `stash@{0}` van duoc giu lai lam backup tam thoi, chua drop.
- Co nhieu warning/info analyzer ve `withOpacity`, unused/private/style trong code hien co; day khong phai loi compile va khong nam trong scope merge UI nay.

## Follow-up 2026-10-10 - restore xuanthu UI exactness

Theo feedback test, cac man hinh chinh can bam sat `origin/xuanthu` hon nua, dac biet Map. Da phuc hoi cac file UI chinh ve blob `origin/xuanthu`, sau do chi patch lai hook chuc nang nho:

- `HomeScreen`: tiep tuc dung `ApiMomentsRepository` va refresh Moment that.
- `MainShell`: tiep tuc truyen `HomeScreen.onOpenPostLocation` sang Map bang `MapFocusTarget`.
- `GoMateMapScreen`: tiep tuc nhan `focusTarget`, khong doi layout xuanthu.
- `MessageScreen`: default sang `RealDirectMessageRepository`.
- `MessageContactSearchScreen`: voi real repository thi search user tu API.
- `MessageAvatar`: ho tro avatar URL backend tra ve.

Bug Map da fix:

- Sau khi search mot Place, mo detail tu card tren map roi back ve Map, map reload lai explore list day du neu query dang bi filter.
- Selected Place van duoc render lai, nhung cac marker khac khong con bien mat.

Quy tac thuc hien:

- Khong rollback cac thay doi Moment/Profile/Search da co chuc nang that truoc do, vi cac thay doi nay la data/API wiring va camera/upload behavior da duoc test, khong phai thay doi nghiep vu UI moi.
- Khong chay `dart format` lai tren cac file UI vua phuc hoi de tranh tao diff format lon so voi xuanthu.

## Follow-up 2026-10-10 - xuanthu map/place detail color update

`origin/xuanthu` da co commit moi `dce3a2f` (`cap nhat mau maps va chi tiet dia diem`). Commit nay chi doi:

- `lib/features/map/screens/place_detail_screen.dart`
- `lib/features/map/services/mapbox_layer_controller.dart`

Da lay nguyen 2 file tren tu `origin/xuanthu` vi chung khong co local function hook rieng can merge tay. Cac hook chuc nang hien tai van giu o cac file khac:

- `GoMateMapScreen.focusTarget` va bugfix reset search marker.
- `MainShell -> HomeScreen -> MapFocusTarget`.
- Home Moment API, Message real direct repository.

Ket qua mong muon:

- UI chi tiet dia diem theo header moi cua xuanthu.
- Mau Mapbox basemap theo palette moi cua xuanthu.
- Map style request khong bi mat neu `onStyleLoaded` den truoc `attach`.
