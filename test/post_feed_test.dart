import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomate/core/network/api_exception.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/features/posts/data/post_repository.dart';
import 'package:gomate/features/posts/data/post_feed_controller.dart';
import 'package:gomate/features/posts/data/post_engagement_controller.dart';
import 'package:gomate/features/home/screens/home_screen.dart';
import 'package:gomate/features/profile/screens/profile_post_feed_screen.dart';
import 'profile_posts_test.dart' as fixture;

class _Repo extends PostRepository {
  _Repo(AuthService a) : super(auth: a);
  final calls = <String>[];
  bool fail = false;
  bool liked = false, saved = false;
  Completer<Map<String, dynamic>>? heldPage, heldAction;
  List<Map<String, dynamic>> first = [fixture.post(1), fixture.post(2)];
  @override
  Future<Map<String, dynamic>> feed({String? cursor}) async {
    calls.add('feed:$cursor');
    if (fail) throw const ApiException(503, 'FAILED', 'Failed');
    if (heldPage != null) return heldPage!.future;
    return {
      'items': cursor == null ? first : [fixture.post(2), fixture.post(3)],
      'nextCursor': cursor == null ? 'next' : null,
    };
  }

  @override
  Future<Map<String, dynamic>> detail(int id) async => {
    ...fixture.post(id),
    'likeCount': liked ? 1 : 0,
    'likedByMe': liked,
    'savedByMe': saved,
  };
  @override
  Future<Map<String, dynamic>> engagement(
    int id,
    String kind,
    bool value,
  ) async {
    calls.add('$kind:$id:$value');
    if (fail) throw const ApiException(503, 'FAILED', 'Failed');
    if (heldAction != null) return heldAction!.future;
    if (kind == 'like') {
      liked = value;
    } else {
      saved = value;
    }
    return {
      'postId': id,
      'likeCount': liked ? 1 : 0,
      'likedByMe': liked,
      'savedByMe': saved,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'feed pages dedupe, revoke on failed refresh, retry and respect session',
    () async {
      final a = await fixture.auth();
      final r = _Repo(a);
      final c = PostFeedController(r);
      await c.refresh();
      await c.load();
      expect(c.items.map((p) => p['id']), [1, 2, 3]);
      r.heldPage = Completer();
      final pending = c.refresh();
      expect(c.revalidating, true);
      expect(c.items.length, 3);
      r.heldPage!.complete({
        'items': [fixture.post(2)],
        'nextCursor': null,
      });
      await pending;
      expect(c.items.map((p) => p['id']), [2]);
      r.heldPage = null;
      r.fail = true;
      await c.refresh();
      expect(c.items, isEmpty);
      expect(c.error, isNotNull);
      r.fail = false;
      await c.refresh();
      r.heldPage = Completer();
      final stale = c.refresh();
      await a.clearLocal();
      expect(c.items, isEmpty);
      r.heldPage!.complete({
        'items': [fixture.post(1)],
        'nextCursor': null,
      });
      await stale;
      expect(c.items, isEmpty);
      c.dispose();
      a.dispose();
    },
  );
  test(
    'fresh snapshots keep backend relationship order and paging never resorts it',
    () async {
      final a = await fixture.auth();
      final r = _Repo(a)
        ..first = [fixture.post(30), fixture.post(10), fixture.post(20)];
      final c = PostFeedController(r);

      await c.refresh();
      expect(c.items.map((post) => post['id']), [30, 10, 20]);

      r.first = [fixture.post(10), fixture.post(30), fixture.post(20)];
      await c.refresh();
      expect(c.items.map((post) => post['id']), [10, 30, 20]);
      expect(r.calls.where((call) => call == 'feed:null').length, 2);

      await c.load();
      expect(r.calls.last, 'feed:next');
      expect(c.items.map((post) => post['id']), [10, 30, 20, 2, 3]);

      c.dispose();
      a.dispose();
    },
  );
  test(
    'paging failure keeps authorized pages and retry; mutations refresh current truth',
    () async {
      final a = await fixture.auth();
      final r = _Repo(a);
      final c = PostFeedController(r);
      await c.refresh();
      r.fail = true;
      await c.load();
      expect(c.items.length, 2);
      expect(c.error, isNotNull);
      r.fail = false;
      await c.load();
      expect(c.items.length, 3);
      r.first = [];
      PostChanges.changed();
      await Future<void>.delayed(Duration.zero);
      expect(c.items, isEmpty);
      expect(c.error, isNull);
      c.dispose();
      a.dispose();
    },
  );
  test(
    'optimistic like/save, double-like idempotency, failure rollback and reload',
    () async {
      final a = await fixture.auth();
      final r = _Repo(a);
      final c = PostEngagementController(r, 1, {});
      final pending = c.like(true);
      expect(c.liked, true);
      expect(c.likeCount, 1);
      expect(await pending, true);
      expect(await c.like(true), true);
      expect(r.calls.where((s) => s.startsWith('like')).length, 1);
      expect(await c.save(true), true);
      expect(c.saved, true);
      final reloaded = PostEngagementController(r, 1, await r.detail(1));
      expect(reloaded.liked, true);
      expect(reloaded.saved, true);
      r.fail = true;
      expect(await c.like(false), false);
      expect(c.liked, true);
      expect(c.likeCount, 1);
      expect(await c.save(false), false);
      expect(c.saved, true);
      r.fail = false;
      expect(await c.like(false), true);
      expect(c.likeCount, 0);
      expect(await c.save(false), true);
      c.dispose();
      reloaded.dispose();
      a.dispose();
    },
  );
  test(
    'rapid action is guarded and stale ACK cannot restore logged-out state',
    () async {
      final a = await fixture.auth();
      final r = _Repo(a);
      final c = PostEngagementController(r, 1, {});
      r.heldAction = Completer();
      final pending = c.like(true);
      expect(await c.like(false), false);
      expect(r.calls.length, 1);
      await a.clearLocal();
      expect(c.liked, false);
      expect(c.likeCount, 0);
      r.heldAction!.complete({
        'postId': 1,
        'likedByMe': true,
        'savedByMe': true,
        'likeCount': 1,
      });
      expect(await pending, false);
      expect(c.liked, false);
      expect(c.saved, false);
      expect(c.likeCount, 0);
      c.dispose();
      a.dispose();
    },
  );
  testWidgets(
    'Home uses protected real card, ACK interactions, existing viewer and no demo fallback',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final a = (await tester.runAsync(() => fixture.auth()))!;
      final r = _Repo(a);
      r.first = [fixture.post(1)];
      await tester.pumpWidget(MaterialApp(home: HomeScreen(postRepository: r)));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await fixture.settleHomeMedia(tester);
      expect(find.text('trip'), findsOneWidget);
      expect(find.textContaining('CaptionCaption'), findsNothing);
      final heart = find.byIcon(LucideIcons.heart).first;
      await tester.ensureVisible(heart);
      await tester.tap(heart);
      await fixture.settleHomeMedia(tester);
      expect(r.calls, contains('like:1:true'));
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(postRepository: r, active: false)),
      );
      await fixture.settleHomeMedia(tester);
      expect(find.text('1'), findsOneWidget);
      final bookmark = find.byIcon(LucideIcons.bookmark).first;
      await tester.tap(bookmark);
      await fixture.settleHomeMedia(tester);
      expect(r.calls, contains('save:1:true'));
      expect(find.text('Đã lưu vào bộ sưu tập'), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
      final media = find.byType(AspectRatio).first;
      await tester.ensureVisible(media);
      await tester.tap(media);
      await fixture.settleHomeMedia(tester);
      expect(find.byType(GoMateProfilePostFeedScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      a.dispose();
    },
  );
  testWidgets('Home API failure exposes retry without rendering demo Posts', (
    tester,
  ) async {
    final a = (await tester.runAsync(() => fixture.auth()))!;
    final r = _Repo(a);
    r.fail = true;
    await tester.pumpWidget(MaterialApp(home: HomeScreen(postRepository: r)));
    await fixture.settleHomeMedia(tester);
    expect(find.textContaining('CaptionCaption'), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1500));
    await fixture.settleHomeMedia(tester);
    expect(find.text('Không tải được bài viết. Thử lại'), findsOneWidget);
    r.fail = false;
    r.first = [];
    await tester.tap(find.text('Không tải được bài viết. Thử lại'));
    await fixture.settleHomeMedia(tester);
    expect(r.calls.where((s) => s == 'feed:null').length, 2);
    expect(find.text('Tải thêm bài viết'), findsOneWidget);
    await tester.tap(find.text('Tải thêm bài viết'));
    await fixture.settleHomeMedia(tester);
    expect(r.calls, contains('feed:next'));
    await tester.pumpWidget(const SizedBox());
    a.dispose();
  });
}
