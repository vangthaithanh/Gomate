import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/session_store.dart';
import 'package:gomate/features/messages/data/message_repository.dart';
import 'package:gomate/features/messages/screens/group_management_screen.dart';
import 'package:gomate/features/trip/data/trip_repository.dart';
import 'package:gomate/features/trip/screens/trip_screen.dart';
import 'package:gomate/features/map/state/map_ui_session.dart';
import 'package:gomate/features/messages/models/message_models.dart';
import 'package:gomate/features/trip/models/trip_ui_models.dart';

class _Store implements SessionStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
}

class _Fixture {
  final counts = <String, int>{};
  bool failDetail = false;
  int detailErrorStatus = 503;
  List<Map<String, Object?>> detailMessages = [];
  Completer<void>? detailGate;
  Completer<void>? listGate;
  Completer<void>? mutationGate;
  bool failMutation = false;
  bool transferred = false;
  bool archived = false;
  late final AuthService auth;
  late final RealTripRepository trips;
  late final RealDirectMessageRepository messages;

  static const members = [
    {'userId': 'leader', 'displayName': 'Leader', 'role': 'LEADER'},
    {'userId': 'member-b', 'displayName': 'Member B', 'role': 'MEMBER'},
    {'userId': 'member-c', 'displayName': 'Member C', 'role': 'MEMBER'},
    {'userId': 'member-d', 'displayName': 'Member D', 'role': 'MEMBER'},
  ];
  List<Map<String, Object?>> get currentMembers => members
      .map(
        (m) => <String, Object?>{
          ...m,
          if (transferred)
            'role': m['userId'] == 'member-b' ? 'LEADER' : 'MEMBER',
        },
      )
      .toList();

  Map<String, Object?> get summary => {
    'id': 'trip',
    'title': 'Four member Trip',
    'tripType': 'GROUP',
    'startDate': '2026-10-16',
    'endDate': '2026-10-17',
    'memberCount': 4,
    'stopCount': 0,
    'pinned': false,
    'currentUserRole': transferred ? 'MEMBER' : 'LEADER',
    'linkedConversationId': 'chat',
  };

  Map<String, Object?> get conversation => {
    'conversationId': 'chat',
    'type': 'GROUP',
    'displayName': 'Empty group chat',
    'status': 'ACCEPTED',
    'linkedTripId': 'trip',
    'members': currentMembers,
    'lastMessage': null,
    'unreadCount': 0,
  };

