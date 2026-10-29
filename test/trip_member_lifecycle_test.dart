import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomate/features/map/state/map_ui_session.dart';
import 'package:gomate/core/network/api_exception.dart';
import 'package:gomate/features/messages/data/message_repository.dart';
import 'package:gomate/features/messages/models/message_models.dart';
import 'package:gomate/features/messages/screens/group_management_screen.dart';
import 'package:gomate/features/messages/screens/message_detail_screen.dart';
import 'package:gomate/features/trip/data/trip_repository.dart';
import 'package:gomate/features/trip/models/trip_ui_models.dart';
import 'package:gomate/features/trip/screens/trip_detail_screen.dart';

TripUi _trip({bool leader = false}) => TripUi(
  id: 'trip',
  title: 'Lifecycle Trip',
  days: 2,
  destination: 'Test',
  isGroup: true,
  isActive: true,
  conversationId: 'chat',
  currentUserRole: leader ? TripAccessRole.leader : TripAccessRole.member,
  members: const [
    TripMemberUi(id: 'a', name: 'Leader', isOwner: true),
    TripMemberUi(id: 'b', name: 'Member B'),
    TripMemberUi(id: 'c', name: 'Member C'),
  ],
);

class _Trips implements RealTripRepository {
  int leaves = 0;
  int deletes = 0;
  bool fail = false;
  bool denied = false;
  bool leader = false;
  Completer<void>? gate;
  @override
  Future<TripUi> detail(String tripId) async {
    if (denied) {
      throw const ApiException(404, 'NOT_FOUND', 'No longer a member');
    }
    return _trip(leader: leader);
  }

  @override
  Future<void> leave(String tripId) async {
    leaves++;
    await gate?.future;
    if (fail) throw StateError('fixture network failure');
  }

