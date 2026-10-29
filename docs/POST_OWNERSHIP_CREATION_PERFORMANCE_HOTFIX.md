# Post V21: Menu, Creation Modes And Feed Performance

Ngay 2026-10-22. Hotfix sau P2, dung truoc P3. Khong thay backend/schema/API,
khong tao migration, khong thay quyen xem media hay thu tu Feed.

## 1. Nguyen nhan menu

- Feed da co authorId that. _HomePost.server giu nguyen DTO va profilePost truyen
  authorId vao viewer. Khong phai loi PostgreSQL, JWT hay thieu field backend.
- Home._openPostActions truoc day luon mo PostActionContent cua nguoi khac.
  Owner menu P1C chi duoc noi tai viewer/Profile, nen hai loi vao bi lech.
- PostMenuActions hien la mot nguon logic chung cho Home va moi remote viewer.
  Doc detail moi tu server, so sanh authorId voi auth.user.id that, khong dung
  ten/avatar/demo state. Backend van la noi quyet dinh quyen cuoi cung.
- Owner dung lai menu/picker/xac nhan P1C: Ghim, doi quyen rieng tu, Xoa.
  Ghim chi tac dong Profile, khong doi Home sort. Owner khong thay Bao cao.
- Non-owner khong co hanh dong owner. Bao cao van chi bao chua kha dung;
  khong tao Report/Comment/Share backend hay thong bao thanh cong gia.
- Chan mo menu trung; menu an/dong khi logout/doi user. Kiem tra lai actor sau
  moi async gap; 401/403/404 goi revalidation. Xoa chi go bai sau server ACK.
  Cancel/API fail khong xoa gia. Dung lai PostChanges de dong bo Home/Profile.

## 2. Dau + Tren Home

- Badge + cua ban tren MomentsStrip mo GoMateCreatePostScreen voi
  enableMomentMode=true: mac dinh Bai viet, chua mo camera Khoanh khac.
- Thanh duoi co Bai viet/Khoanh khac; cham hoac vuot ngang tren thanh de doi.
  Khong bat cu chi vuot tren gallery, anh bai viet hay khung camera.
- Tai su dung form, gallery, trim, caption/audience va camera cu. Khong sao chep
  bo cuc mau Instagram, khong dung anh QR trong anh tham khao lam asset.
- Chuyen che do giu state draft trong CreatePost; khong giu widget video/camera
  native dang an. Quay ve Bai viet dispose camera; vao Khoanh khac moi khoi tao.
  Guard async camera discovery/initialize tranh tao camera sau khi da roi che do.
- Khong doi che do khi dang xu ly media/dang tai Moment. An thanh khi sang form
  caption/de dang bai khong bi ngat. Cac loi vao Create Post khac giu nguyen.
- Moment van chup truc tiep, flash trai/dao camera phai; khong them upload tu
  thu vien. Preview chi thu them neu man hinh thap khong du cho thanh moi.
- Gioi han 12 media, video moi 30s, trim that va media bao ve giu nguyen.

## 3. Toi uu cuon Home

- Header dung ValueNotifier va child co dinh: doi huong cuon chi rebuild header,
  khong rebuild ca Home, map lai tat ca Post hay dung lai media.
- Feed listener chi rebuild danh sach. MomentsStrip va avatar highlight tu nghe
  Moment repository, khong goi setState toan Home moi lan repository refresh.
- Gan key cho ca Post va cac rail; findChildIndexCallback giu dung mounted tile
  khi insert/delete/refresh doi vi tri. Giu ScrollController, khong jump ve dau.
- Bai chi co mot media khong can PageView ngang. Gioi han/tach list media mot
  lan khi map DTO, tranh tao list take(12) lap lai trong moi lan build card.
- Guard load-more truoc khi tao Future tren cac scroll tick khong can request.
- Anh Home giai ma theo chieu rong hien thi x devicePixelRatio, khong giai ma
  anh goc qua lon chi de ve mot o tren dien thoai. Evict ca ResizeImage khi
  dispose/logout/doi path. Khong co global/disk cache media rieng tu moi.
- Van an media trong luc revalidate va chi hien sau ACK moi. Moi GET binary van
  qua Spring JWT/quyen hien tai, no-store; video Range va buffer Spring giu cu.

## 4. File

