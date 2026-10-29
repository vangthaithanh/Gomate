import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/session_store.dart';
import 'package:gomate/core/widgets/bottom_sheet.dart';
import 'package:gomate/features/posts/data/comment_repository.dart';
import 'package:gomate/features/posts/data/post_repository.dart';
import 'package:gomate/features/posts/data/post_video_pool.dart';
import 'package:gomate/features/posts/widgets/post_menu_actions.dart';
import 'package:gomate/features/home/widgets/comment_sheet_content.dart';
import 'package:gomate/features/home/widgets/report_reason_content.dart';
import 'package:gomate/features/posts/screens/post_reports_screen.dart';

class _Store implements SessionStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}

Map<String, dynamic> comment(
  int id, {
  int? parent,
  int replies = 0,
  bool mine = false,
}) => {
  'commentId': id,
  'id': id,
  'postId': 1,
  'userId': 'actor',
  'userName': 'User $id',
  'avatarUrl': '',
  'body': 'Body $id',
  'createdAt': '2026-10-23T00:00:00Z',
  'likeCount': 0,
  'likedByMe': false,
  'isMine': mine,
  'parentCommentId': parent,
  'replyCount': replies,
  'media': [],
};
Future<AuthService> auth(
  Future<http.Response> Function(http.Request) send,
) async {
  final a = AuthService(
    store: _Store(),
    baseUrl: 'http://localhost/api/v1',
    client: MockClient((r) async {
      if (r.url.path.endsWith('/login'))
        return http.Response(
          jsonEncode({
            'accessToken': 'access',
            'refreshToken': 'refresh',
            'user': {'id': 'actor', 'isPrivate': false},
          }),
          200,
        );
      return send(r);
    }),
  );
  await a.login(
    email: 'x@example.com',
    password: 'TestPass123!',
    remember: false,
  );
  return a;
}