  @override
  Future<void> delete(String tripId) async {
    deletes++;
    await gate?.future;
    if (fail) throw StateError('fixture archive failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Messages extends MessageRepository {
  _Messages({this.leader = true});
  final bool leader;
  bool fail = false;
  Completer<void>? gate;
  int removals = 0;
  int leaves = 0;
  int refreshes = 0;
  int transfers = 0;
  int archives = 0;
  bool partialFail = false;
  late MessageConversation? item = MessageConversation(
    id: 'chat',
    linkedItineraryId: 'trip',
    type: MessageConversationType.group,
    title: 'Lifecycle Trip',
    participants: const [
      MessageParticipant(
        id: 'a',
        name: 'Leader',
        role: MessageGroupRole.leader,
      ),
      MessageParticipant(id: 'b', name: 'Member B'),
      MessageParticipant(id: 'c', name: 'Member C'),
    ],
    messages: const [],
    lastSenderId: '',
    lastMessageText: '',
    lastMessageTime: '',
  );
  @override
  String get currentUserId => leader ? 'a' : 'b';
  @override
  MessageConversation? conversation(String id) => item;
  @override
  Future<List<MessageGroupInvite>> fetchPendingGroupInvites(String id) async =>
      [];
  @override
  Future<void> refresh() async {
    refreshes++;
  }

  @override
  Future<void> removeGroupMembers(String id, Iterable<String> ids) async {
    removals++;
    await gate?.future;
    if (fail) throw StateError('fixture network failure');
    if (partialFail) {
      partialFail = false;
      final removed = ids.first;
      item = item!.copyWith(
        participants: item!.participants.where((p) => p.id != removed).toList(),
      );
      notifyListeners();
      throw StateError('Later request failed after one ACK');
    }
    item = item!.copyWith(
      participants: item!.participants
          .where((p) => !ids.contains(p.id))
          .toList(),
    );
    notifyListeners();
  }

  @override
  Future<void> leaveGroup(String id) async {
    leaves++;
    await gate?.future;
    if (fail) throw StateError('fixture network failure');
    item = null;
    GoMateMapUiSession.removeTrip('trip');
    notifyListeners();
  }

  @override
  Future<void> transferGroupLeader(String id, String target) async {
    transfers++;
    await gate?.future;
    if (fail) throw StateError('fixture transfer failure');
    item = item!.copyWith(
      participants: item!.participants
          .map(
            (p) => MessageParticipant(
              id: p.id,
              name: p.name,
              role: p.id == target
                  ? MessageGroupRole.leader
                  : MessageGroupRole.member,
            ),
          )
          .toList(),
    );
    notifyListeners();
  }

  @override
  Future<void> deleteGroupAndItinerary(String id) async {
    archives++;
    await gate?.future;
    if (fail) throw StateError('fixture archive failure');
    item = null;
    GoMateMapUiSession.removeTrip('trip');
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _open(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => screen)),
            child: const Text('Open fixture'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open fixture'));
  await tester.pumpAndSettle();
}

Future<void> _confirmTripLeave(WidgetTester tester) async {
  await tester.tap(find.byIcon(LucideIcons.ellipsis_vertical));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Rời lịch trình'));
  await tester.pumpAndSettle();
  expect(find.text('Rời lịch trình?'), findsOneWidget);
  await tester.tap(find.text('Xác nhận'));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  tearDown(() => GoMateMapUiSession.removeTrip('trip'));

  testWidgets('LF01 LF03 key appears for exactly one current MEMBER only', (
    tester,
  ) async {
    final messages = _Messages();
    await _open(
      tester,
      RoleAwareGroupMembersScreen(conversationId: 'chat', repository: messages),
    );
    expect(find.byKey(const ValueKey('transfer-leader')), findsNothing);
    await tester.tap(find.byIcon(LucideIcons.copy));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leader').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('transfer-leader')), findsNothing);
    await tester.tap(find.text('Member B').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('transfer-leader')), findsOneWidget);
    await tester.tap(find.text('Member C').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('transfer-leader')), findsNothing);
  });

  testWidgets(
    'LF04 LF05 transfer waits for ACK, preserves group, loses leader controls',
    (tester) async {
      final messages = _Messages()..gate = Completer<void>();
      await _open(
        tester,
        RoleAwareGroupMembersScreen(
          conversationId: 'chat',
          repository: messages,
        ),
      );
      await tester.tap(find.byIcon(LucideIcons.copy));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Member B').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('transfer-leader')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Chuyển trưởng nhóm?'), findsOneWidget);
      await tester.tap(find.text('Xác nhận'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(messages.transfers, 1);
      expect(messages.item!.roleOf('a'), MessageGroupRole.leader);
      expect(messages.leaves, 0);
      messages.gate!.complete();
      await tester.pumpAndSettle();
      expect(messages.item!.id, 'chat');
      expect(messages.item!.roleOf('a'), MessageGroupRole.member);
      expect(messages.item!.roleOf('b'), MessageGroupRole.leader);
      expect(find.byIcon(LucideIcons.copy), findsNothing);
      expect(find.byIcon(LucideIcons.plus), findsNothing);
      expect(find.byKey(const ValueKey('transfer-leader')), findsNothing);
      expect(messages.leaves, 0);
    },
  );

  testWidgets('LF04 transfer failure keeps original leader and selection', (
    tester,
  ) async {
    final messages = _Messages()..fail = true;
    await _open(
      tester,
      RoleAwareGroupMembersScreen(conversationId: 'chat', repository: messages),
    );
    await tester.tap(find.byIcon(LucideIcons.copy));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Member B').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transfer-leader')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(messages.item!.roleOf('a'), MessageGroupRole.leader);
    expect(find.byKey(const ValueKey('transfer-leader')), findsOneWidget);
    expect(find.text('Đã chuyển trưởng nhóm'), findsNothing);
  });

  testWidgets(
    'LF07 cancelling archive confirmation never sends API or fake success',
    (tester) async {
      final messages = _Messages();
      await _open(
        tester,
        MessageDetailScreen(conversationId: 'chat', repository: messages),
      );
      await tester.tap(find.text('Xoá nhóm'));
      await tester.pumpAndSettle();
      expect(find.text('Xoá nhóm?'), findsOneWidget);
      Navigator.of(tester.element(find.text('Xoá nhóm?'))).pop();
      await tester.pumpAndSettle();
      expect(messages.archives, 0);
      expect(find.byType(MessageDetailScreen), findsOneWidget);
      expect(find.textContaining('Đã xoá nhóm'), findsNothing);
    },
  );

