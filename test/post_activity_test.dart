import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/session_store.dart';
import 'package:gomate/features/posts/data/post_repository.dart';
import 'package:gomate/features/posts/data/post_activity_controller.dart';
import 'package:gomate/features/posts/data/post_engagement_controller.dart';
import 'package:gomate/features/posts/data/post_feed_controller.dart';
import 'package:gomate/features/posts/data/profile_posts_controller.dart';
import 'package:gomate/features/posts/widgets/protected_post_media.dart';
import 'package:gomate/features/home/widgets/comment_sheet_content.dart';
import 'package:gomate/features/home/screens/home_screen.dart';
import 'package:gomate/features/profile/screens/settings_collection_screen.dart';
import 'package:gomate/features/profile/screens/profile_post_feed_screen.dart';
import 'profile_posts_test.dart' as fixture;

class _Store implements SessionStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> clear() async {}
  @override
  Future<void> write(String value) async {}
}

class _Harness {
  late final AuthService auth;
  late final PostRepository repository;
  String actor = 'a';
  final calls = <String>[];
  final likes = <int>{1, 2}, saves = <int>{1};
  final comments = <Map<String, dynamic>>[
    {
      'commentId': 12,
      'postId': 1,
      'parentCommentId': 99,
      'body': 'Own reply',
      'parentBody': 'Foreign parent',
    },
    {'commentId': 11, 'postId': 1, 'parentCommentId': null, 'body': 'Own root'},
  ];
  bool failPage = false;
  int? failRemoval;
  Completer<http.Response>? holdPage;
  Map<String, dynamic> post(int id) => {
    ...fixture.post(id),
    'likedByMe': likes.contains(id),
    'savedByMe': saves.contains(id),
    'likeCount': likes.contains(id) ? 1 : 0,
    'commentCount': comments.length,
  };
  Map<String, dynamic> item(int id, String time) => {
    'post': post(id),
    time: '2026-10-23T00:00:00Z',
  };
  static Future<_Harness> create() async {
    final h = _Harness();
    final image = (await rootBundle.load(
      'assets/images/checkin.jpg',
    )).buffer.asUint8List();
    h.auth = AuthService(
      store: _Store(),
      baseUrl: 'http://localhost/api/v1',
      client: MockClient((r) async {
        h.calls.add(
          '${r.method} ${r.url.path}${r.url.hasQuery ? '?${r.url.query}' : ''}',
        );
        http.Response ok(Object body) => http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
        if (r.url.path.endsWith('/login')) {
          return ok({
            'accessToken': 'access-${h.actor}',
            'refreshToken': 'refresh',
            'user': {'id': h.actor, 'isPrivate': false},
          });
        }
        if (r.url.path.contains('/media/')) {
          return http.Response.bytes(
            image,
            200,
            headers: {'content-type': 'image/jpeg'},
          );
        }
        if (r.url.path.startsWith('/api/v1/me/')) {
          if (h.holdPage != null) return h.holdPage!.future;
          if (h.failPage) {
            return http.Response(
              '{"error":{"code":"FAILED","message":"retry"}}',
              503,
            );
          }
          final name = r.url.path.split('/').last;
          final items = h.actor != 'a'
              ? <Object>[]
              : switch (name) {
                  'liked-posts' =>
                    h.likes.map((id) => h.item(id, 'likedAt')).toList(),
                  'saved-posts' =>
                    h.saves.map((id) => h.item(id, 'savedAt')).toList(),
                  'comments' =>
                    h.comments
                        .map(
                          (c) => {
                            ...c,
                            'post': h.post(c['postId'] as int),
                            'createdAt': '2026-10-23T00:00:00Z',
                            'authorName': 'Account A',
                          },
                        )
                        .toList(),
                  _ => <Object>[],
                };
          return ok({'items': items, 'nextCursor': null});
        }
        if (r.url.path.endsWith('/like') || r.url.path.endsWith('/save')) {
          final segments = r.url.pathSegments;
          final id = int.parse(segments[3]);
          if (id == h.failRemoval) {
            return http.Response(
              '{"error":{"code":"FAILED","message":"retry"}}',
              503,
            );
          }
          final values = segments.last == 'like' ? h.likes : h.saves;
          if (r.method == 'DELETE') {
            values.remove(id);
          } else {
            values.add(id);
          }
          return ok({
            'postId': id,
            'likedByMe': h.likes.contains(id),
            'savedByMe': h.saves.contains(id),
            'likeCount': h.likes.contains(id) ? 1 : 0,
            'commentCount': h.comments.length,
          });
        }
        if (r.method == 'DELETE' &&
            r.url.path.startsWith('/api/v1/comments/')) {
          final id = int.parse(r.url.pathSegments.last);
          h.comments.removeWhere(
            (c) => c['commentId'] == id || c['parentCommentId'] == id,
          );
          return http.Response('', 204);
        }
        if (r.url.path.endsWith('/comments')) {
          return ok({'items': [], 'nextCursor': null});
        }
        if (r.url.path.endsWith('/feed') ||
            r.url.path.endsWith('/posts') && r.url.path.contains('/users/')) {
          return ok({
            'items': [h.post(1), h.post(2)],
            'nextCursor': null,
          });
        }
        final id = int.tryParse(r.url.pathSegments.last);
        return ok(h.post(id ?? 1));
      }),
    );
    h.repository = PostRepository(auth: h.auth);
    await h.login();
    return h;
  }

