import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomate/features/map/state/map_ui_session.dart';
import 'package:gomate/features/messages/data/message_repository.dart';
import 'package:gomate/features/messages/models/message_models.dart';
import 'package:gomate/features/messages/screens/group_management_screen.dart';
import 'package:gomate/features/trip/data/trip_repository.dart';
import 'package:gomate/features/trip/models/trip_ui_models.dart';
import 'package:gomate/features/trip/screens/trip_detail_screen.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/features/trip/location/trip_location_realtime_service.dart';
import 'package:http/http.dart' as http;

const active = TripUi(
  id: 'lifecycle',
  title: 'Trip lifecycle',
  days: 2,
  destination: 'Test',
  isGroup: true,
  conversationId: 'chat',
  currentUserRole: TripAccessRole.leader,
  places: [TripPlaceUi(id: 'stop', placeId: '42', name: 'Place', day: 1)],
  members: [
    TripMemberUi(id: 'a', name: 'Leader', isOwner: true),
    TripMemberUi(id: 'b', name: 'Member'),
  ],
);

class _Trips implements RealTripRepository {
  _Trips(this.value);
  TripUi value;
  @override
  Future<TripUi> detail(String id) async => value;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Messages extends MessageRepository {
  @override
  String get currentUserId => 'a';
  @override
  Future<void> refresh() async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _RosterMessages extends MessageRepository {
  MessageConversation? item = const MessageConversation(
    id: 'chat',
    type: MessageConversationType.group,
    title: 'Trip',
    linkedItineraryId: 'lifecycle',
    participants: [
      MessageParticipant(
        id: 'a',
        name: 'Roster leader',
        nickname: 'roster_leader',
        role: MessageGroupRole.leader,
      ),
      MessageParticipant(
        id: 'b',
        name: 'Roster member',
        nickname: 'roster_member',
      ),
    ],
    messages: [],
    lastSenderId: '',
    lastMessageText: '',
    lastMessageTime: '',
  );
  @override
  String get currentUserId => 'a';
  @override
  MessageConversation? conversation(String id) => item;
  @override
  Future<List<MessageGroupInvite>> fetchPendingGroupInvites(String id) async =>
      [];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  void closeChat() {
    item = null;
    notifyListeners();
  }
}

class _StreamAuth extends AuthService {
  String? openedPath;
  @override
  Future<http.StreamedResponse> openEventStream(
    http.Client client, {
    String path = '/notifications/stream',
  }) async {
    openedPath = path;
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          'event:ready\ndata:{}\n\nevent:tripUnavailable\ndata:{"eventKind":"tripUnavailable","tripId":"trip"}\n\n',
        ),
      ),
      200,
    );
  }
}

class _MessageAuth extends AuthService {
  @override
  bool get signedIn => true;
  @override
  Map<String, dynamic>? get user => {'id': 'a'};
  @override
  Future<Object?> requestJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (path == '/message-requests') return [];
    if (path == '/conversations') {
      return [
        {
          'conversationId': 'chat',
          'type': 'GROUP',
          'displayName': 'Trip',
          'status': 'ACCEPTED',
          'linkedTripId': active.id,
        },
        {
          'conversationId': 'direct',
          'type': 'DIRECT',
          'status': 'ACCEPTED',
          'peer': {'userId': 'b', 'displayName': 'B'},
        },
      ];
    }
    if (path == '/trips') {
      return [
        {
          'id': active.id,
          'title': 'Trip',
          'memberCount': 2,
          'currentUserRole': 'LEADER',
        },
      ];
    }
    throw StateError('Unexpected request $path');
  }
}

