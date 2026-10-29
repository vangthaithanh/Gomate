import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomate/core/network/api_exception.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/features/home/screens/home_screen.dart';
import 'package:gomate/features/posts/data/post_repository.dart';
import 'package:gomate/features/posts/data/profile_posts_controller.dart';
import 'package:gomate/features/posts/widgets/post_menu_actions.dart';
import 'package:gomate/features/posts/widgets/protected_post_media.dart';
import 'package:gomate/features/profile/screens/profile_post_feed_screen.dart';
import 'profile_posts_test.dart' as fixture;

class _Repo extends PostRepository {
  _Repo(AuthService auth) : super(auth: auth);
  String owner = 'owner';
  String audienceValue = 'EVERYONE';
  bool video = false;
  final removed = <int>{};
  final mutations = <String>[];
  int? error;
  Completer<void>? deletion;
  Completer<Map<String, dynamic>>? pendingDetail;
  List<int> ids = [1, 2, 3];
  Map<String, dynamic> row(int id) => {
    ...fixture.post(id),
    'authorId': owner,
    'audience': audienceValue,
    if (video)
      'media': [
        for (final media in fixture.post(id)['media'] as List)
          {...media as Map<String, dynamic>, 'kind': 'VIDEO'},
      ],
  };
  @override
  Future<Map<String, dynamic>> feed({String? cursor}) async => {
    'items': ids.where((id) => !removed.contains(id)).map(row).toList(),
    'nextCursor': null,
  };
  @override
  Future<Map<String, dynamic>> detail(int id) async {
    if (pendingDetail != null) return pendingDetail!.future;
    if (error == 404 || removed.contains(id)) {
      throw const ApiException(404, 'NOT_FOUND', 'Unavailable');
    }
    return row(id);
  }

  @override
  Future<Map<String, dynamic>> audience(int id, String audience) async {
    if (error != null) throw ApiException(error!, 'FAILED', 'Failed');
    audienceValue = audience;
    mutations.add('audience:$id:$audience');
    PostChanges.changed();
    return row(id);
  }

  @override
  Future<void> delete(int id) async {
    mutations.add('delete:$id');
    if (error != null) throw ApiException(error!, 'FAILED', 'Failed');
    await deletion?.future;
    removed.add(id);
    PostChanges.changed();
  }
}

Future<void> _home(WidgetTester t, _Repo r) async {
  t.view.physicalSize = const Size(400, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(home: HomeScreen(postRepository: r)));
  await fixture.settleHomeMedia(t);
}