| Loai | File |
|---|---|
| Moi | lib/features/posts/widgets/post_menu_actions.dart |
| Moi | lib/features/posts/widgets/content_mode_selector.dart |
| Sua | lib/features/home/screens/home_screen.dart |
| Sua | lib/features/profile/screens/profile_post_feed_screen.dart |
| Sua | lib/features/posts/screens/create_post_screen.dart |
| Sua | lib/features/posts/widgets/protected_post_media.dart |
| Sua | lib/features/moments/widgets/moments_strip.dart |
| Sua | lib/features/moments/screens/moment_camera_screen.dart |
| Test moi | test/post_ownership_menu_test.dart |
| Test moi | test/content_mode_selector_test.dart |

Docs: file nay, pointer trong POST_HOME_FEED_P2.md va CODEX_INDEX.md.
Khong thay dependency, .env, native config, Auth, Trip, Map, Cloudinary hay AI.

## 5. Kiem thu

- Flutter focused regression: 63 PASS (47 cu + 12 menu/performance + 4 creation).
  Hai actor/author dao chieu tren Home/viewer; stale authorId, duplicate menu,
  audience ACK, cancel/delete fail/ACK, logout/session guard; Like/Save/paging,
  Profile pixel comparison, privacy/Auth/notification UI va trim/upload tests cu.
- Performance widget proof: doi huong scroll khong thay widget/state media hay
  tai lai anh; keyed refresh giu state; ResizeImage dung physical width; logout
  go tile va evict resized image key. Day khong phai benchmark FPS may that.
- Creation widget proof: 390x844 va 360x640 khong overflow; cham/vuot doi mode,
  giu che do chon nhieu va khong query lai album; doi mode khi discovery dang
  pending khong tao hidden camera. Home + vao Post truoc.
- Test host Windows khong ho tro AssetEntity.file that cua Android, camera test
  dung platform-channel mock. Chup/trim/chon file/publish that can test may that.
- Analyze: 0 errors, 15 warning cu, 265 info; khong warning moi.
- Android debug APK build PASS. Chua tu cai/restart app tren dien thoai.
- Khong sua backend/DTO/API nen khong chay lai Maven trong hotfix nay.
- Chi SELECT DB truoc/sau: 7 Post / 12 media, Flyway moi nhat V21 success.
  Khong tao/xoa Post/media that, khong goi upload/xoa Cloudinary asset.
- Log nam trong ignored backups/p2-pre-v21/hotfix-*.log. Khong dua token/secret
  vao bao cao. Khong tao container/API test moi.

## 6. Nghiem thu Android

1. Run lai Flutter bang cau hinh hien tai. A mo bai cua A tren Home va viewer:
   co doi quyen/Xoa; khong Bao cao. B xem cung bai: khong co thao tac owner.
2. A doi audience; chuyen B kiem tra quyen moi va media. A thu Huy xoa, mat mang
   khi xoa, roi xoa thanh cong tren mot bai test; Home/Profile/viewer dong bo.
3. Dau + tren Home mo Bai viet. Chon media, vuot sang Khoanh khac de chup truc
   tiep, vuot ve kiem tra draft; flash/dao cam/upload van theo luong cu.
4. Cuon Feed nhanh/cham, dao huong, Like/Save va nap trang tiep. Danh gia do muot
   tren ket noi/may that; cold download va video van co chi phi, khong cam ket
   FPS hay phan tram tang toc khi chua do tren thiet bi.

Dung tai day, khong trien khai P3/P4.

## Home Single-Video Clipping Follow-up

- User reported video on Home painting over adjacent controls, while the same
  Post in Profile stayed inside its media frame.
- Cause: the single-media fast path removed PageView and therefore its viewport
  clipping. BoxFit.cover still paints beyond the layout bounds for a non-square
  video; Stack's default clip is not a guarantee against this paint-only overflow.
- Home now clips its square media viewport explicitly with ClipRect/hardEdge.
  This keeps the fast path, square dimensions, cover fit, player controls, Like,
  paging and navigation. No rounded border, redesign or offscreen saveLayer.
- Only Home rendering, test/post_ownership_menu_test.dart and this note change.
  Shared protected player, Profile, backend/API/privacy and database are unchanged.
- Regression tests check the real Home video viewport and portrait/landscape
  cover painting pixels inside/outside the configured clip. This is a rendering
  test, not a claim of playing native video on the user's physical phone.
- Verification: 28 targeted Flutter tests PASS (Feed, Profile and ownership/media
  regressions); analyze 0 errors / 15 existing warnings. No APK install, backend
  restart or database write was performed for this follow-up. Hot Restart the
  current Flutter run and verify the original first-video case on the phone.