  Future<void> login() => auth
      .login(email: 'a@example.com', password: 'TestPass123!', remember: false)
      .then((_) {});
}

class _PagedRepository extends PostRepository {
  _PagedRepository(AuthService auth) : super(auth: auth);
  bool fail = false;
  @override
  Future<Map<String, dynamic>> activity(String kind, {String? cursor}) async {
    if (fail) throw StateError('offline');
    return {
      'items': [
        for (final id in cursor == null ? [1, 2] : [2, 3])
          {'post': fixture.post(id), 'savedAt': '2026-10-23T00:00:00Z'},
      ],
      'nextCursor': cursor == null ? 'next' : null,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Settings unlike ACK retains mounted Home media without binary or Feed reload',
    (t) async {
      final h = await _Harness.create();
      await t.pumpWidget(
        MaterialApp(home: HomeScreen(postRepository: h.repository)),
      );
      await fixture.settleHomeMedia(t);
      final media = find.byType(ProtectedPostMedia).first;
      await t.ensureVisible(media);
      await fixture.settleHomeMedia(t);
      final state = t.state(media);
      final binaries = h.calls.where((call) => call.contains('/media/')).length;
      final feeds = h.calls.where((call) => call.contains('/feed')).length;
      expect(binaries, greaterThan(0));
      final activity = PostActivityController(
        PostActivityKind.likes,
        h.repository,
      );
      await activity.refresh();
      await activity.remove({'1'});
      await fixture.settleHomeMedia(t);
      expect(t.state(media), same(state));
      expect(
        h.calls.where((call) => call.contains('/media/')).length,
        binaries,
      );
      expect(h.calls.where((call) => call.contains('/feed')).length, feeds);
      activity.dispose();
      await t.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  test(
    'activity cursor appends/dedupes; paging error keeps rows and retries',
    () async {
      final h = await _Harness.create();
      final repo = _PagedRepository(h.auth);
      final controller = PostActivityController(PostActivityKind.saved, repo);
      await controller.refresh();
      expect(controller.items.map((item) => item.id), ['1', '2']);
      repo.fail = true;
      await controller.more();
      expect(controller.items.length, 2);
      expect(controller.cursor, 'next');
      expect(controller.error, isNotNull);
      repo.fail = false;
      await controller.more();
      expect(controller.items.map((item) => item.id), ['1', '2', '3']);
      expect(controller.cursor, isNull);
      controller.dispose();
      h.auth.dispose();
    },
  );
  test(
    'in-flight old page cannot restore an item after a removal ACK',
    () async {
      final h = await _Harness.create();
      final controller = PostActivityController(
        PostActivityKind.likes,
        h.repository,
      );
      await controller.refresh();
      final old = h.item(1, 'likedAt');
      final pending = Completer<http.Response>();
      h.holdPage = pending;
      final stale = controller.refresh();
      h.holdPage = null;
      await controller.remove({'1'});
      pending.complete(
        http.Response(
          jsonEncode({
            'items': [old],
            'nextCursor': null,
          }),
          200,
        ),
      );
      await stale;
      expect(controller.items.map((item) => item.id), ['2']);
      controller.dispose();
      h.auth.dispose();
    },
  );
  test(
    'three activity lists use server IDs, correct source and bound cursor encoding',
    () async {
      final h = await _Harness.create();
      for (final kind in PostActivityKind.values) {
        final controller = PostActivityController(kind, h.repository);
        await controller.refresh();
        expect(controller.items, isNotEmpty);
        expect(controller.items.first.postId, 1);
        expect(
          controller.items.first.commentId,
          kind == PostActivityKind.comments ? 12 : null,
        );
        controller.dispose();
      }
      await h.repository.activity('liked-posts', cursor: 'a+/=');
      expect(h.calls.last, contains('cursor=a%2B%2F%3D'));
      expect(h.calls.any((call) => call.contains('userId=')), false);
      h.auth.dispose();
    },
  );
  test(
    'Settings ACK updates Home/Profile/mounted cards without feed/detail reload',
    () async {
      final h = await _Harness.create();
      final feed = PostFeedController(h.repository);
      final profile = ProfilePostsController(
        () => 'owner',
        repository: h.repository,
      );
      final card = PostEngagementController(h.repository, 1, h.post(1));
      final likes = PostActivityController(
        PostActivityKind.likes,
        h.repository,
      );
      final saves = PostActivityController(
        PostActivityKind.saved,
        h.repository,
      );
      await feed.refresh();
      await profile.refresh();
      await likes.refresh();
      await saves.refresh();
      final feedReads = h.calls.where((c) => c.contains('/feed')).length;
      final profileReads = h.calls
          .where((c) => c.contains('/users/owner/posts'))
          .length;
      expect(await likes.remove({'1'}), isEmpty);
      expect(await saves.remove({'1'}), isEmpty);
      expect(likes.items.map((item) => item.postId), [2]);
      expect(saves.items, isEmpty);
      expect(card.liked, false);
      expect(card.saved, false);
      expect(card.likeCount, 0);
      expect(feed.items.first['likedByMe'], false);
      expect(feed.items.first['savedByMe'], false);
      expect(profile.items.first.server!['likedByMe'], false);
      expect(h.calls.where((c) => c.contains('/feed')).length, feedReads);
      expect(
        h.calls.where((c) => c.contains('/users/owner/posts')).length,
        profileReads,
      );
      expect(h.calls.where((c) => c == 'GET /api/v1/posts/1'), isEmpty);
      card.dispose();
      feed.dispose();
      profile.dispose();
      likes.dispose();
      saves.dispose();
      h.auth.dispose();
    },
  );
  test(
    'Home unlike/unsave ACK refreshes Settings; partial batch keeps failed item',
    () async {
      final h = await _Harness.create();
      final likes = PostActivityController(
        PostActivityKind.likes,
        h.repository,
      );
      final saves = PostActivityController(
        PostActivityKind.saved,
        h.repository,
      );
      await likes.refresh();
      await saves.refresh();
      await h.repository.engagement(1, 'save', false);
      await Future<void>.delayed(Duration.zero);
      expect(saves.items, isEmpty);
      h.failRemoval = 2;
      expect((await likes.remove({'1', '2'})).keys, ['2']);
      expect(likes.items.map((item) => item.id), ['2']);
      expect(h.calls.any((c) => c == 'DELETE /api/v1/posts/1'), false);
      h.failRemoval = null;
      await h.repository.engagement(2, 'like', false);
      await Future<void>.delayed(Duration.zero);
      expect(likes.items, isEmpty);
      likes.dispose();
      saves.dispose();
      h.auth.dispose();
    },
  );
  test(
    'delete own reply uses P3 id and reconciles only its Post count',
    () async {
      final h = await _Harness.create();
      final feed = PostFeedController(h.repository);
      final controller = PostActivityController(
        PostActivityKind.comments,
        h.repository,
      );
      await feed.refresh();
      await controller.refresh();
      expect(await controller.remove({'12'}), isEmpty);
      await Future<void>.delayed(Duration.zero);
      expect(controller.items.map((i) => i.id), ['11']);
      expect(feed.items.first['commentCount'], 1);
      expect(h.calls, contains('DELETE /api/v1/comments/12'));
      expect(h.calls.any((c) => c == 'DELETE /api/v1/comments/99'), false);
      expect(h.calls.where((c) => c.contains('/feed')).length, 1);
      feed.dispose();
      controller.dispose();
      h.auth.dispose();
    },
  );
  test(
    'logout drops list immediately and rejects stale response; B sees no A activity',
    () async {
      final h = await _Harness.create();
      final controller = PostActivityController(
        PostActivityKind.likes,
        h.repository,
      );
      await controller.refresh();
      h.holdPage = Completer();
      final stale = controller.refresh();
      await h.auth.clearLocal();
      expect(controller.items, isEmpty);
      h.holdPage!.complete(
        http.Response(
          jsonEncode({
            'items': [h.item(1, 'likedAt')],
            'nextCursor': null,
          }),
          200,
        ),
      );
      await stale;
      expect(controller.items, isEmpty);
      h.holdPage = null;
      h.actor = 'b';
      await h.login();
      await controller.refresh();
      expect(controller.items, isEmpty);
      controller.dispose();
      h.auth.dispose();
    },
  );
  test(
    'failed permission revalidation hides previous items, retry uses server truth',
    () async {
      final h = await _Harness.create();
      final controller = PostActivityController(
        PostActivityKind.saved,
        h.repository,
      );
      await controller.refresh();
      h.failPage = true;
      await controller.refresh();
      expect(controller.items, isEmpty);
      expect(controller.error, isNotNull);
      h.failPage = false;
      await controller.refresh();
      expect(controller.items.length, 1);
      controller.dispose();
      h.auth.dispose();
    },
  );
  testWidgets(
    'Like Place tab remains; real Post thumbnail opens exactly the selected ID',
    (t) async {
      final h = await _Harness.create();
      await t.pumpWidget(
        MaterialApp(
          home: SettingsCollectionScreen(
            kind: SettingsCollectionKind.likes,
            repository: h.repository,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Địa điểm'), findsOneWidget);
      expect(find.byType(ProtectedPostMedia), findsNothing);
      await t.tap(find.text('Bài viết'));
      await t.pumpAndSettle();
      expect(find.byType(ProtectedPostMedia), findsNWidgets(2));
      await t.tap(find.byType(ProtectedPostMedia).first);
      await t.pumpAndSettle();
      final viewer = t.widget<GoMateProfilePostFeedScreen>(
        find.byType(GoMateProfilePostFeedScreen),
      );
      expect(viewer.remote, true);
      expect(viewer.postId, 1);
      expect(viewer.posts, isEmpty);
      expect(h.calls, contains('GET /api/v1/posts/1'));
      expect(h.calls.where((c) => c == 'GET /api/v1/posts/2'), isEmpty);
      await t.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
  testWidgets(
    'two-level comments select only own lower row; reference opens existing comment sheet',
    (t) async {
      final h = await _Harness.create();
      await t.pumpWidget(
        MaterialApp(
          home: SettingsCollectionScreen(
            kind: SettingsCollectionKind.comments,
            repository: h.repository,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Foreign parent'), findsOneWidget);
      expect(find.text('Own reply'), findsOneWidget);
      await t.tap(find.byIcon(LucideIcons.copy));
      await t.pump();
      expect(find.byIcon(LucideIcons.circle), findsNWidgets(2));
      await t.tap(find.text('Own reply'));
      await t.pump();
      expect(find.text('Gỡ bình luận (1)'), findsOneWidget);
      await t.tap(find.text('Gỡ bình luận (1)'));
      await t.pumpAndSettle();
      expect(find.text('Own reply'), findsNothing);
      expect(find.text('Own root'), findsOneWidget);
      expect(h.calls, contains('DELETE /api/v1/comments/12'));
      await t.tap(find.text('Bài viết gốc'));
      await t.pumpAndSettle();
      expect(find.byType(CommentSheetContent), findsOneWidget);
      expect(h.calls, contains('GET /api/v1/posts/1/comments'));
      await t.pumpWidget(const SizedBox());
      h.auth.dispose();
    },
  );
}
