import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomate/core/widgets/gomate_member_invite_content.dart';
import 'package:gomate/features/map/state/map_ui_session.dart';
import 'package:gomate/features/messages/data/message_repository.dart';
import 'package:gomate/features/messages/models/message_models.dart';
import 'package:gomate/features/messages/screens/group_management_screen.dart';
import 'package:gomate/features/trip/data/trip_repository.dart';
import 'package:gomate/features/trip/models/trip_ui_models.dart';
import 'package:gomate/features/trip/screens/create_trip_screen.dart';
import 'package:gomate/features/trip/screens/trip_detail_screen.dart';

const _contacts = [
  MessageContact(id: 'user-existing', name: 'Existing invitee', subtitle: ''),
  MessageContact(id: 'user-new', name: 'New invitee', subtitle: ''),
  MessageContact(id: 'user-next', name: 'Next invitee', subtitle: ''),
];

TripUi _personalTrip(String id) => TripUi(
  id: id,
  title: 'Personal Trip',
  days: 2,
  destination: 'Test',
  isActive: true,
  startDate: DateTime(2026, 12, 1),
  endDate: DateTime(2026, 12, 2),
  members: const [TripMemberUi(id: 'user-owner', name: 'Owner', isOwner: true)],
  pendingInviteIds: const ['user-existing'],
  pendingInvitees: const [
    TripMemberUi(
      id: 'user-existing',
      name: 'Existing invitee',
      invitationId: 'invite-existing',
    ),
  ],
);

class _Trips implements RealTripRepository {
  _Trips(this.current);
  TripUi current;
  final sends = <Set<String>>[];
  final cancellations = <String>[];
  Completer<void>? gate;
  Completer<void>? cancelGate;
  bool failNext = false;
  bool failCancel = false;
  int creates = 0;

  @override
  Future<List<MessageContact>> searchMemberCandidates(String query) async =>
      _contacts;

  @override
  Future<TripUi> addMembers(String tripId, Iterable<String> ids) async {
    expect(tripId, current.id);
    final selected = ids.toSet();
    sends.add(selected);
    if (failNext) {
      failNext = false;
      throw StateError('Network unavailable');
    }
    await gate?.future;
    current = current.copyWith(
      // The UI must preserve its local pinned state when mapping the response.
      isActive: false,
      pendingInviteIds: {...current.pendingInviteIds, ...selected}.toList(),
      pendingInvitees: [
        ...current.pendingInvitees,
        for (final contact in _contacts)
          if (selected.contains(contact.id))
            TripMemberUi(
              id: contact.id,
              name: contact.name,
              invitationId: 'invite-${contact.id}',
            ),
      ],
    );
    return current;
  }

  @override
  Future<TripUi> detail(String tripId) async => current;

  @override
  Future<TripUi> cancelInvitation(String tripId, String invitationId) async {
    expect(tripId, current.id);
    cancellations.add(invitationId);
    if (failCancel) throw StateError('Cancel unavailable');
    await cancelGate?.future;
    final invitee = current.pendingInvitees.singleWhere(
      (person) => person.invitationId == invitationId,
    );
    current = current.copyWith(
      pendingInviteIds: current.pendingInviteIds
          .where((id) => id != invitee.id)
          .toList(),
      pendingInvitees: current.pendingInvitees
          .where((person) => person.id != invitee.id)
          .toList(),
    );
    return current;
  }

