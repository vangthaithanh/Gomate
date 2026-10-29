import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/session_store.dart';
import 'package:gomate/core/widgets/gomate_unread_indicator.dart';
import 'package:gomate/features/notifications/data/notification_repository.dart';
import 'package:gomate/features/notifications/data/notification_realtime_client.dart';
import 'package:gomate/features/notifications/data/follow_request_repository.dart';
import 'package:gomate/features/notifications/models/gomate_notification.dart';
import 'package:gomate/features/notifications/screens/notification_screen.dart';
import 'package:gomate/features/profile/screens/profile_post_feed_screen.dart';
import 'package:gomate/features/home/widgets/comment_sheet_content.dart';

class _Store implements SessionStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}

class _Realtime implements NotificationRealtimeClient {
  final channel = StreamController<NotificationRealtimeEvent>.broadcast();
  @override
  Stream<NotificationRealtimeEvent> connect() => channel.stream;
  @override
  void disconnect() {}
  void signal(String id) => channel.add(
    NotificationRealtimeEvent(
      eventId: 'event-$id',
      eventKind: 'CREATED',
      notificationId: id,
    ),
  );
}

Map<String, dynamic> _row(String id, String type) => {
  'id': id,
  'type': type,
  'actorId': 'A',
  'actorName': 'Xuân Thu',
  'postId': 42,
  if (type != 'POST_LIKE') 'commentId': 9,
  'message': 'Never trust arbitrary private preview',
  'occurredAt': DateTime.now().toUtc().toIso8601String(),
  'isRead': false,
};