  testWidgets('LF08 chat archive failure leaves active group visible', (
    tester,
  ) async {
    final messages = _Messages()..fail = true;
    await _open(
      tester,
      MessageDetailScreen(conversationId: 'chat', repository: messages),
    );
    await tester.tap(find.text('Xoá nhóm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(messages.archives, 1);
    expect(messages.item, isNotNull);
    expect(find.byType(MessageDetailScreen), findsOneWidget);
    expect(find.textContaining('Đã xoá nhóm'), findsNothing);
  });

  for (final fail in [false, true]) {
    testWidgets(
      'LF07 LF08 LF09 LF10 Trip archive waits for ACK, failure=$fail',
      (tester) async {
        final trips = _Trips()
          ..leader = true
          ..fail = fail
          ..gate = Completer<void>();
        GoMateMapUiSession.registerTrips([_trip(leader: true)]);
        GoMateMapUiSession.pinTrip(_trip(leader: true));
        await _open(
          tester,
          TripDetailScreen(
            trip: _trip(leader: true),
            tripRepository: trips,
            messageRepository: _Messages(),
          ),
        );
        await tester.tap(find.byIcon(LucideIcons.ellipsis_vertical));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xoá lịch trình'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xác nhận'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(trips.deletes, 1);
        expect(GoMateMapUiSession.availableTrips.length, 1);
        expect(GoMateMapUiSession.pinnedTrip, isNotNull);
        trips.gate!.complete();
        await tester.pumpAndSettle();
        expect(GoMateMapUiSession.availableTrips.length, fail ? 1 : 0);
        expect(GoMateMapUiSession.pinnedTrip == null, !fail);
        expect(
          find.byType(TripDetailScreen),
          fail ? findsOneWidget : findsNothing,
        );
      },
    );
  }

  testWidgets(
    'F01/F05/F07/F08 leave waits for ACK then clears protected Trip and pin',
    (tester) async {
      final trips = _Trips()..gate = Completer<void>();
      final messages = _Messages(leader: false);
      GoMateMapUiSession.registerTrips([_trip()]);
      await _open(
        tester,
        TripDetailScreen(
          trip: _trip(),
          tripRepository: trips,
          messageRepository: messages,
        ),
      );
      await _confirmTripLeave(tester);
      expect(trips.leaves, 1);
      expect(find.byType(TripDetailScreen), findsOneWidget);
      expect(GoMateMapUiSession.availableTrips.length, 1);
      trips.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(TripDetailScreen), findsNothing);
      expect(GoMateMapUiSession.availableTrips, isEmpty);
      expect(GoMateMapUiSession.pinnedTrip, isNull);
    },
  );

  testWidgets('F06 leave failure keeps Trip and has no fake success', (
    tester,
  ) async {
    final trips = _Trips()..fail = true;
    GoMateMapUiSession.registerTrips([_trip()]);
    await _open(
      tester,
      TripDetailScreen(
        trip: _trip(),
        tripRepository: trips,
        messageRepository: _Messages(leader: false),
      ),
    );
    await _confirmTripLeave(tester);
    await tester.pumpAndSettle();
    expect(find.byType(TripDetailScreen), findsOneWidget);
    expect(GoMateMapUiSession.availableTrips.length, 1);
    expect(find.text('Đã rời lịch trình'), findsNothing);
    expect(find.textContaining('Không thể rời lịch trình'), findsOneWidget);
  });

  testWidgets('F02 Leader does not see normal leave action', (tester) async {
    await _open(
      tester,
      TripDetailScreen(
        trip: _trip(leader: true),
        tripRepository: _Trips()..leader = true,
        messageRepository: _Messages(),
      ),
    );
    await tester.tap(find.byIcon(LucideIcons.ellipsis_vertical));
    await tester.pumpAndSettle();
    expect(find.text('Rời lịch trình'), findsNothing);
  });

  testWidgets(
    'F03/F05/F07/F09 remove waits for ACK and refreshes roster once',
    (tester) async {
      final messages = _Messages()..gate = Completer<void>();
      await _open(
        tester,
        RoleAwareGroupMembersScreen(
          conversationId: 'chat',
          repository: messages,
        ),
      );
      await tester.tap(find.byIcon(LucideIcons.copy));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Member B').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.trash));
      await tester.pumpAndSettle();
      expect(find.text('Xoá (1) thành viên'), findsOneWidget);
      await tester.tap(find.text('Xác nhận'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(messages.removals, 1);
      expect(find.text('Member B'), findsWidgets);
      await tester.tap(find.byIcon(LucideIcons.trash), warnIfMissed: false);
      expect(messages.removals, 1);
      messages.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Member B'), findsNothing);
      expect(find.text('Member C'), findsWidgets);
    },
  );

  testWidgets('F06 remove failure keeps roster and no success message', (
    tester,
  ) async {
    final messages = _Messages()..fail = true;
    await _open(
      tester,
      RoleAwareGroupMembersScreen(conversationId: 'chat', repository: messages),
    );
    await tester.tap(find.byIcon(LucideIcons.copy));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Member B').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.trash));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(find.text('Member B'), findsWidgets);
    expect(find.textContaining('Đã xoá'), findsNothing);
    expect(find.textContaining('Không thể xóa thành viên'), findsOneWidget);
  });

  testWidgets('F04 MEMBER cannot select/remove members', (tester) async {
    await _open(
      tester,
      RoleAwareGroupMembersScreen(
        conversationId: 'chat',
        repository: _Messages(leader: false),
      ),
    );
    expect(find.byIcon(LucideIcons.copy), findsNothing);
    expect(find.byIcon(LucideIcons.trash), findsNothing);
    expect(find.byIcon(LucideIcons.plus), findsNothing);
  });

  testWidgets(
    'F07 partial bulk ACK keeps only remaining members selected for retry',
    (tester) async {
      final messages = _Messages()..partialFail = true;
      await _open(
        tester,
        RoleAwareGroupMembersScreen(
          conversationId: 'chat',
          repository: messages,
        ),
      );
      await tester.tap(find.byIcon(LucideIcons.copy));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Member B').first);
      await tester.tap(find.text('Member C').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.trash));
      await tester.pumpAndSettle();
      expect(find.text('Xoá (2) thành viên'), findsOneWidget);
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(find.text('Member B'), findsNothing);
      expect(find.text('Member C'), findsWidgets);
      // Existing error snackbar temporarily overlays the bottom action.
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.trash));
      await tester.pumpAndSettle();
      expect(find.text('Xoá (1) thành viên'), findsOneWidget);
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(find.text('Member C'), findsNothing);
      expect(messages.removals, 2);
    },
  );