  @override
  Future<TripUi> create(TripCreateDraft draft) async {
    creates++;
    return current;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Messages extends ChangeNotifier implements MessageRepository {
  @override
  String get currentUserId => 'user-owner';
  @override
  List<MessageContact> get contacts => _contacts;
  @override
  Future<void> refresh() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _GroupMessages extends _Messages {
  _GroupMessages({this.leader = true});
  final bool leader;
  final pending = <MessageGroupInvite>[
    const MessageGroupInvite(
      contactId: 'user-existing',
      name: 'Existing invitee',
      subtitle: '',
      invitedById: 'user-owner',
    ),
  ];
  final cancels = <String>[];
  bool failCancel = false;

  @override
  String get currentUserId => leader ? 'user-owner' : 'user-member';

  @override
  MessageConversation? conversation(String id) => const MessageConversation(
    id: 'group-chat',
    type: MessageConversationType.group,
    title: 'Group Trip',
    participants: [
      MessageParticipant(
        id: 'user-owner',
        name: 'Owner',
        role: MessageGroupRole.leader,
      ),
      MessageParticipant(id: 'user-member', name: 'Member'),
    ],
    messages: [],
    lastSenderId: '',
    lastMessageText: '',
    lastMessageTime: '',
    linkedItineraryId: 'group-trip',
  );

  @override
  List<MessageGroupInvite> pendingGroupInvites(String conversationId) =>
      List.of(pending);
  @override
  Future<List<MessageGroupInvite>> fetchPendingGroupInvites(
    String conversationId,
  ) async => List.of(pending);
  @override
  Future<List<MessageContact>> fetchContactSuggestions(String query) async =>
      _contacts;
  @override
  Future<void> inviteGroupMembers(
    String conversationId,
    Iterable<String> contactIds,
  ) async {
    for (final id in contactIds) {
      final person = contacts.singleWhere((item) => item.id == id);
      pending.add(
        MessageGroupInvite(
          contactId: id,
          name: person.name,
          subtitle: '',
          invitedById: currentUserId,
        ),
      );
    }
    notifyListeners();
  }

  @override
  Future<void> cancelGroupInvite(
    String conversationId,
    String contactId,
  ) async {
    cancels.add(contactId);
    if (failCancel) throw StateError('Group cancel unavailable');
    pending.removeWhere((person) => person.contactId == contactId);
    notifyListeners();
  }
}

Finder _pickerText(String text) => find.descendant(
  of: find.byType(GoMateMemberInviteContent),
  matching: find.text(text),
);

Future<void> _openGroupMembers(
  WidgetTester tester,
  _GroupMessages messages,
) async {
  tester.view.physicalSize = const Size(360, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: RoleAwareGroupMembersScreen(
        conversationId: 'group-chat',
        repository: messages,
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Đang chờ'), findsNothing);
}

Future<void> _openMembers(
  WidgetTester tester,
  _Trips trips,
  _Messages messages,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (trips.current.isActive) GoMateMapUiSession.pinTrip(trips.current);
  await tester.pumpWidget(
    MaterialApp(
      home: TripDetailScreen(
        trip: trips.current,
        tripRepository: trips,
        messageRepository: messages,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Thành viên'));
  await tester.pumpAndSettle();
  expect(find.byType(TripDraftMembersScreen), findsOneWidget);
  expect(find.text('Đang chờ'), findsNothing);
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.byIcon(LucideIcons.plus));
  await tester.pumpAndSettle();
}

Future<void> _closePicker(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(GoMateMemberInviteContent))).pop();
  await tester.pumpAndSettle();
}

void main() {
  for (final id in [
    'trip-created-this-session',
    'trip-from-previous-session',
  ]) {
    testWidgets('Saved PERSONAL $id sends on Add without a second Send step', (
      tester,
    ) async {
      final trips = _Trips(_personalTrip(id));
      final messages = _Messages();
      await _openMembers(tester, trips, messages);
      await _openPicker(tester);
      expect(
        find.descendant(
          of: find.byType(GoMateMemberInviteContent),
          matching: find.text('Existing invitee'),
        ),
        findsNothing,
      );
      await tester.tap(find.text('New invitee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('(1) Thêm'));
      await tester.pumpAndSettle();
      expect(trips.sends, [
        <String>{'user-new'},
      ]);
      expect(_pickerText('New invitee'), findsNothing);
      expect(_pickerText('Huỷ lời mời'), findsNothing);
      expect(find.textContaining('Gửi ('), findsNothing);
      await _closePicker(tester);
      expect(find.text('Existing invitee'), findsOneWidget);
      expect(find.text('New invitee'), findsOneWidget);
      expect(find.text('Đang chờ'), findsNothing);
      expect(find.text('Huỷ lời mời'), findsNWidgets(2));
      final updated = GoMateMapUiSession.availableTrips.singleWhere(
        (trip) => trip.id == id,
      );
      expect(updated.isActive, isTrue);
      expect(updated.isGroup, isFalse);
      expect(updated.conversationId, isNull);
      expect(updated.members.single.id, 'user-owner');
      await tester.tap(
        find.descendant(
          of: find.byType(TripDraftMembersScreen),
          matching: find.byIcon(LucideIcons.chevron_left),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 thành viên • 2 lời mời'), findsOneWidget);
      await tester.tap(find.text('Thành viên'));
      await tester.pumpAndSettle();
      expect(find.text('New invitee'), findsOneWidget);
      expect(find.textContaining('Gửi ('), findsNothing);
      await _openPicker(tester);
      expect(
        find.descendant(
          of: find.byType(GoMateMemberInviteContent),
          matching: find.text('New invitee'),
        ),
        findsNothing,
      );
      expect(trips.sends.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      messages.dispose();
    });
  }

  testWidgets('Add waits for server ACK and ignores repeated taps', (
    tester,
  ) async {
    final trips = _Trips(_personalTrip('trip-delayed'))
      ..gate = Completer<void>();
    final messages = _Messages();
    await _openMembers(tester, trips, messages);
    await _openPicker(tester);
    await tester.tap(find.text('New invitee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('(1) Thêm'));
    await tester.pump();
    await tester.tap(find.text('(1) Thêm'));
    await tester.pump();
    expect(trips.sends.length, 1);
    expect(find.text('Huỷ lời mời'), findsOneWidget);
    trips.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Huỷ lời mời'), findsNWidgets(2));
    expect(_pickerText('New invitee'), findsNothing);
    expect(_pickerText('Huỷ lời mời'), findsNothing);
    await _closePicker(tester);
    await tester.tap(find.byKey(const ValueKey('cancel-invite-user-new')));
    await tester.pumpAndSettle();
    expect(trips.cancellations, ['invite-user-new']);
    expect(find.text('Huỷ lời mời'), findsOneWidget);
    expect(find.text('Đang chờ'), findsNothing);
    expect(find.text('Huỷ lời mời'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    messages.dispose();
  });

  testWidgets('Failed Add does not create fake pending state and can retry', (
    tester,
  ) async {
    final trips = _Trips(_personalTrip('trip-retry'))..failNext = true;
    final messages = _Messages();
    await _openMembers(tester, trips, messages);
    await _openPicker(tester);
    await tester.tap(find.text('New invitee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('(1) Thêm'));
    await tester.pumpAndSettle();
    expect(find.text('Huỷ lời mời'), findsOneWidget);
    expect(find.text('(1) Thêm'), findsOneWidget);
    expect(find.textContaining('Không gửi được lời mời:'), findsOneWidget);
    expect(trips.current.pendingInviteIds, ['user-existing']);
    await tester.tap(find.text('(1) Thêm'));
    await tester.pumpAndSettle();
    expect(trips.sends.length, 2);
    await _closePicker(tester);
    expect(find.text('New invitee'), findsOneWidget);
    expect(find.text('Đang chờ'), findsNothing);
    expect(find.text('Huỷ lời mời'), findsNWidgets(2));
    expect(find.textContaining('Gửi ('), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    messages.dispose();
  });

  testWidgets(
    'Leader cancels an existing pending invite only after ACK and can reselect',
    (tester) async {
      final trips = _Trips(_personalTrip('trip-cancel'))
        ..cancelGate = Completer<void>();
      final messages = _Messages();
      await _openMembers(tester, trips, messages);
      final cancel = find.byKey(const ValueKey('cancel-invite-user-existing'));
      expect(find.byType(GoMateMemberInviteContent), findsNothing);
      await tester.tap(cancel);
      await tester.pump();
      await tester.tap(cancel);
      await tester.pump();
      expect(trips.cancellations, ['invite-existing']);
      expect(cancel, findsOneWidget);
      trips.cancelGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Huỷ lời mời'), findsNothing);
      await _openPicker(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(GoMateMemberInviteContent),
          matching: find.text('Existing invitee'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('(1) Thêm'), findsOneWidget);
      await _closePicker(tester);
      expect(find.text('Đang chờ'), findsNothing);
      expect(find.text('Existing invitee'), findsNothing);
      final cached = GoMateMapUiSession.availableTrips.singleWhere(
        (trip) => trip.id == trips.current.id,
      );
      expect(cached.pendingInviteIds, isEmpty);
      expect(cached.members.single.id, 'user-owner');
      expect(cached.isGroup, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      messages.dispose();
    },
  );

  testWidgets(
    'Failed cancellation keeps the pending invite visible for retry',
    (tester) async {
      final trips = _Trips(_personalTrip('trip-cancel-retry'))
        ..failCancel = true;
      final messages = _Messages();
      await _openMembers(tester, trips, messages);
      await tester.tap(
        find.byKey(const ValueKey('cancel-invite-user-existing')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Huỷ lời mời'), findsOneWidget);
      expect(trips.current.pendingInviteIds, ['user-existing']);
      expect(find.textContaining('Cancel unavailable'), findsOneWidget);
      trips.failCancel = false;
      await tester.tap(
        find.byKey(const ValueKey('cancel-invite-user-existing')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Huỷ lời mời'), findsNothing);
      expect(trips.cancellations.length, 2);
      expect(find.text('Đang chờ'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      messages.dispose();
    },
  );

  testWidgets(
    'GROUP adds hide inside the picker; cancellation is in the outer pending list',
    (tester) async {
      final messages = _GroupMessages();
      await _openGroupMembers(tester, messages);
      expect(find.text('Lời mời đang chờ'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('cancel-invite-user-existing')),
        findsOneWidget,
      );
      await _openPicker(tester);
      expect(_pickerText('Existing invitee'), findsNothing);
      expect(_pickerText('Huỷ lời mời'), findsNothing);
      await tester.tap(_pickerText('New invitee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('(1) Thêm'));
      await tester.pumpAndSettle();
      expect(_pickerText('New invitee'), findsNothing);
      await tester.enterText(find.byType(TextField), 'New');
      await tester.pumpAndSettle();
      expect(_pickerText('New invitee'), findsNothing);
      await _closePicker(tester);
      expect(find.text('New invitee'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cancel-invite-user-new')));
      await tester.pumpAndSettle();
      expect(messages.cancels, ['user-new']);
      expect(find.text('New invitee'), findsNothing);
      await _openPicker(tester);
      expect(_pickerText('New invitee'), findsOneWidget);
      expect(_pickerText('Existing invitee'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      messages.dispose();
    },
  );

  testWidgets('GROUP cancel failure leaves the outer pending row for retry', (
    tester,
  ) async {
    final messages = _GroupMessages()..failCancel = true;
    await _openGroupMembers(tester, messages);
    final cancel = find.byKey(const ValueKey('cancel-invite-user-existing'));
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(cancel, findsOneWidget);
    expect(find.textContaining('Group cancel unavailable'), findsOneWidget);
    messages.failCancel = false;
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(cancel, findsNothing);
    expect(messages.cancels.length, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    messages.dispose();
  });

  testWidgets('GROUP non-leader has no pending cancellation action', (
    tester,
  ) async {
    final messages = _GroupMessages(leader: false);
    await _openGroupMembers(tester, messages);
    expect(find.text('Huỷ lời mời'), findsNothing);
    expect(find.byIcon(LucideIcons.plus), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    messages.dispose();
  });

  testWidgets(
    'Create screen still stages invitees without sending before create',
    (tester) async {
      final trips = _Trips(_personalTrip('not-created-yet'));
      final messages = _Messages();
      await tester.pumpWidget(
        MaterialApp(
          home: CreateTripScreen(
            tripRepository: trips,
            messageRepository: messages,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm thành viên'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New invitee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('(1) Thêm'));
      await tester.pumpAndSettle();
      expect(trips.sends, isEmpty);
      expect(trips.creates, 0);
      expect(find.text('Huỷ lời mời'), findsOneWidget);
      await tester.tap(find.text('Huỷ lời mời'));
      await tester.pumpAndSettle();
      expect(find.text('Huỷ lời mời'), findsNothing);
      expect(trips.sends, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      messages.dispose();
    },
  );

  for (final width in [320.0, 430.0]) {
    testWidgets('Outer pending actions fit long names at width $width', (
      tester,
    ) async {
      final longName = List.filled(8, 'Long display name').join(' ');
      final trips = _Trips(
        _personalTrip('trip-width-$width').copyWith(
          pendingInvitees: [
            TripMemberUi(
              id: 'user-existing',
              name: longName,
              invitationId: 'invite-existing',
            ),
          ],
        ),
      );
      final messages = _Messages();
      await _openMembers(tester, trips, messages);
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('cancel-invite-user-existing')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      messages.dispose();
      final group = _GroupMessages();
      group.pending[0] = MessageGroupInvite(
        contactId: 'user-existing',
        name: longName,
        subtitle: '',
        invitedById: 'user-owner',
      );
      await _openGroupMembers(tester, group);
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('cancel-invite-user-existing')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      group.dispose();
    });
  }
}