class _Fixture {
  final rows = <Map<String, dynamic>>[];
  final realtime = _Realtime();
  final paths = <String>[];
  bool denyPost = false, missingComment = false, failRead = false;
  Completer<void>? targetGate;
  late final AuthService auth = AuthService(
    baseUrl: 'http://localhost/api/v1',
    store: _Store(),
    client: MockClient((r) async {
      final path = r.url.path;
      paths.add('${r.method} $path');
      if (path.endsWith('/login')) {
        final actor = (jsonDecode(r.body) as Map)['email'];
        return ok({
          'user': {'id': actor},
          'accessToken': 'access',
          'refreshToken': 'refresh',
        });
      }
      if (path.endsWith('/notifications'))
        return ok({
          'items': rows,
          'total': rows.length,
          'unreadCount': rows.where((r) => r['isRead'] != true).length,
        });
      if (path.endsWith('/post-target')) {
        await targetGate?.future;
        return denyPost
            ? http.Response('{}', 404)
            : ok({
                'postId': 42,
                'commentId': rows.first['commentId'],
                'rootCommentId': 9,
                'commentAvailable': !missingComment,
              });
      }
      if (path.endsWith('/read')) {
        if (failRead) return http.Response('{}', 503);
        final id = path.split('/').reversed.skip(1).first;
        final row = rows.firstWhere((r) => r['id'] == id);
        row['isRead'] = true;
        return ok(row);
      }
      if (path.contains('/notifications/'))
        return ok(rows.firstWhere((r) => r['id'] == path.split('/').last));
      if (path.endsWith('/follow-requests'))
        return ok({'items': [], 'total': 0});
      if (path.endsWith('/posts/42')) {
        if (denyPost) return http.Response('{}', 404);
        return ok({
          'id': 42,
          'authorId': 'A',
          'authorName': 'Xuân Thu',
          'caption': 'Real Post',
          'hashtags': [],
          'media': [],
          'taggedUserIds': [],
          'audience': 'EVERYONE',
          'createdAt': '2026-10-23T00:00:00Z',
        });
      }
      if (path.endsWith('/comments'))
        return ok({'items': [], 'nextCursor': null});
      return ok({});
    }),
  );
  late final inbox = NotificationRepository(auth: auth, realtime: realtime);
  http.Response ok(Object data) => http.Response(
    jsonEncode(data),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  Future<void> login([String actor = 'B']) =>
      auth.login(email: actor, password: 'test', remember: false);
  void dispose() {
    inbox.dispose();
    auth.dispose();
    unawaited(realtime.channel.close());
  }
}

void main() {
  for (final type in ['POST_LIKE', 'POST_COMMENT', 'POST_REPLY']) {
    test(
      'Parses $type as ordinary notification with safe copy and business IDs',
      () {
        final item = GoMateNotificationItem.fromJson(_row('N', type));
        expect(item.isPostInteraction, isTrue);
        expect(item.isPendingInvitation, isFalse);
        expect(item.postId, '42');
        expect(item.invitationId, isNull);
        expect(item.message, isNot(contains('private preview')));
        expect(item.copyWith(isRead: true).commentId, item.commentId);
      },
    );
  }

  testWidgets(
    'Post SSE/FCM invalidation and poll yield one popup and update unread dot after read ACK',
    (tester) async {
      final f = _Fixture();
      await f.login();
      final popups = <String>[];
      f.inbox.events.listen((e) => popups.add(e.id));
      f.inbox.start();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: ListenableBuilder(
            listenable: f.inbox,
            builder: (_, _) => GoMateUnreadIndicator(
              unread: f.inbox.unreadCount > 0,
              child: const Icon(Icons.notifications),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('gomate-unread-dot')), findsNothing);
      f.rows.add(_row('N', 'POST_REPLY'));
      f.realtime.signal('N');
      f.inbox.invalidate('N');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      await f.inbox.refresh();
      await tester.pump();
      expect(popups, ['N']);
      expect(find.byKey(const ValueKey('gomate-unread-dot')), findsOneWidget);
      f.realtime.signal('N');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(popups, ['N']);
      await f.inbox.markRead('N');
      await tester.pump();
      expect(find.byKey(const ValueKey('gomate-unread-dot')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      f.dispose();
    },
  );

  testWidgets(
    'Read error preserves unread and account switch clears old notifications',
    (tester) async {
      final f = _Fixture();
      await f.login();
      f.inbox.start();
      await tester.pump(const Duration(milliseconds: 150));
      f.rows.add(_row('N', 'POST_LIKE'));
      await f.inbox.refresh();
      f.failRead = true;
      await expectLater(f.inbox.markRead('N'), throwsA(anything));
      expect(f.inbox.unreadCount, 1);
      expect(f.inbox.byId('N')!.isRead, isFalse);
      f.rows.clear();
      await f.login('C');
      expect(f.inbox.items, isEmpty);
      expect(f.inbox.unreadCount, 0);
      f.dispose();
      await tester.pump();
    },
  );

  for (final denied in [false, true]) {
    testWidgets(
      'Post notification opens protected viewer with no invitation action; denied=$denied',
      (tester) async {
        final f = _Fixture()..denyPost = denied;
        f.rows.add(_row('N', 'POST_LIKE'));
        await f.login();
        await tester.pumpWidget(
          MaterialApp(
            home: GoMateNotificationScreen(
              repository: f.inbox,
              followRequests: FollowRequestRepository(auth: f.auth),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Chấp nhận'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('N')));
        await tester.pumpAndSettle();
        expect(f.paths, contains('GET /api/v1/notifications/N/post-target'));
        expect(f.paths, contains('PATCH /api/v1/notifications/N/read'));
        expect(find.byType(GoMateProfilePostFeedScreen), findsOneWidget);
        expect(
          find.textContaining(
            denied ? 'Bài viết không khả dụng' : 'Real',
            findRichText: true,
          ),
          findsOneWidget,
        );
        if (denied) expect(find.text('Quay lại thông báo'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        f.dispose();
      },
    );
  }

  testWidgets(
    'Deleted comment opens allowed Post and real sheet with unavailable notice',
    (tester) async {
      final f = _Fixture()..missingComment = true;
      f.rows.add(_row('N', 'POST_COMMENT'));
      await f.login();
      await tester.pumpWidget(
        MaterialApp(
          home: GoMateNotificationScreen(
            repository: f.inbox,
            followRequests: FollowRequestRepository(auth: f.auth),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('N')));
      await tester.pumpAndSettle();
      expect(find.byType(CommentSheetContent), findsOneWidget);
      expect(f.paths, contains('GET /api/v1/posts/42/comments'));
      expect(find.text('Bình luận không còn khả dụng'), findsOneWidget);
      // Text in a SnackBar beneath the modal exists in the tree but cannot
      // actually be seen/touched while the Comment sheet covers it.
      expect(
        find.text('Bình luận không còn khả dụng').hitTestable(),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(CommentSheetContent),
          matching: find.text('Bình luận không còn khả dụng'),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 11));
      expect(
        find.text('Bình luận không còn khả dụng').hitTestable(),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      f.dispose();
    },
  );

  testWidgets(
    'Available comment opens sheet without an unavailable notice',
    (tester) async {
      final f = _Fixture();
      f.rows.add(_row('N', 'POST_COMMENT'));
      await f.login();
      await tester.pumpWidget(
        MaterialApp(
          home: GoMateNotificationScreen(
            repository: f.inbox,
            followRequests: FollowRequestRepository(auth: f.auth),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('N')));
      await tester.pumpAndSettle();
      expect(find.byType(CommentSheetContent), findsOneWidget);
      expect(find.text('Bình luận không còn khả dụng'), findsNothing);
      expect(f.paths, contains('GET /api/v1/notifications/N/post-target'));
      await tester.pumpWidget(const SizedBox());
      f.dispose();
    },
  );

  testWidgets(
    'Changing account during target lookup cannot open old notification Post',
    (tester) async {
      final f = _Fixture();
      f.rows.add(_row('N', 'POST_LIKE'));
      await f.login();
      f.inbox.start();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpWidget(
        MaterialApp(
          home: GoMateNotificationScreen(
            repository: f.inbox,
            followRequests: FollowRequestRepository(auth: f.auth),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gate = Completer<void>();
      f.targetGate = gate;
      await tester.tap(find.byKey(const ValueKey('N')));
      await tester.pump();
      f.rows.clear();
      await f.login('C');
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(GoMateProfilePostFeedScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      f.dispose();
    },
  );
}
