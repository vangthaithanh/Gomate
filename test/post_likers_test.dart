import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomate/core/network/api_exception.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/session_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gomate/features/posts/data/post_repository.dart';
import 'package:gomate/features/posts/widgets/post_likers_content.dart';
import 'package:gomate/features/profile/screens/profile_post_feed_screen.dart';
import 'package:gomate/features/home/screens/home_screen.dart';
import 'profile_posts_test.dart' as fixture;

class _Repo extends PostRepository {
  _Repo(AuthService auth) : super(auth: auth);
  final reads = <String?>[];
  int? error;
  Completer<Map<String, dynamic>>? gate;
  List<Map<String, dynamic>> rows = [
    {
      'userId': 'thu',
      'displayName': 'Xuân Thu',
      'nickname': 'thu_handle',
      'avatarUrl': null,
    },
  ];
  @override
  Future<Map<String, dynamic>> likers(int id, {String? cursor}) async {
    reads.add(cursor);
    if (gate != null) return gate!.future;
    if (error != null) throw ApiException(error!, 'FAILED', 'Failed');
    return {
      'items': cursor == null
          ? rows
          : [
              rows.first,
              {'userId': 'thanh', 'displayName': 'Thanh', 'nickname': 'thanh'},
            ],
      'nextCursor': cursor == null ? 'next' : null,
    };
  }

  @override
  Future<Map<String, dynamic>> detail(int id) async => {
    ...fixture.post(id),
    'media': [],
  };
  @override
  Future<Map<String, dynamic>> feed({String? cursor}) async => {
    'items': [await detail(1)],
    'nextCursor': null,
  };
}

class _Store implements SessionStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Likers uses GoMate names/avatar rows, loads more without duplicates and returns selection',
    (tester) async {
      final a = await fixture.auth();
      final r = _Repo(a);
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await showModalBottomSheet<String>(
                    context: context,
                    builder: (_) => PostLikersContent(postId: 1, repository: r),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Xuân Thu'), findsOneWidget);
      expect(find.text('@thu_handle'), findsOneWidget);
      await tester.tap(find.text('Xem thêm'));
      await tester.pumpAndSettle();
      expect(find.text('Xuân Thu'), findsOneWidget);
      expect(find.text('Thanh'), findsOneWidget);
      expect(r.reads, [null, 'next']);
      await tester.tap(find.byKey(const ValueKey('post-liker-thu')));
      await tester.pumpAndSettle();
      expect(selected, 'thu');
      await tester.pumpWidget(const SizedBox());
      a.dispose();
    },
  );
  testWidgets(
    'Likers loading, empty, network retry and denied states do not invent users',
    (tester) async {
      final a = await fixture.auth();
      final r = _Repo(a)..error = 503;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PostLikersContent(postId: 1, repository: r)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
      r.error = null;
      r.rows = [];
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có lượt thích'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      r.error = 404;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PostLikersContent(postId: 1, repository: r)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bài viết không còn khả dụng'), findsOneWidget);
      expect(find.text('Thử lại'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      a.dispose();
    },
  );
  testWidgets('Account switch clears likers and ignores a late response', (
    tester,
  ) async {
    final a = await fixture.auth();
    final r = _Repo(a)..gate = Completer();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PostLikersContent(postId: 1, repository: r)),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await a.clearLocal();
    r.gate!.complete({'items': r.rows, 'nextCursor': null});
    await tester.pumpAndSettle();
    expect(find.text('Xuân Thu'), findsNothing);
    expect(find.text('Tài khoản đã thay đổi'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    a.dispose();
  });
  for (final home in [false, true]) {
    testWidgets(
      'Holding Like opens real likers without liking the Post: home=$home',
      (tester) async {
        tester.view.physicalSize = const Size(400, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <String>[];
        final a = AuthService(
          baseUrl: 'http://localhost/api/v1',
          store: _Store(),
          client: MockClient((req) async {
            calls.add('${req.method} ${req.url.path}');
            return http.Response(
              jsonEncode(
                req.url.path.endsWith('/login')
                    ? {
                        'user': {'id': 'owner'},
                        'accessToken': 'access',
                        'refreshToken': 'refresh',
                      }
                    : req.url.path.endsWith('/likes')
                    ? {
                        'items': [
                          {'userId': 'thu', 'displayName': 'Xuân Thu'},
                        ],
                        'nextCursor': null,
                      }
                    : {},
              ),
              200,
            );
          }),
        );
        await a.login(
          email: 'owner@example.com',
          password: 'TestPass123!',
          remember: false,
        );
        final r = _Repo(a);
        await tester.pumpWidget(
          MaterialApp(
            home: home
                ? HomeScreen(postRepository: r)
                : GoMateProfilePostFeedScreen(
                    posts: const [],
                    remote: true,
                    postId: 1,
                    repository: r,
                  ),
          ),
        );
        await tester.pumpAndSettle();
        final heart = find.byIcon(LucideIcons.heart).first;
        await tester.ensureVisible(heart);
        await tester.pumpAndSettle();
        await tester.longPress(heart);
        await tester.pumpAndSettle();
        expect(find.text('Người đã thích'), findsOneWidget);
        if (home)
          expect(r.reads, [null]);
        else
          expect(calls, contains('GET /api/v1/posts/1/likes'));
        expect(
          calls.where((c) => c.startsWith('PUT ') || c.startsWith('DELETE ')),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        a.dispose();
      },
    );
  }
}