Future<void> _more(WidgetTester t) async {
  final list = t.widget<ListView>(find.byType(ListView).first);
  list.controller!.jumpTo(0);
  await fixture.settleHomeMedia(t);
  final icon = find.byIcon(LucideIcons.ellipsis_vertical).first;
  await t.tap(icon);
  await fixture.settleHomeMedia(t);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final (actor, author) in [
    ('owner', 'owner'),
    ('viewer', 'owner'),
    ('owner', 'viewer'),
    ('viewer', 'viewer'),
  ]) {
    for (final home in [true, false]) {
      testWidgets(
        'actor $actor on author $author has correct ${home ? 'Home' : 'viewer'} menu',
        (t) async {
          final a = (await t.runAsync(() => fixture.auth(id: actor)))!;
          final r = _Repo(a)..owner = author;
          if (home) {
            await _home(t, r);
          } else {
            await t.pumpWidget(
              MaterialApp(
                home: GoMateProfilePostFeedScreen(
                  posts: [profilePost(r.row(1))],
                  remote: true,
                  repository: r,
                ),
              ),
            );
            await fixture.settleHomeMedia(t);
          }
          if (home) {
            await _more(t);
          } else {
            await t.tap(find.byType(IconButton).last);
            await fixture.settleHomeMedia(t);
          }
          final owned = actor == author;
          expect(
            find.text('Chỉnh sửa quyền riêng tư'),
            owned ? findsOneWidget : findsNothing,
          );
          expect(find.text('Xoá'), owned ? findsOneWidget : findsNothing);
          expect(find.text('Báo cáo'), owned ? findsNothing : findsOneWidget);
          if (!owned) {
            await t.tap(find.text('Báo cáo'));
            await fixture.settleHomeMedia(t);
            expect(find.text('Tại sao bạn lại báo cáo?'), findsOneWidget);
            expect(r.mutations, isEmpty);
          }
          await t.pumpWidget(const SizedBox());
          a.dispose();
        },
      );
    }
  }

  testWidgets(
    'Home audience ACK refreshes, cancel/failure do not remove; delete waits for ACK',
    (t) async {
      final a = (await t.runAsync(() => fixture.auth()))!;
      final r = _Repo(a);
      await _home(t, r);
      await _more(t);
      await t.tap(find.text('Chỉnh sửa quyền riêng tư'));
      await fixture.settleHomeMedia(t);
      await t.tap(find.text('Chỉ mình tôi'));
      await t.tap(find.text('Lưu'));
      await fixture.settleHomeMedia(t);
      expect(r.mutations, ['audience:1:ONLY_ME']);
      await t.pump(const Duration(seconds: 4));
      await _more(t);
      await t.tap(find.text('Xoá'));
      await fixture.settleHomeMedia(t);
      await t.tap(find.text('Huỷ'));
      await fixture.settleHomeMedia(t);
      expect(r.mutations.length, 1);
      r.error = 503;
      await _more(t);
      await t.tap(find.text('Xoá'));
      await fixture.settleHomeMedia(t);
      await t.tap(find.text('Xác nhận xoá'));
      await fixture.settleHomeMedia(t);
      expect(r.removed, isEmpty);
      expect(
        find.textContaining('Không cập nhật được bài viết'),
        findsOneWidget,
      );
      await t.pump(const Duration(seconds: 4));
      r.error = null;
      r.deletion = Completer();
      await _more(t);
      await t.tap(find.text('Xoá'));
      await fixture.settleHomeMedia(t);
      await t.tap(find.text('Xác nhận xoá'));
      await fixture.settleHomeMedia(t);
      expect(r.removed, isEmpty);
      r.deletion!.complete();
      await fixture.settleHomeMedia(t);
      expect(r.removed, {1});
      expect(find.byKey(const ValueKey('owner:1')), findsNothing);
      expect(find.byKey(const ValueKey('owner:2')), findsWidgets);
      await t.pumpWidget(const SizedBox());
      a.dispose();
    },
  );

  testWidgets(
    'one shared menu guards duplicate taps, denied detail and changed session',
    (t) async {
      final a = (await t.runAsync(() => fixture.auth()))!;
      final r = _Repo(a);
      final menu = PostMenuActions(r);
      int denied = 0;
      late BuildContext host;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              host = context;
              return const Scaffold();
            },
          ),
        ),
      );
      r.pendingDetail = Completer();
      final first = menu.open(host, 1);
      await menu.open(host, 1);
      r.pendingDetail!.complete(r.row(1));
      await fixture.settleHomeMedia(t);
      expect(find.text('Xoá'), findsOneWidget);
      await a.clearLocal();
      await fixture.settleHomeMedia(t);
      await first;
      expect(find.text('Xoá'), findsNothing);
      expect(r.mutations, isEmpty);
      await a.login(
        email: 'a@test.com',
        password: 'TestPass123!',
        remember: false,
      );
      r.pendingDetail = null;
      r.error = 404;
      await menu.open(host, 1, onUnavailable: () => denied++);
      await fixture.settleHomeMedia(t);
      expect(denied, 1);
      expect(find.text('Xoá'), findsNothing);
      await t.pumpWidget(const SizedBox());
      a.dispose();
    },
  );

  testWidgets('fresh authorId overrides stale feed metadata', (t) async {
    final a = (await t.runAsync(() => fixture.auth()))!;
    final r = _Repo(a);
    await _home(t, r);
    r.owner = 'other';
    await _more(t);
    expect(find.text('Báo cáo'), findsOneWidget);
    expect(find.text('Xoá'), findsNothing);
    await t.pumpWidget(const SizedBox());
    a.dispose();
  });

  testWidgets(
    'header direction changes do not rebuild feed media; keyed refresh retains tile',
    (t) async {
      int downloads = 0;
      final a = (await t.runAsync(
        () => fixture.auth(onMedia: () => downloads++),
      ))!;
      final r = _Repo(a);
      await _home(t, r);
      final media = find.byType(ProtectedPostMedia).first;
      final state = t.state(media);
      final widget = t.widget(media);
      final count = downloads;
      final scroll = find.byType(ListView).first;
      final context = t.element(scroll);
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 3000,
        pixels: 100,
        viewportDimension: 1100,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      );
      for (final direction in [
        ScrollDirection.reverse,
        ScrollDirection.forward,
      ]) {
        UserScrollNotification(
          metrics: metrics,
          context: context,
          direction: direction,
        ).dispatch(context);
        await fixture.settleHomeMedia(t);
        expect(identical(t.widget(media), widget), true);
        expect(identical(t.state(media), state), true);
      }
      expect(downloads, count);
      final image = t
          .widget<RawImage>(
            find.descendant(of: media, matching: find.byType(RawImage)).first,
          )
          .image!;
      expect(image.width, lessThanOrEqualTo(600));
      expect(image.width * image.height, lessThanOrEqualTo(1002000));
      // Insert before the mounted card and move it across rail indices.
      r.ids = [9, 1, 2, 3];
      PostChanges.changed();
      await fixture.settleHomeMedia(t);
      expect(t.stateList(find.byType(ProtectedPostMedia)), contains(state));
      await a.clearLocal();
      await fixture.settleHomeMedia(t);
      expect(find.byType(ProtectedPostMedia), findsNothing);
      expect(image.debugDisposed, true);
      await t.pumpWidget(const SizedBox());
      a.dispose();
    },
  );

  for (final videoSize in [const Size(900, 1600), const Size(1600, 900)]) {
    testWidgets(
      'Home single video keeps cover painting inside its square: $videoSize',
      (t) async {
        final a = (await t.runAsync(() => fixture.auth()))!;
        final r = _Repo(a)..video = true;
        await _home(t, r);
        final media = find.byType(ProtectedPostMedia).first;
        expect(t.widget<ProtectedPostMedia>(media).video, true);
        final frame = find
            .ancestor(of: media, matching: find.byType(AspectRatio))
            .first;
        expect(t.widget<AspectRatio>(frame).aspectRatio, 1);
        // No horizontal pager is needed, but its old viewport clip is mandatory.
        expect(
          find.descendant(of: frame, matching: find.byType(PageView)),
          findsNothing,
        );
        final clipping = find
            .descendant(of: frame, matching: find.byType(ClipRect))
            .first;
        final viewport = t.widget<ClipRect>(clipping);
        expect(viewport.clipBehavior, Clip.hardEdge);
        expect(t.getRect(clipping), t.getRect(frame));

        // Paint a portrait/landscape video-sized surface with the same cover fit.
        // Native decoder playback is not simulated by this raster regression.
        final key = GlobalKey();
        await t.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: Colors.white,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 100, top: 100),
                    child: SizedBox.square(
                      dimension: 200,
                      child: ClipRect(
                        clipBehavior: viewport.clipBehavior,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: videoSize.width,
                            height: videoSize.height,
                            child: const ColoredBox(color: Color(0xFFFF0000)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await fixture.settleHomeMedia(t);
        final image = (await t.runAsync(
          () =>
              (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
                  .toImage(),
        ))!;
        final bytes = (await t.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        List<int> pixel(int x, int y) =>
            bytes.buffer.asUint8List((y * image.width + x) * 4, 4);
        expect(pixel(110, 110), [255, 0, 0, 255]);
        for (final (x, y) in [(110, 90), (110, 310), (90, 110), (310, 110)]) {
          expect(pixel(x, y), [255, 255, 255, 255]);
        }
        image.dispose();
        await t.pumpWidget(const SizedBox());
        a.dispose();
      },
    );
  }
}