http.Response ok(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'six real image uploads are reused after uncertain Comment ACK',
    () async {
      final dir = await Directory.systemTemp.createTemp('gomate-comment-test-');
      final files = <File>[];
      int uploads = 0, sends = 0;
      final attempts = <Map<String, dynamic>>[];
      final a = await auth((r) async {
        if (r.url.path.endsWith('/comments/media')) {
          uploads++;
          return ok({
            'mediaId':
                '00000000-0000-4000-8000-${uploads.toString().padLeft(12, '0')}',
          });
        }
        sends++;
        attempts.add(jsonDecode(r.body) as Map<String, dynamic>);
        if (sends == 1)
          return http.Response(
            '{"error":{"code":"TIMEOUT","message":"retry"}}',
            503,
          );
        return ok(comment(8));
      });
      try {
        for (int i = 0; i < 6; i++) {
          files.add(await File('${dir.path}/$i.jpg').writeAsString('photo'));
        }
        final repo = ApiPostInteractionRepository(auth: a);
        await expectLater(
          repo.createComment(
            postId: '1',
            body: '',
            mediaAssets: files.map((f) => f.path).toList(),
          ),
          throwsException,
        );
        await repo.createComment(
          postId: '1',
          body: '',
          mediaAssets: files.map((f) => f.path).toList(),
        );
        expect(uploads, 6);
        expect(attempts[0]['mediaIds'], hasLength(6));
        expect(attempts[1], attempts[0]);
      } finally {
        a.dispose();
        for (final file in files) {
          await file.delete();
        }
        await dir.delete();
      }
    },
  );
  testWidgets('report history and open detail disappear on account logout', (
    t,
  ) async {
    final a = await auth(
      (r) async => ok({
        'items': [
          {
            'id': 'report',
            'postId': 1,
            'reasonCode': 'SCAM_OR_SPAM',
            'details': 'private report text',
            'createdAt': '2026-10-23T00:00:00Z',
            'status': 'PENDING',
          },
        ],
        'nextCursor': null,
      }),
    );
    await t.pumpWidget(
      MaterialApp(
        home: PostReportsScreen(repository: PostRepository(auth: a)),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text(ReportReason.scamOrSpam.label));
    await t.pumpAndSettle();
    expect(find.text('private report text'), findsOneWidget);
    await a.clearLocal();
    await t.pumpAndSettle();
    expect(find.text('private report text'), findsNothing);
    expect(find.text(ReportReason.scamOrSpam.label), findsNothing);
    await t.pumpWidget(const SizedBox());
    a.dispose();
  });
  Future<void> sheet(WidgetTester t, AuthService a) async {
    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommentSheetContent(
            postId: '1',
            repository: ApiPostInteractionRepository(auth: a),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  test('native decoder pool evicts oldest, not all mounted Post covers', () {
    final pool = PostVideoPool();
    final released = <int>[];
    pool.acquire(1, () => released.add(1));
    pool.acquire(2, () => released.add(2));
    pool.acquire(1, () => released.add(1));
    pool.acquire(3, () => released.add(3));
    expect(released, [2]);
    pool.forget(1);
    pool.clear();
    expect(released, [2, 3]);
  });
  test(
    'uncertain comment retry keeps request key and original submission',
    () async {
      final attempts = <Map<String, dynamic>>[];
      final a = await auth((r) async {
        attempts.add(jsonDecode(r.body) as Map<String, dynamic>);
        if (attempts.length == 1)
          throw StateError('connection lost after commit');
        return ok(comment(9));
      });
      final repo = ApiPostInteractionRepository(auth: a);
      await expectLater(
        repo.createComment(postId: '1', body: 'original'),
        throwsStateError,
      );
      expect(repo.commitPending, true);
      await repo.createComment(postId: '1', body: 'edited');
      expect(attempts[1], attempts[0]);
      expect(repo.commitPending, false);
      await a.clearLocal();
      await expectLater(repo.page('1'), throwsStateError);
      a.dispose();
    },
  );
  test('empty/overlength/seven images rejected before upload', () async {
    int calls = 0;
    final a = await auth((r) async {
      calls++;
      return ok({});
    });
    final repo = ApiPostInteractionRepository(auth: a);
    await expectLater(
      repo.createComment(postId: '1', body: ''),
      throwsStateError,
    );
    await expectLater(
      repo.createComment(postId: '1', body: 'a' * 2001),
      throwsStateError,
    );
    await expectLater(
      repo.createComment(
        postId: '1',
        body: '',
        mediaAssets: List.generate(7, (i) => '$i.jpg'),
      ),
      throwsStateError,
    );
    expect(calls, 0);
    a.dispose();
  });
  testWidgets(
    'replies load lazily, collapse, like uses server ACK, text hides media tools',
    (t) async {
      int replies = 0, likes = 0;
      final a = await auth((r) async {
        if (r.url.path.endsWith('/replies')) {
          replies++;
          return ok({
            'items': [comment(2, parent: 1)],
            'nextCursor': null,
          });
        }
        if (r.url.path.endsWith('/like')) {
          likes++;
          return ok({
            ...comment(2, parent: 1),
            'likedByMe': true,
            'likeCount': 1,
          });
        }
        return ok({
          'items': [comment(1, replies: 1)],
          'nextCursor': null,
        });
      });
      await sheet(t, a);
      expect(replies, 0);
      expect(find.text('2'), findsNothing);
      expect(find.byIcon(LucideIcons.camera), findsOneWidget);
      await t.enterText(find.byType(TextField), 'hello');
      await t.pump();
      expect(find.byIcon(LucideIcons.camera), findsNothing);
      await t.tap(find.text('Hiển thị 1 câu trả lời'));
      await t.pumpAndSettle();
      expect(replies, 1);
      expect(find.text('2'), findsOneWidget);
      await t.tap(find.byIcon(LucideIcons.heart).last);
      await t.pumpAndSettle();
      expect(likes, 1);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      await t.tap(find.text('Ẩn câu trả lời'));
      await t.pumpAndSettle();
      expect(find.text('2'), findsNothing);
      await t.pumpWidget(const SizedBox());
      a.dispose();
    },
  );
  for (final replying in [false, true]) {
    testWidgets(
      '${replying ? 'reply' : 'new comment'} keeps the same input and keyboard through typing and send',
      (t) async {
        t.view.physicalSize = const Size(400, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetViewInsets);
        final submissions = <Map<String, dynamic>>[];
        final a = await auth((r) async {
          if (r.method == 'POST') {
            final body = jsonDecode(r.body) as Map<String, dynamic>;
            submissions.add(body);
            return ok({
              ...comment(30 + submissions.length, parent: replying ? 1 : null),
              'body': body['body'],
            });
          }
          return ok({
            'items': r.url.path.endsWith('/replies')
                ? <Object>[]
                : [comment(1)],
            'nextCursor': null,
          });
        });
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
        unawaited(
          GoMateBottomSheet.show<void>(
            context: host,
            size: GoMateBottomSheetSize.expanded,
            child: CommentSheetContent(
              postId: '1',
              repository: ApiPostInteractionRepository(auth: a),
            ),
          ),
        );
        await t.pumpAndSettle();
        final input = find.byType(TextField);
        final editable = find.byType(EditableText);
        final originalState = t.state<EditableTextState>(editable);
        final focus = t.widget<TextField>(input).focusNode!;

        // Each fresh draft gets one tap, never enterText (which refocuses).
        for (var draft = 0; draft < 2; draft++) {
          if (replying) {
            await t.tap(find.text('Trả lời').first);
          } else {
            await t.tap(input);
          }
          await t.pumpAndSettle();
          expect(focus.hasFocus, isTrue);
          expect(t.testTextInput.isVisible, isTrue);

          t.view.viewInsets = const FakeViewPadding(bottom: 300);
          await t.pumpAndSettle();
          for (final text in ['h', 'hello', '', 'n', 'next draft']) {
            t.testTextInput.updateEditingValue(
              TextEditingValue(
                text: text,
                selection: TextSelection.collapsed(offset: text.length),
              ),
            );
            await t.pump();
            expect(t.state<EditableTextState>(editable), same(originalState));
            expect(focus.hasFocus, isTrue);
            expect(t.testTextInput.isVisible, isTrue);
            expect(t.widget<TextField>(input).controller!.text, text);
            expect(
              find.byIcon(LucideIcons.camera),
              text.isEmpty ? findsOneWidget : findsNothing,
            );
          }
          await t.tap(find.byIcon(LucideIcons.send));
          await t.pumpAndSettle();
          expect(submissions.length, draft + 1);
          expect(submissions.last['body'], 'next draft');
          expect(submissions.last['parentId'], replying ? 1 : null);
          expect(t.widget<TextField>(input).controller!.text, isEmpty);
          expect(t.state<EditableTextState>(editable), same(originalState));
        }
        await t.pumpWidget(const SizedBox());
        a.dispose();
      },
    );
  }
  testWidgets(
    'failed comment keeps draft; retry ACK clears and shows real comment',
    (t) async {
      int sends = 0;
      final a = await auth((r) async {
        if (r.method == 'POST') {
          sends++;
          if (sends == 1)
            return http.Response(
              '{"error":{"code":"OFFLINE","message":"offline"}}',
              503,
            );
          return ok({...comment(3), 'body': 'my draft'});
        }
        return ok({'items': [], 'nextCursor': null});
      });
      await sheet(t, a);
      await t.enterText(find.byType(TextField), 'my draft');
      await t.pump();
      await t.tap(find.byIcon(LucideIcons.send));
      await t.pumpAndSettle();
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'my draft',
      );
      await t.tap(find.byIcon(LucideIcons.send));
      await t.pumpAndSettle();
      expect(sends, 2);
      expect(find.text('my'), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');
      await t.pumpWidget(const SizedBox());
      a.dispose();
    },
  );
  testWidgets(
    'Report sheet keeps all six reasons; success only after ACK and history action',
    (t) async {
      final pending = Completer<http.Response>();
      int reports = 0;
      final a = await auth((r) async {
        if (r.url.path.endsWith('/reports') && r.method == 'POST') {
          reports++;
          expect(jsonDecode(r.body)['reasonCode'], 'SCAM_OR_SPAM');
          return pending.future;
        }
        return ok({'id': 1, 'authorId': 'someone', 'pinned': false});
      });
      final menu = PostMenuActions(PostRepository(auth: a));
      late BuildContext host;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              host = c;
              return const Scaffold();
            },
          ),
        ),
      );
      unawaited(menu.open(host, 1));
      await t.pumpAndSettle();
      await t.tap(find.text('Báo cáo'));
      await t.pumpAndSettle();
      expect(find.text('Cảm ơn bạn đã đóng góp ý kiến'), findsNothing);
      await t.tap(find.text(ReportReason.scamOrSpam.label));
      await t.pumpAndSettle();
      await t.tap(find.text('Gửi'));
      await t.tap(find.text('Gửi'), warnIfMissed: false);
      await t.pump();
      expect(reports, 1);
      expect(find.text('Cảm ơn bạn đã đóng góp ý kiến'), findsNothing);
      pending.complete(ok({'id': 'report', 'status': 'PENDING'}));
      await t.pumpAndSettle();
      expect(find.text('Cảm ơn bạn đã đóng góp ý kiến'), findsOneWidget);
      expect(find.text('Xem báo cáo'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      a.dispose();
    },
  );
}
