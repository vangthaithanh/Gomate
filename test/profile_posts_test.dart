import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/session_store.dart';
import 'package:gomate/core/network/api_exception.dart';
import 'package:gomate/features/posts/data/post_repository.dart';
import 'package:gomate/features/posts/data/profile_posts_controller.dart';
import 'package:gomate/features/posts/widgets/protected_post_media.dart';
import 'package:gomate/features/profile/screens/profile_post_feed_screen.dart';
import 'package:gomate/features/profile/widgets/profile_ui_widgets.dart';

class _Store implements SessionStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}

// Raw, application-owned decoding uses native async steps outside fake time.
Future<void> settleHomeMedia(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pumpAndSettle();
}

Map<String, dynamic> post(int id) => {
  'id': id,
  'authorId': 'owner',
  'authorName': 'GoMate',
  'caption': 'A trip',
  'audience': 'EVERYONE',
  'pinned': false,
  'hashtags': [],
  'createdAt': '2026-10-22T00:00:00Z',
  'taggedUserIds': [],
  'media': [
    {
      'id': '00000000-0000-4000-8000-000000000001',
      'kind': 'IMAGE',
      'url': '/posts/$id/media/00000000-0000-4000-8000-000000000001',
      'thumbnailUrl':
          '/posts/$id/media/00000000-0000-4000-8000-000000000001/thumbnail',
    },
  ],
};
Future<AuthService> auth({
  String id = 'owner',
  VoidCallback? onMedia,
  Future<void> Function()? mediaGate,
  int Function()? mediaStatus,
  String Function()? accountId,
  String Function()? accessToken,
}) async {
  final bytes = (await rootBundle.load(
    'assets/images/checkin.jpg',
  )).buffer.asUint8List();
  final value = {'id': id, 'isPrivate': false, 'onboardingCompleted': true};
  final service = AuthService(
    store: _Store(),
    baseUrl: 'http://localhost/api/v1',
    client: MockClient((request) async {
      if (accountId != null) value['id'] = accountId();
      if (request.url.path.contains('/media/')) {
        onMedia?.call();
        if (mediaGate != null) await mediaGate();
        return http.Response.bytes(bytes, mediaStatus?.call() ?? 200);
      }
      return http.Response(
        jsonEncode(
          request.url.path.endsWith('/login')
              ? {
                  'accessToken': accessToken?.call() ?? 'access',
                  'refreshToken': 'refresh',
                  'user': value,
                }
              : value,
        ),
        200,
      );
    }),
  );
  await service.login(
    email: 'owner@example.com',
    password: 'TestPass123!',
    remember: false,
  );
  return service;
}

class _Repo extends PostRepository {
  _Repo(AuthService auth) : super(auth: auth);
  bool fail = false;
  Completer<Map<String, dynamic>>? hold;
  final mutations = <String>[];
  final reads = <int>[];
  String audienceValue = 'EVERYONE';
  @override
  Future<Map<String, dynamic>> profile(String author, {String? cursor}) async {
    if (fail) throw const ApiException(503, 'FAILED', 'Failed');
    if (hold != null) return hold!.future;
    return {
      'items': cursor == null ? [post(1), post(2)] : [post(2), post(3)],
      'nextCursor': cursor == null ? 'next' : null,
    };
  }

  @override
  Future<Map<String, dynamic>> detail(int id) async {
    reads.add(id);
    return {...post(id), 'audience': audienceValue};
  }

  @override
  Future<Map<String, dynamic>> pin(int id, bool value) async {
    mutations.add('pin:$id:$value');
    throw const ApiException(
      422,
      'POST_PIN_LIMIT',
      'Chỉ được ghim tối đa 3 bài viết.',
    );
  }

  @override
  Future<void> delete(int id) async {
    mutations.add('delete:$id');
  }