  testWidgets('F08 revoked membership closes stale detail and clears pin', (
    tester,
  ) async {
    GoMateMapUiSession.registerTrips([_trip()]);
    await _open(
      tester,
      TripDetailScreen(
        trip: _trip(),
        tripRepository: _Trips()..denied = true,
        messageRepository: _Messages(leader: false),
      ),
    );
    expect(find.byType(TripDetailScreen), findsNothing);
    expect(GoMateMapUiSession.availableTrips, isEmpty);
    expect(GoMateMapUiSession.pinnedTrip, isNull);
  });

  testWidgets(
    'F08 leave ACK clears membership even if user backed out while waiting',
    (tester) async {
      final trips = _Trips()..gate = Completer<void>();
      GoMateMapUiSession.registerTrips([_trip()]);
      await _open(
        tester,
        TripDetailScreen(
          trip: _trip(),
          tripRepository: trips,
          messageRepository: _Messages(leader: false),
        ),
      );
      await _confirmTripLeave(tester);
      Navigator.of(tester.element(find.byType(TripDetailScreen))).pop();
      await tester.pumpAndSettle();
      trips.gate!.complete();
      await tester.pumpAndSettle();
      expect(GoMateMapUiSession.availableTrips, isEmpty);
    },
  );

  testWidgets(
    'F01/F06/F09 chat leave uses ACK and does not fake a failed leave',
    (tester) async {
      final messages = _Messages(leader: false)..fail = true;
      await _open(
        tester,
        MessageDetailScreen(conversationId: 'chat', repository: messages),
      );
      await tester.tap(find.text('Rời nhóm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(messages.leaves, 1);
      expect(find.byType(MessageDetailScreen), findsOneWidget);
      expect(find.textContaining('Đã rời nhóm'), findsNothing);
    },
  );
}