void main() {
  setUp(GoMateMapUiSession.clearUserState);
  tearDown(GoMateMapUiSession.clearUserState);
  testWidgets('Unpin keeps current roster and leader selection controls', (
    tester,
  ) async {
    final repo = _RosterMessages();
    GoMateMapUiSession.updateTrip(active);
    GoMateMapUiSession.pinTrip(active);
    await tester.pumpWidget(
      MaterialApp(
        home: RoleAwareGroupMembersScreen(
          conversationId: 'chat',
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    GoMateMapUiSession.clearPinnedTrip();
    await tester.pumpAndSettle();
    expect(find.text('Roster leader'), findsOneWidget);
    expect(find.text('Roster member'), findsOneWidget);
    expect(find.byIcon(LucideIcons.plus), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
  });
  test(
    'Unpin and ordinary Trip refresh never remove GROUP chat or DM',
    () async {
      final auth = _MessageAuth(),
          repo = RealDirectMessageRepository(auth: _MessageAuth());
      await repo.refresh();
      GoMateMapUiSession.updateTrip(active);
      GoMateMapUiSession.pinTrip(active);
      GoMateMapUiSession.clearPinnedTrip();
      expect(repo.mainConversations.length, 2);
      expect(repo.inviteableItineraries.length, 1);
      await repo.refresh();
      expect(repo.mainConversations.length, 2);
      repo.dispose();
      auth.dispose();
    },
  );
  test(
    'SSE parser accepts minimal unavailable signal without journey state/GPS',
    () async {
      final auth = _StreamAuth(),
          client = SseTripLocationEventClient(_StreamAuth());
      final signals = await client.connect('trip').toList();
      expect(signals.length, 2);
      expect(signals.last.tripId, 'trip');
      expect(signals.last.unavailable, true);
      expect(signals.last.userId, isNull);
      client.disconnect();
      auth.dispose();
    },
  );
  test('Edit/delete/leave/chat depend on role and membership, not pin', () {
    for (final pinned in [true, false]) {
      final leader = active.copyWith(isActive: pinned);
      expect(leader.canEditTrip, true);
      expect(leader.hasChat, true);
      expect(leader.canDeleteTrip, true);
      expect(leader.canLeaveTrip, false);
      final member = leader.copyWith(currentUserRole: TripAccessRole.member);
      expect(member.canEditTrip, false);
      expect(member.canDeleteTrip, false);
      expect(member.canLeaveTrip, true);
      expect(member.hasChat, true);
    }
  });
  test(
    'Stale list/detail cannot replace another explicitly acknowledged pin',
    () {
      GoMateMapUiSession.registerTrips([active]);
      GoMateMapUiSession.pinTrip(active.copyWith(id: 'other'));
      GoMateMapUiSession.updateTrip(active.copyWith(isActive: true));
      GoMateMapUiSession.registerTrips([active.copyWith(isActive: true)]);
      expect(GoMateMapUiSession.pinnedTrip?.id, 'other');
      GoMateMapUiSession.clearPinnedTrip(tripId: active.id);
      expect(GoMateMapUiSession.pinnedTrip?.id, 'other');
    },
  );
  test('Unpin preserves stops and pending add flow', () {
    GoMateMapUiSession.updateTrip(active);
    GoMateMapUiSession.pinTrip(active);
    GoMateMapUiSession.requestAddPlaceFromDetail(placeId: '42', trip: active);
    GoMateMapUiSession.clearPinnedTrip();
    expect(GoMateMapUiSession.consumeAddPlaceRequest()?.placeId, '42');
    expect(GoMateMapUiSession.availableTrips.single.places.length, 1);
  });
  for (final role in [TripAccessRole.leader, TripAccessRole.member]) {
    testWidgets(
      'No Start/Complete/Cancel/Share controls for $role; existing actions preserved',
      (tester) async {
        final repo = _Trips(active.copyWith(currentUserRole: role));
        await tester.pumpWidget(
          MaterialApp(
            home: TripDetailScreen(
              trip: repo.value,
              tripRepository: repo,
              messageRepository: _Messages(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Bắt đầu lịch trình'), findsNothing);
        expect(find.text('Kết thúc lịch trình'), findsNothing);
        expect(find.text('Chia sẻ vị trí'), findsNothing);
        expect(find.text('Tin nhắn'), findsOneWidget);
        await tester.tap(find.byIcon(LucideIcons.ellipsis_vertical));
        await tester.pumpAndSettle();
        expect(find.text('Ghim lịch trình'), findsOneWidget);
        expect(find.text('Hủy lịch trình'), findsNothing);
        expect(
          find.text(
            role == TripAccessRole.leader ? 'Xoá lịch trình' : 'Rời lịch trình',
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