  @override
  Future<Map<String, dynamic>> audience(int id, String audience) async {
    audienceValue = audience;
    mutations.add('audience:$id:$audience');
    return {...post(id), 'audience': audience};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('pages dedupe, hide during revalidation and clear on logout', () async {
    final a = await auth();
    final r = _Repo(a);
    final c = ProfilePostsController(() => 'owner', repository: r);
    await c.refresh();
    await c.load();
    expect(c.items.map((p) => p.id), ['1', '2', '3']);
    expect(c.cursor, null);
    r.hold = Completer();
    final pending = c.refresh();
    expect(c.items.length, 3);
    expect(c.revalidating, true);
    r.hold!.complete({'items': [], 'nextCursor': null});
    await pending;
    expect(c.items, isEmpty);
    expect(c.revalidating, false);
    await a.clearLocal();
    expect(c.items, isEmpty);
    c.dispose();
    a.dispose();
  });
  test(
    'failed revalidation drops retained items; stale ACK cannot restore logout',
    () async {
      final a = await auth();
      final r = _Repo(a);
      final c = ProfilePostsController(() => 'owner', repository: r);
      await c.refresh();
      r.fail = true;
      await c.refresh();
      expect(c.items, isEmpty);
      expect(c.error, isNotNull);
      r.fail = false;
      await c.refresh();
      r.hold = Completer();
      final pending = c.refresh();
      await a.clearLocal();
      expect(c.items, isEmpty);
      r.hold!.complete({
        'items': [post(1)],
        'nextCursor': null,
      });
      await pending;
      expect(c.items, isEmpty);
      c.dispose();
      a.dispose();
    },
  );
  testWidgets(
    'mounted thumbnails stay hidden until fresh ACK without downloading again',
    (tester) async {
      int downloads = 0;
      final a = (await tester.runAsync(
        () => auth(onMedia: () => downloads++),
      ))!;
      final r = _Repo(a);
      final c = ProfilePostsController(() => 'owner', repository: r);
      await c.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: c,
            builder: (context, _) => CustomScrollView(
              slivers: [
                SliverVisibility(
                  visible: !c.revalidating,
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: true,
                  sliver: SliverGrid.builder(
                    itemCount: c.items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                        ),
                    itemBuilder: (context, index) => ProtectedPostMedia(
                      key: ValueKey(c.items[index].id),
                      auth: a,
                      path:
                          (c.items[index].server!['media'] as List)
                                  .first['thumbnailUrl']
                              as String,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(downloads, 2);
      final mounted = tester
          .stateList(find.byType(ProtectedPostMedia))
          .toList();
      r.hold = Completer();
      final pending = c.refresh();
      await tester.pump();
      expect(
        tester.widget<SliverVisibility>(find.byType(SliverVisibility)).visible,
        false,
      );
      expect(
        tester.stateList(find.byType(ProtectedPostMedia)),
        orderedEquals(mounted),
      );
      r.hold!.complete({
        'items': [post(1), post(2)],
        'nextCursor': null,
      });
      await pending;
      await tester.pumpAndSettle();
      expect(
        tester.widget<SliverVisibility>(find.byType(SliverVisibility)).visible,
        true,
      );
      expect(
        tester.stateList(find.byType(ProtectedPostMedia)),
        orderedEquals(mounted),
      );
      expect(downloads, 2);
      r.hold = null;
      r.fail = true;
      await c.refresh();
      await tester.pumpAndSettle();
      expect(find.byType(ProtectedPostMedia), findsNothing);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      a.dispose();
    },
  );
  test('failed paging keeps loaded items and can retry', () async {
    final a = await auth();
    final r = _Repo(a);
    final c = ProfilePostsController(() => 'owner', repository: r);
    await c.refresh();
    r.fail = true;
    await c.load();
    expect(c.error, isNotNull);
    expect(c.items.length, 2);
    r.fail = false;
    await c.load();
    expect(c.items.length, 3);
    expect(c.error, null);
    c.dispose();
    a.dispose();
  });
  testWidgets('selected-first viewer keeps approved square card geometry', (
    tester,
  ) async {
    final a = await tester.runAsync(() => auth());
    final r = _Repo(a!);
    await tester.pumpWidget(
      MaterialApp(
        home: GoMateProfilePostFeedScreen(
          posts: [1, 2, 3, 4].map((i) => profilePost(post(i))).toList(),
          initialIndex: 1,
          remote: true,
          repository: r,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(r.reads.first, 2);
    expect(r.reads.toSet().length, r.reads.length);
    expect(
      tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .every((w) => w.aspectRatio == 1),
      true,
    );
    expect(find.text('GoMate'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    a.dispose();
  });
  testWidgets('owner menu pin limit and confirmed delete use real callbacks', (
    tester,
  ) async {
    final a = await tester.runAsync(() => auth());
    final r = _Repo(a!);
    await tester.pumpWidget(
      MaterialApp(
        home: GoMateProfilePostFeedScreen(
          posts: [profilePost(post(1))],
          remote: true,
          repository: r,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IconButton).last);
    await tester.pumpAndSettle();
    expect(find.text('Ghim bài viết'), findsOneWidget);
    await tester.tap(find.text('Ghim bài viết'));
    await tester.pumpAndSettle();
    expect(r.mutations, ['pin:1:true']);
    expect(find.textContaining('Chỉ được ghim tối đa 3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.byType(IconButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chỉnh sửa quyền riêng tư'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chỉ mình tôi'));
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(r.mutations.last, 'audience:1:ONLY_ME');
    expect(find.text('Đã đổi quyền riêng tư'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.byType(IconButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá'));
    await tester.pumpAndSettle();
    expect(r.mutations.length, 2);
    await tester.tap(find.text('Xác nhận xoá'));
    await tester.pumpAndSettle();
    expect(r.mutations.last, 'delete:1');
    expect(find.text('Đã xoá bài viết'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    a.dispose();
  });
  testWidgets('outsider does not get owner management', (tester) async {
    final a = await tester.runAsync(() => auth(id: 'viewer'));
    final r = _Repo(a!);
    await tester.pumpWidget(
      MaterialApp(
        home: GoMateProfilePostFeedScreen(
          posts: [profilePost(post(1))],
          remote: true,
          repository: r,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IconButton).last);
    await tester.pumpAndSettle();
    expect(find.text('Ghim bài viết'), findsNothing);
    expect(find.text('Chỉnh sửa quyền riêng tư'), findsNothing);
    expect(find.text('Xoá'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    a.dispose();
  });
  testWidgets('real card pixels match the existing GoMate card form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final a = await tester.runAsync(() => auth());
    final r = _Repo(a!);
    final key = GlobalKey();
    Future<List<int>> render(bool real) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: GoMateProfilePostFeedScreen(
              posts: real
                  ? [profilePost(post(1))]
                  : [
                      const GoMateProfilePostPreview(
                        id: '1',
                        authorId: 'owner',
                        authorName: 'GoMate',
                        caption: 'A trip',
                        media: ['assets/images/checkin.jpg'],
                      ),
                    ],
              remote: real,
              repository: r,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = await tester.runAsync(
        () => (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 1),
      );
      final data = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      image!.dispose();
      return data!.buffer.asUint8List();
    }

    final old = await render(false);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    final current = await render(true);
    expect(current, old);
    await tester.pumpWidget(const SizedBox());
    a.dispose();
  });
}
