import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/session_store.dart';
import 'package:gomate/features/messages/data/message_repository.dart';
import 'package:gomate/features/messages/models/message_models.dart';
import 'package:gomate/features/messages/screens/chat_screen.dart';
import 'package:gomate/features/messages/screens/message_screen.dart';
import 'package:gomate/features/messages/widgets/message_widgets.dart';
import 'package:gomate/features/posts/data/post_repository.dart';
import 'package:gomate/features/profile/screens/profile_post_feed_screen.dart';
import 'package:gomate/features/profile/screens/public_profile_screen.dart';
import 'package:gomate/features/search/data/search_repository.dart';

class _Store implements SessionStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}

http.Response _ok(Object? data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Api {
  String status = 'DRAFT';
  String? peerDisplayName = 'Recipient';
  String? peerNickname;
  bool requester = true;
  bool failSend = false;
  bool failAccept = false;
  bool canInitiate = false;
  bool openDenied = false;
  bool includeGroup = false;
  bool chatRecentlySent = false;
  int inboxReads = 0;
  int unreadCount = 0;
  int creates = 0;
  int deletes = 0;
  final keys = <String>[];
  Completer<void>? gate;
  Completer<void>? inboxGate;
  Map<String, Object?> message(String id) => {
    'messageId': id,
    'conversationId': 'chat',
    'senderUserId': 'a',
    'type': 'TEXT',
    'text': id,
    'createdAt': '2026-10-23T10:00:00Z',
  };
  Map<String, Object?> get summary => {
    'conversationId': 'chat',
    'type': 'DIRECT',
    'status': status,
    'requester': requester,
    'recipient': !requester,
    'unreadCount': unreadCount,
    'peer': {
      'userId': 'b',
      'displayName': peerDisplayName,
      'nickname': peerNickname,
    },
    if (status != 'DRAFT') 'latestMessage': message('latest'),
  };
  Map<String, Object?> get group => {
    'conversationId': 'group',
    'type': 'GROUP',
    'status': 'ACCEPTED',
    'linkedTripId': 'trip',
    'displayName': 'Older group',
    'members': [
      {'userId': 'a', 'displayName': 'Me', 'role': 'LEADER'},
    ],
  };
  late final auth = AuthService(
    baseUrl: 'http://localhost/api/v1',
    store: _Store(),
    client: MockClient((r) async {
      final path = r.url.path;
      if (path.endsWith('/message-requests/chat') && r.method == 'DELETE') {
        deletes++;
        status = 'REMOVED';
        return _ok({});
      }
      if (path.endsWith('/login')) {
        return _ok({
          'accessToken': 'access',
          'refreshToken': 'refresh',
          'user': {'id': 'a'},
        });
      }
      if (path.endsWith('/conversations/direct/messages')) {
        final body = jsonDecode(r.body) as Map;
        keys.add(body['clientRequestId'] as String);
        await gate?.future;
        if (failSend)
          return http.Response(
            '{"code":"MESSAGE_STORE_UNAVAILABLE","message":"Try again"}',
            503,
          );
        creates++;
        status = 'PENDING';
        return _ok({'conversation': summary, 'message': message('sent')});
      }
      if (path.endsWith('/conversations/direct')) {
        if (openDenied)
          return http.Response(
            '{"code":"DM_INITIATION_NOT_ALLOWED","message":"Private recipient"}',
            403,
          );
        return _ok(
          status == 'DRAFT'
              ? {'status': 'DRAFT', 'conversationId': null}
              : summary,
        );
      }
      if (path.endsWith('/conversations')) {
        inboxReads++;
        final snapshot = [
          if (status == 'ACCEPTED' && chatRecentlySent) summary,
          if (includeGroup) group,
          if (status == 'ACCEPTED' && !chatRecentlySent) summary,
        ];
        await inboxGate?.future;
        return _ok(snapshot);
      }
      if (path.endsWith('/conversations/chat/messages') && r.method == 'POST') {
        await gate?.future;
        if (failSend)
          return http.Response(
            '{"code":"MESSAGE_STORE_UNAVAILABLE","message":"Try again"}',
            503,
          );
        chatRecentlySent = true;
        return _ok(message('reply'));
      }
      if (path.endsWith('/message-requests')) {
        return _ok(status == 'PENDING' ? [summary] : []);
      }
      if (path.endsWith('/message-requests/chat/accept')) {
        await gate?.future;
        if (failAccept)
          return http.Response(
            '{"code":"DENIED","message":"Not accepted"}',
            403,
          );
        status = 'ACCEPTED';
        return _ok(summary);
      }
      if (path.endsWith('/conversations/chat')) {
        return _ok({
          'conversation': summary,
          'messages': [message('old'), message('latest')],
        });
      }
      if (path.endsWith('/conversations/chat/read')) {
        unreadCount = 0;
        return _ok(summary);
      }
      if (path.endsWith('/users/b')) {
        return _ok({
          'userId': 'b',
          'nickname': 'Recipient',
          'displayName': 'Recipient',
          'isPrivate': false,
          'canInitiateMessage': canInitiate,
        });
      }
      if (path.endsWith('/posts/42'))
        return http.Response(
          '{"code":"NOT_FOUND","message":"Unavailable"}',
          404,
        );
      if (path.endsWith('/posts')) return _ok({'items': []});
      if (path.endsWith('/trips')) return _ok([]);
      return _ok({});
    }),
  );
  Future<void> login() => auth.login(
    email: 'a@example.com',
    password: 'TestPass123!',
    remember: false,
  );
}

void main() {
  test(
    'Unread message indicator uses server counts and clears on read',
    () async {
      final api = _Api()
        ..status = 'ACCEPTED'
        ..unreadCount = 3;
      await api.login();
      final repo = RealDirectMessageRepository(auth: api.auth);
      await repo.refresh();
      expect(repo.hasUnread, isTrue);
      repo.markRead('chat');
      expect(repo.hasUnread, isFalse);
      await Future<void>.delayed(Duration.zero);
      repo.dispose();
      api.auth.dispose();
    },
  );
  testWidgets('Inbox and chat show display name instead of account nickname', (
    tester,
  ) async {
    final api = _Api()
      ..status = 'ACCEPTED'
      ..peerDisplayName = 'Xuân Thu'
      ..peerNickname = 'gomate_thu';
    await api.login();
    final repo = RealDirectMessageRepository(auth: api.auth);
    await repo.refresh();
    expect(repo.conversation('chat')?.title, 'Xuân Thu');
    expect(
      repo.conversation('chat')?.participants.last.displayName,
      'Xuân Thu',
    );
    await tester.pumpWidget(MaterialApp(home: MessageScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Xuân Thu'), findsOneWidget);
    expect(find.text('gomate_thu'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: MessageChatScreen(conversationId: 'chat', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Xuân Thu'), findsOneWidget);
    expect(find.text('gomate_thu'), findsNothing);
    expect(find.text('Đã gửi'), findsOneWidget);
    expect(find.text('Đã xem'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
    api.auth.dispose();
  });

  for (final displayName in <String?>[null, '   ']) {
    test(
      'Missing/blank display name ($displayName) falls back to nickname',
      () async {
        final api = _Api()
          ..status = 'ACCEPTED'
          ..peerDisplayName = displayName
          ..peerNickname = 'gomate_thu';
        await api.login();
        final repo = RealDirectMessageRepository(auth: api.auth);
        await repo.refresh();
        expect(repo.conversation('chat')?.title, 'gomate_thu');
        expect(
          repo.conversation('chat')?.participants.last.displayName,
          'gomate_thu',
        );
        repo.dispose();
        api.auth.dispose();
      },
    );
  }

  test('An explicit chat-local nickname keeps its existing behavior', () {
    const participant = MessageParticipant(
      id: 'b',
      name: 'Xuân Thu',
      nickname: 'Chat alias',
    );
    expect(participant.displayName, 'Chat alias');
  });

  testWidgets(
    'Mounted inbox immediately shows an existing DM above older groups after send ACK',
    (tester) async {
      final api = _Api()
        ..status = 'ACCEPTED'
        ..includeGroup = true;
      await api.login();
      final repo = RealDirectMessageRepository(auth: api.auth);
      await repo.refresh();
      await tester.pumpWidget(
        MaterialApp(home: MessageScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Recipient')).dy,
        greaterThan(tester.getTopLeft(find.text('Older group')).dy),
      );
      await repo.sendTextConfirmed(conversationId: 'chat', text: 'new');
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Recipient')).dy,
        lessThan(tester.getTopLeft(find.text('Older group')).dy),
      );
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
      api.auth.dispose();
    },
  );
  test('Late inbox refresh cannot undo a successful send promotion', () async {
    final api = _Api()
      ..status = 'ACCEPTED'
      ..includeGroup = true;
    await api.login();
    final repo = RealDirectMessageRepository(auth: api.auth);
    await repo.refresh();
    api.inboxGate = Completer<void>();
    final refresh = repo.refresh();
    await Future<void>.delayed(Duration.zero);
    await repo.sendTextConfirmed(conversationId: 'chat', text: 'new');
    expect(repo.mainConversations.first.id, 'chat');
    api.inboxGate!.complete();
    await refresh;
    expect(repo.mainConversations.first.id, 'chat');
    expect(repo.mainConversations.first.lastMessageText, 'reply');
    repo.dispose();
    api.auth.dispose();
  });
  test(
    'Sending existing DM promotes it above older groups only after ACK, without inbox reload',
    () async {
      final api = _Api()
        ..status = 'ACCEPTED'
        ..includeGroup = true;
      await api.login();
      final repo = RealDirectMessageRepository(auth: api.auth);
      await repo.refresh();
      expect(repo.mainConversations.map((c) => c.id), ['group', 'chat']);
      final reads = api.inboxReads;
      api.failSend = true;
      await expectLater(
        repo.sendTextConfirmed(conversationId: 'chat', text: 'new'),
        throwsException,
      );
      expect(repo.mainConversations.first.id, 'group');
      api.failSend = false;
      api.gate = Completer<void>();
      final send = repo.sendTextConfirmed(conversationId: 'chat', text: 'new');
      await Future<void>.delayed(Duration.zero);
      expect(repo.mainConversations.first.id, 'group');
      api.gate!.complete();
      await send;
      expect(repo.mainConversations.map((c) => c.id), ['chat', 'group']);
      expect(repo.mainConversations.first.lastMessageText, 'reply');
      expect(api.inboxReads, reads);
      await repo.refresh();
      expect(repo.mainConversations.first.id, 'chat');
      repo.dispose();
      api.auth.dispose();
    },
  );

  test(
    'Accepting incoming request promotes same conversation above older groups',
    () async {
      final api = _Api()
        ..status = 'PENDING'
        ..requester = false
        ..includeGroup = true;
      await api.login();
      final repo = RealDirectMessageRepository(auth: api.auth);
      await repo.refresh();
      expect(repo.mainConversations.single.id, 'group');
      await repo.acceptPendingConfirmed('chat');
      expect(repo.mainConversations.map((c) => c.id), ['chat', 'group']);
      expect(repo.pendingConversations, isEmpty);
      repo.dispose();
      api.auth.dispose();
    },
  );
  test(
    'Profile parses server canInitiateMessage rather than inferring PUBLIC',
    () async {
      final api = _Api();
      await api.login();
      final search = SearchRepository(auth: api.auth);
      expect((await search.getUserProfile('b')).canInitiateMessage, isFalse);
      api.canInitiate = true;
      expect((await search.getUserProfile('b')).canInitiateMessage, isTrue);
      api.auth.dispose();
    },
  );

  for (final allowed in [false, true]) {
    testWidgets('Profile Message button obeys server flag $allowed', (
      tester,
    ) async {
      final api = _Api()..canInitiate = allowed;
      await api.login();
      await tester.pumpWidget(
        MaterialApp(
          home: PublicProfileScreen(
            userId: 'b',
            repository: SearchRepository(auth: api.auth),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nhắn tin'), allowed ? findsOneWidget : findsNothing);
      await tester.pumpWidget(const SizedBox());
      api.auth.dispose();
    });
  }

  test(
    'Opening and leaving draft never sends or inserts it in either inbox',
    () async {
      final api = _Api();
      await api.login();
      final repo = RealDirectMessageRepository(auth: api.auth);
      await repo.refresh();
      final id = repo.openOrCreateDirectConversationWithPeer(
        contactId: 'b',
        name: 'Recipient',
      );
      await Future<void>.delayed(Duration.zero);
      expect(repo.conversation(id)?.isDraft, isTrue);
      expect(repo.mainConversations, isEmpty);
      expect(repo.pendingConversations, isEmpty);
      repo.discardDraft(id);
      expect(repo.conversation(id), isNull);
      expect(api.creates, 0);
      repo.dispose();
      api.auth.dispose();
    },
  );

  test(
    'First send retry preserves request ID; outgoing PENDING has no recipient actions',
    () async {
      final api = _Api();
      await api.login();
      final repo = RealDirectMessageRepository(auth: api.auth);
      await repo.refresh();
      final id = repo.openOrCreateDirectConversation('b');
      api.failSend = true;
      await expectLater(
        repo.sendTextConfirmed(conversationId: id, text: 'hello'),
        throwsException,
      );
      expect(repo.conversation(id)?.isDraft, isTrue);
      expect(api.creates, 0);
      api.failSend = false;
      await repo.sendTextConfirmed(conversationId: id, text: 'hello');
      expect(api.keys.toSet().length, 1);
      expect(api.creates, 1);
      expect(repo.conversation(id)?.isRequester, isTrue);
      expect(repo.conversation(id)?.isIncomingRequest, isFalse);
      expect(repo.pendingConversations, isEmpty);
      expect(repo.mainConversations, isEmpty);
      await Future<void>.delayed(Duration.zero);
      repo.dispose();
      api.auth.dispose();
    },
  );

  test(
    'Logout discards late first-send response and all prior-session aliases',
    () async {
      final api = _Api();
      await api.login();
      final repo = RealDirectMessageRepository(auth: api.auth);
      await repo.refresh();
      final id = repo.openOrCreateDirectConversation('b');
      api.gate = Completer<void>();
      final sending = repo.sendTextConfirmed(conversationId: id, text: 'hello');
      final assertion = expectLater(sending, throwsException);
      await Future<void>.delayed(Duration.zero);
      await api.auth.clearLocal();
      api.gate!.complete();
      await assertion;
      expect(repo.mainConversations, isEmpty);
      expect(repo.pendingConversations, isEmpty);
      expect(repo.conversation(id), isNull);
      repo.dispose();
      api.auth.dispose();
    },
  );

  testWidgets(
    'Composer waits for ACK, prevents double tap and preserves failed text',
    (tester) async {
      var count = 0;
      final gate = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageChatComposer(
              onSend: (_) async {
                count++;
                await gate.future;
              },
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Keep this text');
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.arrow_up));
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.arrow_up));
      expect(count, 1);
      expect(find.text('Keep this text'), findsOneWidget);
      gate.completeError(StateError('Network error'));
      await tester.pumpAndSettle();
      expect(find.text('Keep this text'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Incoming accept stays in chat and retains loaded history; failed ACK stays pending',
    (tester) async {
      final api = _Api()
        ..status = 'PENDING'
        ..requester = false;
      await api.login();
      final repo = RealDirectMessageRepository(auth: api.auth);
      await repo.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: MessageChatScreen(conversationId: 'chat', repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('old'), findsOneWidget);
      api.failAccept = true;
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(repo.pendingConversations.length, 1);
      expect(find.byType(MessageChatComposer), findsNothing);
      api.failAccept = false;
      ScaffoldMessenger.of(
        tester.element(find.byType(MessageChatScreen)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(repo.pendingConversations, isEmpty);
      expect(repo.mainConversations.length, 1);
      expect(find.byType(MessageChatScreen), findsOneWidget);
      expect(find.byType(MessageChatComposer), findsOneWidget);
      expect(find.text('old'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
      api.auth.dispose();
    },
  );

  test(
    'Reopening contact cannot reuse a previous draft alias to bypass new-contact privacy',
    () async {
      final api = _Api();
      await api.login();
      final repo = RealDirectMessageRepository(auth: api.auth);
      await repo.refresh();
      final firstId = repo.openOrCreateDirectConversation('b');
      await repo.sendTextConfirmed(conversationId: firstId, text: 'Initial');
      repo.discardDraft(firstId);
      api.status = 'ACCEPTED';
      await repo.refresh();
      api.openDenied = true;
      final secondId = repo.openOrCreateDirectConversation('b');
      expect(secondId, isNot(firstId));
      await Future<void>.delayed(Duration.zero);
      expect(repo.conversation(secondId), isNull);
      expect(repo.mainConversations.single.id, 'chat');
      expect(repo.conversation('chat'), isNotNull);
      await Future<void>.delayed(Duration.zero);
      repo.dispose();
      api.auth.dispose();
    },
  );

  testWidgets('Cancel pending delete keeps route and never calls DELETE', (
    tester,
  ) async {
    final api = _Api()
      ..status = 'PENDING'
      ..requester = false;
    await api.login();
    final repo = RealDirectMessageRepository(auth: api.auth);
    await repo.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: MessageChatScreen(conversationId: 'chat', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.trash));
    await tester.pumpAndSettle();
    expect(find.text('Xoá tin nhắn chờ?'), findsOneWidget);
    Navigator.of(tester.element(find.byType(MessageConfirmContent))).pop();
    await tester.pumpAndSettle();
    expect(api.deletes, 0);
    expect(find.byType(MessageChatScreen), findsOneWidget);
    expect(repo.pendingConversations.length, 1);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
    api.auth.dispose();
  });

  testWidgets('Outgoing pending uses existing composer, never Accept/Delete', (
    tester,
  ) async {
    final api = _Api()..status = 'PENDING';
    await api.login();
    final repo = RealDirectMessageRepository(auth: api.auth);
    await repo.refresh();
    final id = repo.openOrCreateDirectConversation('b');
    await tester.pumpWidget(
      MaterialApp(
        home: MessageChatScreen(conversationId: id, repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MessageChatComposer), findsOneWidget);
    expect(find.text('Chấp nhận'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
    api.auth.dispose();
  });

  testWidgets(
    'Only shared Post unavailable page uses matching lock state and return to chat',
    (tester) async {
      final api = _Api();
      await api.login();
      await tester.pumpWidget(
        MaterialApp(
          home: GoMateProfilePostFeedScreen(
            posts: const [],
            remote: true,
            sharedReference: true,
            postId: 42,
            repository: PostRepository(auth: api.auth),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bài viết không khả dụng'), findsOneWidget);
      expect(find.text('Quay lại tin nhắn'), findsOneWidget);
      expect(find.byIcon(LucideIcons.lock_keyhole), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      api.auth.dispose();
    },
  );
}
