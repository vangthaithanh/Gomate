import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/session_store.dart';
import 'package:gomate/features/posts/data/post_share_repository.dart';
import 'package:gomate/features/home/widgets/share_post_content.dart';
import 'package:gomate/features/search/data/search_repository.dart';
import 'package:gomate/features/search/models/search_models.dart';
import 'package:gomate/features/search/screens/search_screen.dart';
import 'package:gomate/features/map/services/location_service.dart';
import 'package:gomate/features/messages/models/message_models.dart';
import 'package:gomate/features/messages/widgets/message_widgets.dart';
import 'package:gomate/features/profile/screens/profile_post_feed_screen.dart';

class _Store implements SessionStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> clear() async {}
  @override
  Future<void> write(String value) async {}
}

class _NoLocation extends GoMateLocationService {
  @override
  Future<GoMateLocationResult> getCurrentLocation({
    bool requestPermission = true,
  }) async => const GoMateLocationResult(GoMateLocationState.serviceOff);
}

http.Response ok(Object? data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Future<AuthService> auth(
  Future<http.Response> Function(http.Request) handle,
) async {
  final service = AuthService(
    store: _Store(),
    baseUrl: 'http://localhost/api/v1',
    client: MockClient((r) async {
      if (r.url.path.endsWith('/login'))
        return ok({
          'accessToken': 'token',
          'refreshToken': 'refresh',
          'user': {'id': 'a'},
        });
      return handle(r);
    }),
  );
  await service.login(
    email: 'a@example.com',
    password: 'TestPass123!',
    remember: false,
  );
  return service;
}

const targets = [
  {
    'type': 'USER',
    'targetId': 'alice',
    'name': 'Alice',
    'subtitle': 'Bạn bè',
    'avatarUrl': null,
  },
  {
    'type': 'GROUP',
    'targetId': 'group',
    'name': 'Group',
    'subtitle': 'Nhóm chat',
    'avatarUrl': null,
  },
];
Map<String, Object?> post(int id) => {
  'id': id,
  'caption': 'Đà Nẵng',
  'hashtags': ['dulich'],
  'thumbnailUrl': '/posts/$id/media/cover/thumbnail',
};

class _Search extends SearchRepository {
  final pending = <String, Completer<SearchBundle>>{};
  _Search(AuthService auth) : super(auth: auth);
  @override
  Future<List<SearchPlaceItem>> getSuggestedPlaces() async => [];
  @override
  Future<List<String>> getRecentSearches() async => [];
  @override
  Future<SearchBundle> search({
    required String query,
    Set<SearchPlaceFilter> placeFilters = const {},
    Set<String> hashtags = const {},
  }) => (pending[query] ??= Completer<SearchBundle>()).future;
}

void main() {
  test(
    'Missing GPS blocks only nearby Places, never invents coordinates or blocks Post/User tabs',
    () async {
      final a = await auth((r) async {
        if (r.url.path.endsWith('/users/search'))
          return ok({'items': [], 'total': 0});
        expect(r.url.path.endsWith('/search/posts'), isTrue);
        return ok({
          'items': [post(42)],
          'nextCursor': null,
        });
      });
      final result = await SearchRepository(
        auth: a,
        locationService: _NoLocation(),
      ).search(query: 'Hồ', placeFilters: {SearchPlaceFilter.nearby});
      expect(result.places, isEmpty);
      expect(result.placeError, isNotNull);
      expect(result.posts.single.id, 42);
    },
  );
  testWidgets(
    'Share keeps selected targets through contact search and cancel',
    (tester) async {
      Map<String, dynamic>? sent;
      final a = await auth((r) async {
        if (r.method == 'GET')
          return ok(
            r.url.queryParameters['q'] == 'Group' ? [targets.last] : targets,
          );
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return ok([
          for (final t in sent!['targets']) {...t, 'success': true},
        ]);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SharePostContent(
              postId: '42',
              repository: PostShareRepository(auth: a, postId: '42'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alice'));
      await tester.pump();
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Group');
      await tester.pump(const Duration(milliseconds: 310));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Group').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pumpAndSettle();
      expect((sent!['targets'] as List).length, 2);
    },
  );
  testWidgets(
    'Live debounce invalidates stale request immediately and account switch clears results',
    (tester) async {
      final a = await auth((_) async => ok({}));
      final repo = _Search(a);
      await tester.pumpWidget(
        MaterialApp(home: SearchScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'old');
      await tester.pump(const Duration(milliseconds: 330));
      expect(repo.pending.containsKey('old'), isTrue);
      await tester.enterText(find.byType(TextField), 'new');
      repo.pending['old']!.complete(
        const SearchBundle(
          users: [SearchUserItem(id: 'old', name: 'Old result', subtitle: '')],
        ),
      );
      await tester.pump();
      expect(find.text('Old result'), findsNothing);
      await tester.pump(const Duration(milliseconds: 330));
      repo.pending['new']!.complete(
        const SearchBundle(
          users: [SearchUserItem(id: 'new', name: 'New result', subtitle: '')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('New result'), findsOneWidget);
      await a.clearLocal();
      await tester.pumpAndSettle();
      expect(find.text('New result'), findsNothing);
    },
  );
  test(
    'Search uses real paths, protected thumbnail, server history, AND tags and cursors',
    () async {
      final requests = <http.Request>[];
      final a = await auth((r) async {
        requests.add(r);
        if (r.url.path.endsWith('/recent')) return ok(['Đà Nẵng']);
        if (r.url.path.endsWith('/hashtags'))
          return ok([
            {'tag': 'dulich', 'postCount': 2},
          ]);
        if (r.url.path.endsWith('/places'))
          return ok({'items': [], 'nextCursor': null});
        if (r.url.path.endsWith('/users/search'))
          return ok({'items': [], 'total': 0});
        return ok({
          'items': [post(42)],
          'nextCursor': 'next',
        });
      });
      final repo = SearchRepository(auth: a);
      final first = await repo.search(
        query: 'Da Nang',
        hashtags: {'#dulich', '#danang'},
      );
      expect(first.posts.single.id, 42);
      expect(first.posts.single.thumbnailPath, startsWith('/posts/42/'));
      expect(first.posts.single.imageAsset, isEmpty);
      expect(first.postCursor, 'next');
      await repo.nextPage(
        query: 'Da Nang',
        tab: SearchTab.posts,
        current: first,
        hashtags: {'#dulich', '#danang'},
      );
      expect(requests.last.url.queryParameters['cursor'], 'next');
      expect(requests.last.url.queryParameters['hashtags'], 'dulich,danang');
      expect(await repo.getRecentSearches(), ['Đà Nẵng']);
      await repo.saveRecentSearch('Hồ');
      expect(jsonDecode(requests.last.body)['query'], 'Hồ');
      await repo.removeRecentSearch('Hồ');
      expect(requests.last.method, 'DELETE');
      expect((await repo.searchHashtags('du')).single.postCount, 2);
      expect(
        requests.every((r) => r.headers['Authorization'] == 'Bearer token'),
        isTrue,
      );
    },
  );
  test(
    'Share lost ACK retry keeps payload/key and does not duplicate durable messages',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final durable = <String>{};
      bool fail = true;
      final a = await auth((r) async {
        if (r.method == 'GET') return ok(targets);
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        bodies.add(body);
        for (final t in body['targets']) {
          durable.add(
            '${body['clientRequestId']}:${t['type']}:${t['targetId']}',
          );
        }
        if (fail) {
          fail = false;
          throw http.ClientException('lost ACK');
        }
        return ok([
          for (final t in body['targets'])
            {...t, 'success': true, 'messageId': 'stored'},
        ]);
      });
      final repo = PostShareRepository(auth: a, postId: '42');
      final contacts = await repo.getShareContacts();
      expect(contacts.last.isGroup, isTrue);
      await expectLater(
        repo.sharePost(
          postId: '42',
          recipientIds: contacts.map((c) => c.id).toSet(),
          message: 'Hello',
        ),
        throwsA(anything),
      );
      expect(repo.commitPending, isTrue);
      await repo.sharePost(
        postId: '42',
        recipientIds: {'USER:other'},
        message: 'Changed',
      );
      expect(bodies[0], bodies[1]);
      expect(durable.length, 2);
      expect(repo.commitPending, isFalse);
      await a.clearLocal();
      await expectLater(repo.getShareContacts(), throwsStateError);
    },
  );
  test(
    'Partial ACK identifies successes and permits retry of failed targets',
    () async {
      final a = await auth(
        (r) async => ok([
          {'type': 'USER', 'targetId': 'alice', 'success': true},
          {
            'type': 'GROUP',
            'targetId': 'group',
            'success': false,
            'message': 'Không còn quyền gửi',
          },
        ]),
      );
      final repo = PostShareRepository(auth: a, postId: '42');
      try {
        await repo.sharePost(
          postId: '42',
          recipientIds: {'USER:alice', 'GROUP:group'},
        );
        fail('partial must not count as full success');
      } on SharePartialFailure catch (e) {
        expect(e.sent, {'USER:alice'});
        expect(e.message, contains('Không còn quyền'));
      }
      expect(repo.commitPending, isFalse);
    },
  );
  testWidgets(
    'Existing Share grid sends multiple targets and optional text after real ACK',
    (tester) async {
      Map<String, dynamic>? sent;
      final a = await auth((r) async {
        if (r.method == 'GET') return ok(targets);
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return ok([
          for (final t in sent!['targets']) {...t, 'success': true},
        ]);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SharePostContent(
              postId: '42',
              repository: PostShareRepository(auth: a, postId: '42'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alice'));
      await tester.pump();
      await tester.tap(find.text('Group'));
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pumpAndSettle();
      expect((sent!['targets'] as List).length, 2);
      expect(sent!['message'], isEmpty);
    },
  );
  testWidgets(
    'Shared reference opens real permission-checked Post, not a copied preview',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: MessageItem(
                id: 'm',
                senderId: 'a',
                text: '',
                sentAtLabel: 'now',
                postId: 42,
              ),
              isMine: true,
              firstInRun: true,
              lastInRun: true,
            ),
          ),
        ),
      );
      expect(find.text('Bài viết GoMate ↗'), findsOneWidget);
      await tester.tap(find.text('Bài viết GoMate ↗'));
      await tester.pumpAndSettle();
      final viewer = tester.widget<GoMateProfilePostFeedScreen>(
        find.byType(GoMateProfilePostFeedScreen),
      );
      expect(viewer.remote, isTrue);
      expect(viewer.postId, 42);
      expect(viewer.posts, isEmpty);
    },
  );
}