  Future<void> start() async {
    auth = AuthService(
      store: _Store(),
      baseUrl: 'http://fixture.invalid/api/v1',
      client: MockClient((request) async {
        final path = request.url.path;
        counts.update(path, (n) => n + 1, ifAbsent: () => 1);
        Object? response;
        if (path == '/api/v1/auth/login') {
          response = {
            'accessToken': 'fixture-access',
            'refreshToken': 'fixture-refresh',
            'user': {
              'id': 'leader',
              'displayName': 'Leader',
              'onboardingCompleted': true,
            },
          };
        } else if (path == '/api/v1/conversations') {
          await listGate?.future;
          response = archived ? [] : [conversation];
        } else if (path == '/api/v1/message-requests') {
          response = [];
        } else if (path == '/api/v1/trips') {
          response = archived ? [] : [summary];
        } else if (path == '/api/v1/trips/trip/leader' ||
            (path == '/api/v1/trips/trip' && request.method == 'DELETE')) {
          await mutationGate?.future;
          if (failMutation) {
            return http.Response('{"message":"fixture failure"}', 503);
          }
          if (path.endsWith('/leader')) {
            expect(request.method, 'PATCH');
            expect(jsonDecode(request.body), {'targetUserId': 'member-b'});
            transferred = true;
            response = {
              ...summary,
              'members': currentMembers,
              'stops': [],
              'pendingInvitations': [],
            };
          } else {
            archived = true;
            return http.Response('', 204);
          }
        } else if (path == '/api/v1/trips/trip') {
          response = {
            ...summary,
            'members': currentMembers,
            'stops': [],
            'pendingInvitations': [
              {
                'invitationId': 'invite',
                'inviteeUserId': 'invitee',
                'inviteeDisplayName': 'Pending person',
              },
            ],
          };
        } else if (path == '/api/v1/conversations/chat') {
          await detailGate?.future;
          if (failDetail) {
            return http.Response(
              jsonEncode({
                'code': 'UPSTREAM_ERROR',
                'message': 'fixture detail failure',
              }),
              detailErrorStatus,
            );
          }
          response = {'conversation': conversation, 'messages': detailMessages};
        } else if (path.endsWith('/read') || path == '/api/v1/auth/logout') {
          return http.Response('', 204);
        } else {
          throw StateError('Unexpected fixture request: $path');
        }
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await auth.login(
      email: 'fixture@example.test',
      password: 'FixtureOnly123!',
      remember: false,
    );
    trips = RealTripRepository(auth: auth);
    messages = RealDirectMessageRepository(auth: auth, trips: trips);
    await flush();
  }

  static Future<void> flush() async {
    for (var i = 0; i < 15; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void dispose() {
    messages.dispose();
    auth.dispose();
  }
}

class _NoisyPending extends MessageRepository {
  int loads = 0;
  bool fail = false;
  Completer<List<MessageGroupInvite>>? holdNext;
  static const invitation = MessageGroupInvite(
    contactId: 'invitee',
    name: 'Pending person',
    subtitle: '',
    invitedById: 'leader',
  );
  List<MessageGroupInvite> pending = [invitation];
  void emit() => notifyListeners();

  @override
  String get currentUserId => 'leader';
  @override
  MessageConversation? conversation(String id) => MessageConversation(
    id: id,
    linkedItineraryId: 'trip',
    title: 'Group',
    type: MessageConversationType.group,
    participants: const [
      MessageParticipant(
        id: 'leader',
        name: 'Leader',
        role: MessageGroupRole.leader,
      ),
      MessageParticipant(id: 'member', name: 'Member'),
    ],
    messages: const [],
    lastSenderId: '',
    lastMessageText: '',
    lastMessageTime: '',
  );

  @override
  Future<List<MessageGroupInvite>> fetchPendingGroupInvites(String id) async {
    loads++;
    final hold = holdNext;
    holdNext = null;
    notifyListeners();
    if (hold != null) return hold.future;
    if (fail) throw StateError('fixture pending failure');
    return List.of(pending);
  }

  @override
  Future<void> cancelGroupInvite(String id, String contactId) async {
    pending = [];
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'real transfer endpoint waits for ACK and refreshes same chat roles',
    () async {
      final fixture = _Fixture();
      await fixture.start();
      addTearDown(fixture.dispose);
      fixture.mutationGate = Completer<void>();
      final pending = fixture.messages.transferGroupLeader('chat', 'member-b');
      await _Fixture.flush();
      expect(fixture.messages.groupRole('chat'), MessageGroupRole.leader);
      fixture.mutationGate!.complete();
      await pending;
      expect(fixture.messages.groupRole('chat'), MessageGroupRole.member);
      expect(
        fixture.messages.conversation('chat')!.roleOf('member-b'),
        MessageGroupRole.leader,
      );
      expect(fixture.messages.conversation('chat')!.participants.length, 4);
      expect(fixture.messages.inviteableItineraries, isEmpty);
      expect(
        GoMateMapUiSession.availableTrips.single.currentUserRole,
        TripAccessRole.member,
      );
      GoMateMapUiSession.removeTrip('trip');
    },
  );

  for (final fail in [false, true]) {
    test(
      'real group archive purges only after DELETE ACK, failure=$fail',
      () async {
        final fixture = _Fixture();
        await fixture.start();
        addTearDown(fixture.dispose);
        GoMateMapUiSession.registerTrips([await fixture.trips.detail('trip')]);
        GoMateMapUiSession.pinTrip(GoMateMapUiSession.availableTrips.single);
        fixture.failMutation = fail;
        fixture.mutationGate = Completer<void>();
        final pending = fixture.messages.deleteGroupAndItinerary('chat');
        final checked = fail
            ? expectLater(pending, throwsA(anything))
            : pending;
        await _Fixture.flush();
        expect(fixture.messages.mainConversations.length, 1);
        expect(GoMateMapUiSession.pinnedTrip, isNotNull);
        fixture.mutationGate!.complete();
        await checked;
        expect(fixture.messages.mainConversations.length, fail ? 1 : 0);
        expect(GoMateMapUiSession.availableTrips.length, fail ? 1 : 0);
        expect(GoMateMapUiSession.pinnedTrip == null, !fail);
        GoMateMapUiSession.removeTrip('trip');
      },
    );
  }
  test('list uses API memberCount before any detail request', () async {
    final fixture = _Fixture();
    await fixture.start();
    addTearDown(fixture.dispose);
    final trip = (await fixture.trips.list()).single;
    expect(trip.members, isEmpty);
    expect(trip.memberCount, 4);
    expect(trip.copyWith(isActive: true).memberCount, 4);
    expect(
      trip
          .copyWith(
            members: const [TripMemberUi(id: 'leader', name: 'Leader')],
          )
          .memberCount,
      1,
    );
    final detail = await fixture.trips.detail('trip');
    expect(detail.memberCount, 4);
    expect(detail.pendingInvitees.length, 1);
    expect(
      detail.copyWith(members: detail.members.take(2).toList()).memberCount,
      2,
    );
    // List mapping above did not have to fetch any per-trip details.
    expect(fixture.counts['/api/v1/trips/trip'], 1);
  });

  test(
    'empty chat is loaded once despite notifications reading it again',
    () async {
      final fixture = _Fixture();
      await fixture.start();
      addTearDown(fixture.dispose);
      var signals = 0;
      void listener() {
        // Bound the old bug so the red test cannot hang the runner.
        if (++signals < 6) fixture.messages.conversation('chat');
      }

      fixture.messages.addListener(listener);
      fixture.messages.conversation('chat');
      await _Fixture.flush();
      fixture.messages.removeListener(listener);
      expect(fixture.counts['/api/v1/conversations/chat'], 1);
      expect(fixture.messages.conversation('chat')!.messages, isEmpty);
    },
  );

  test(
    'simultaneous reads and markRead share one in-flight chat detail',
    () async {
      final fixture = _Fixture();
      await fixture.start();
      addTearDown(fixture.dispose);
      fixture.detailGate = Completer<void>();
      for (var i = 0; i < 20; i++) {
        fixture.messages.conversation('chat');
        fixture.messages.markRead('chat');
      }
      await _Fixture.flush();
      expect(fixture.counts['/api/v1/conversations/chat'], 1);
      fixture.detailGate!.complete();
      await _Fixture.flush();
      for (var i = 0; i < 20; i++) {
        fixture.messages.conversation('chat');
      }
      await _Fixture.flush();
      expect(fixture.counts['/api/v1/conversations/chat'], 1);
    },
  );

  test(
    'detail failure does not retry on read; explicit refresh permits retry',
    () async {
      final fixture = _Fixture()..failDetail = true;
      await fixture.start();
      addTearDown(fixture.dispose);
      fixture.messages.conversation('chat');
      await _Fixture.flush();
      expect(fixture.messages.error, contains('fixture detail failure'));
      for (var i = 0; i < 20; i++) {
        fixture.messages.conversation('chat');
      }
      await _Fixture.flush();
      expect(fixture.counts['/api/v1/conversations/chat'], 1);
      fixture.failDetail = false;
      await fixture.messages.refresh();
      fixture.messages.conversation('chat');
      await _Fixture.flush();
      expect(fixture.counts['/api/v1/conversations/chat'], 2);
      expect(fixture.messages.error, isNull);
    },
  );

  test(
    'late detail cannot restore forgotten membership or notify after disposal',
    () async {
      final fixture = _Fixture();
      await fixture.start();
      fixture.detailGate = Completer<void>();
      fixture.messages.conversation('chat');
      await _Fixture.flush();
      fixture.messages.forgetTripMembership('trip');
      fixture.dispose();
      fixture.detailGate!.complete();
      await _Fixture.flush();
      expect(fixture.messages.mainConversations, isEmpty);
    },
  );

  test(
    'explicit read still fetches new messages after an empty chat was cached',
    () async {
      final fixture = _Fixture();
      await fixture.start();
      addTearDown(fixture.dispose);
      fixture.messages.conversation('chat');
      await _Fixture.flush();
      fixture.detailMessages = [
        {
          'messageId': 'new-message',
          'senderUserId': 'member-b',
          'text': 'New message',
          'createdAt': '2026-10-16T00:00:00Z',
        },
      ];
      fixture.messages.markRead('chat');
      await _Fixture.flush();
      expect(
        fixture.messages.conversation('chat')!.messages.single.text,
        'New message',
      );
      expect(fixture.counts['/api/v1/conversations/chat'], 2);
    },
  );

  test(
    'permission loss invalidates refresh without leaving loading stuck',
    () async {
      final fixture = _Fixture();
      await fixture.start();
      addTearDown(fixture.dispose);
      fixture.listGate = Completer<void>();
      final refreshing = fixture.messages.refresh();
      fixture.failDetail = true;
      fixture.detailErrorStatus = 404;
      fixture.messages.markRead('chat');
      await _Fixture.flush();
      expect(fixture.messages.loading, isFalse);
      expect(fixture.messages.conversation('chat'), isNull);
      fixture.listGate!.complete();
      await refreshing;
      expect(fixture.messages.loading, isFalse);
      expect(fixture.messages.mainConversations, isEmpty);
    },
  );

  test('logout clears cached conversations and rejects late detail', () async {
    final fixture = _Fixture();
    await fixture.start();
    addTearDown(fixture.dispose);
    fixture.detailGate = Completer<void>();
    fixture.messages.conversation('chat');
    await _Fixture.flush();
    await fixture.auth.logout();
    fixture.detailGate!.complete();
    await _Fixture.flush();
    expect(fixture.messages.mainConversations, isEmpty);
    expect(fixture.messages.conversation('chat'), isNull);
  });

  testWidgets('pending load tolerates synchronous repository notifications', (
    tester,
  ) async {
    final repository = _NoisyPending();
    final gate = Completer<List<MessageGroupInvite>>();
    repository.holdNext = gate;
    await tester.pumpWidget(
      MaterialApp(
        home: RoleAwareGroupMembersScreen(
          conversationId: 'chat',
          repository: repository,
        ),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    repository.emit();
    repository.emit();
    expect(repository.loads, 1);
    gate.complete([_NoisyPending.invitation]);
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Pending person'), findsOneWidget);
    expect(repository.loads, 1);
    await tester.pumpWidget(const SizedBox());
    repository.dispose();
  });

  testWidgets(
    'cancel supersedes an in-flight pending load without a stuck spinner',
    (tester) async {
      final repository = _NoisyPending();
      await tester.pumpWidget(
        MaterialApp(
          home: RoleAwareGroupMembersScreen(
            conversationId: 'chat',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final stale = Completer<List<MessageGroupInvite>>();
      repository.holdNext = stale;
      await tester.tap(find.text('Huỷ lời mời'));
      await tester.pumpAndSettle();
      expect(repository.loads, 3);
      expect(find.text('Pending person'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      stale.complete([_NoisyPending.invitation]);
      await tester.pumpAndSettle();
      expect(find.text('Pending person'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      repository.dispose();
    },
  );

  testWidgets('pending API error stops loading and retry works', (
    tester,
  ) async {
    final repository = _NoisyPending()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: RoleAwareGroupMembersScreen(
          conversationId: 'chat',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('fixture pending failure'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Pending person'), findsOneWidget);
    expect(repository.loads, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    repository.dispose();
  });

  testWidgets(
    'Group Members with empty chat settles and displays pending invitation',
    (tester) async {
      final fixture = _Fixture();
      await tester.runAsync(fixture.start);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: RoleAwareGroupMembersScreen(
            conversationId: 'chat',
            repository: fixture.messages,
          ),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
      expect(find.text('Lời mời đang chờ'), findsOneWidget);
      expect(find.text('Pending person'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(fixture.counts['/api/v1/conversations/chat'], 1);
      final previous = Map.of(fixture.counts);
      await tester.pump(const Duration(seconds: 2));
      expect(fixture.counts, previous);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Trip list displays API member count immediately without opening detail',
    (tester) async {
      final fixture = _Fixture();
      await tester.runAsync(fixture.start);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: TripScreen(
            tripRepository: fixture.trips,
            messageRepository: fixture.messages,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Four member Trip'), findsOneWidget);
      expect(find.text('4 thành viên'), findsOneWidget);
      expect(find.text('1 thành viên'), findsNothing);
      expect(fixture.counts['/api/v1/trips/trip'], isNull);
      expect(GoMateMapUiSession.availableTrips.single.memberCount, 4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      GoMateMapUiSession.removeTrip('trip');
    },
  );
}
