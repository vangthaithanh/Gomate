import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/session_store.dart';
import 'package:gomate/features/map/state/map_ui_session.dart';
import 'package:gomate/features/messages/data/message_repository.dart';
import 'package:gomate/features/notifications/data/notification_repository.dart';
import 'package:gomate/features/notifications/models/gomate_notification.dart';
import 'package:gomate/features/notifications/screens/notification_screen.dart';
import 'package:gomate/features/trip/data/trip_repository.dart';
import 'package:gomate/features/trip/models/trip_planning_context.dart';
import 'package:gomate/features/trip/models/trip_ui_models.dart';
import 'package:gomate/features/trip/screens/create_trip_screen.dart';
import 'package:gomate/features/trip/screens/trip_detail_screen.dart';
import 'package:gomate/features/trip/widgets/trip_shared_sheets.dart';

TripPlanningContext clock() =>
    TripPlanningContext('Asia/Ho_Chi_Minh', DateTime.utc(2026, 10, 21, 10));

Map<String, dynamic> reminderJson(int days, {String? tripId = 'trip-a'}) => {
  'id': 'n-d$days',
  'type': 'TRIP_START_REMINDER',
  'actorName': 'Not a sender',
  'message': days == 2
      ? 'Lịch trình Test bắt đầu vào 28/10/2026. Hãy chuẩn bị cho lịch trình.'
      : 'Nhắc lần hai: lịch trình Test bắt đầu vào ngày mai.',
  'occurredAt': '2026-10-${28 - days}T13:00:00Z',
  'isRead': false,
  'reminderId': 'reminder-d$days',
  'reminderDaysBefore': days,
  'tripStartDate': '2026-10-28',
  'reminderDate': '2026-10-${28 - days}',
  'reminderTimezone': 'Asia/Ho_Chi_Minh',
  'tripId': tripId,
  'tripName': 'Test',
};

class _Inbox extends NotificationRepository {
  _Inbox(this.rows);
  final List<GoMateNotificationItem> rows;
  bool fail = false;
  bool failRead = false;
  final readIds = <String>[];
  int resolves = 0;
  @override
  List<GoMateNotificationItem> get items => rows;
  @override
  bool get hasMore => false;
  @override
  Future<void> refresh() async {}
  @override
  Future<GoMateNotificationItem> resolve(String id) async {
    resolves++;
    if (fail) throw StateError('offline');
    return rows.firstWhere((r) => r.id == id);
  }

  @override
  Future<void> markRead(String id) async {
    readIds.add(id);
    if (failRead) throw StateError('read ACK offline');
    final index = rows.indexWhere((row) => row.id == id);
    rows[index] = rows[index].copyWith(isRead: true);
    notifyListeners();
  }
}

class _Store implements SessionStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
}

class _Api {
  final requests = <http.Request>[];
  final trip = <String, dynamic>{
    'id': 'trip-a',
    'title': 'Date-only Trip',
    'tripType': 'PERSONAL',
    'startDate': '2026-10-28',
    'endDate': '2026-10-28',
    'timezone': 'Asia/Ho_Chi_Minh',
    'members': [
      {'userId': 'leader', 'displayName': 'Leader', 'role': 'LEADER'},
    ],
    'stops': [],
    'pendingInvitations': [],
  };
  late final AuthService auth = AuthService(
    store: _Store(),
    baseUrl: 'http://fixture.invalid/api/v1',
    client: MockClient((r) async {
      if (r.url.path.endsWith('/login')) {
        return http.Response(
          jsonEncode({
            'accessToken': 'fixture',
            'refreshToken': 'refresh',
            'user': {'id': 'leader'},
          }),
          200,
        );
      }
      requests.add(r);
      if (r.url.path.endsWith('/time-context')) {
        return http.Response(
          jsonEncode({
            'timezone': r.url.queryParameters['timezone'],
            'serverNow': '2026-10-28T03:59:00Z',
            'localNow': '2026-10-27T23:59:00',
            'today': '2026-10-27',
          }),
          200,
        );
      }
      if ((r.method == 'POST' && r.url.path.endsWith('/trips')) ||
          (r.method == 'PATCH' && r.url.path.endsWith('/trips/trip-a'))) {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        for (final key in ['title', 'startDate', 'endDate']) {
          if (body.containsKey(key)) trip[key] = body[key];
        }
      }
      return http.Response(
        jsonEncode(
          r.method == 'GET' && r.url.path.endsWith('/trips') ? [trip] : trip,
        ),
        200,
      );
    }),
  );
  late final RealTripRepository repo = RealTripRepository(auth: auth);

  Future<void> login() =>
      auth.login(email: 'leader', password: 'fixture', remember: false);
  Map<String, dynamic> get lastBody =>
      jsonDecode(requests.last.body) as Map<String, dynamic>;
}

TripUi _trip(bool leader) => TripUi(
  id: 'trip-a',
  title: 'Date-only Trip',
  days: 1,
  destination: 'Test',
  isGroup: true,
  currentUserRole: leader ? TripAccessRole.leader : TripAccessRole.member,
  startDate: DateTime(2026, 10, 28),
  endDate: DateTime(2026, 10, 28),
);

class _Messages extends MessageRepository {
  @override
  Future<void> refresh() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Trips extends RealTripRepository {
  _Trips(this.current);
  TripUi current;
  TripCreateDraft? draft;
  var clocks = 0;
  var saves = 0;
  @override
  Future<TripUi> detail(String id) async => current;
  @override
  Future<TripPlanningContext> planningContext(String timezone) async {
    clocks++;
    expect(timezone, 'Asia/Ho_Chi_Minh');
    return clock();
  }

  @override
  Future<TripUi> create(TripCreateDraft value) async {
    draft = value;
    current = current.copyWith(
      title: value.title,
      startDate: value.startDate,
      endDate: value.endDate,
    );
    return current;
  }

  @override
  Future<TripUi> update(
    String tripId, {
    String? title,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    saves++;
    current = current.copyWith(
      title: title,
      startDate: startDate,
      endDate: endDate,
    );
    return current;
  }
}

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _showOctober(WidgetTester tester) async {
  final calendar = find.byType(TripDateRangeContent);
  for (var attempt = 0; attempt < 120; attempt++) {
    final header = tester.widget<Text>(
      find.descendant(
        of: calendar,
        matching: find.byWidgetPredicate(
          (w) => w is Text && (w.data?.startsWith('Tháng ') ?? false),
        ),
      ),
    );
    final parts = header.data!.split(' ');
    final month = int.parse(parts[2]) * 12 + int.parse(parts[1]);
    const target = 2026 * 12 + 10;
    if (month == target) return;
    await tester.tap(
      find.descendant(
        of: calendar,
        matching: find.byIcon(
          month > target ? LucideIcons.chevron_left : LucideIcons.chevron_right,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
  fail('Could not open October 2026');
}

void main() {
  test(
    'Repository sends dates only; list/detail accept responses without hour',
    () async {
      final api = _Api();
      addTearDown(api.auth.dispose);
      await api.login();
      final created = await api.repo.create(
        TripCreateDraft(
          title: ' Test ',
          startDate: DateTime(2026, 10, 28),
          endDate: DateTime(2026, 10, 28),
          selectedMemberIds: const ['invitee'],
        ),
      );
      expect(api.lastBody, {
        'title': 'Test',
        'startDate': '2026-10-28',
        'endDate': '2026-10-28',
        'timezone': 'Asia/Ho_Chi_Minh',
        'selectedMemberIds': ['invitee'],
      });
      expect(created.days, 1);
      expect(created.timezone, 'Asia/Ho_Chi_Minh');
      final updated = await api.repo.update(
        'trip-a',
        startDate: DateTime(2026, 10, 29),
        endDate: DateTime(2026, 10, 30),
      );
      expect(api.lastBody, {
        'startDate': '2026-10-29',
        'endDate': '2026-10-30',
      });
      expect(updated.days, 2);
      expect(
        (await api.repo.detail('trip-a')).startDate,
        DateTime(2026, 10, 29),
      );
      expect((await api.repo.list()).single.endDate, DateTime(2026, 10, 30));
    },
  );

  test(
    'Historical Trip metadata remains editable and old hour is ignored',
    () async {
      final api = _Api();
      addTearDown(api.auth.dispose);
      await api.login();
      api.trip.addAll({
        'startDate': '2020-01-01',
        'endDate': '2020-01-01',
        'plannedStartTime': 'legacy',
      });
      expect((await api.repo.detail('trip-a')).startDate, DateTime(2020, 1, 1));
      expect((await api.repo.list()).single.days, 1);
      final renamed = await api.repo.update('trip-a', title: ' Renamed ');
      expect(api.lastBody, {'title': 'Renamed'});
      expect(renamed.title, 'Renamed');
      expect(renamed.startDate, DateTime(2020, 1, 1));
    },
  );

  test('Date context uses server Trip wall date across UTC midnight', () async {
    final api = _Api();
    addTearDown(api.auth.dispose);
    await api.login();
    final c = await api.repo.planningContext('America/New_York');
    expect(api.requests.single.url.queryParameters, {
      'timezone': 'America/New_York',
    });
    expect(c.timezone, 'America/New_York');
    expect(c.today, DateTime(2026, 10, 27));
    expect(c.initialWallTime, DateTime.utc(2026, 10, 27, 23, 59));
  });

  test(
    'Stop occurrence intervals, start-only hint and explicit clear are unchanged',
    () async {
      final api = _Api();
      addTearDown(api.auth.dispose);
      await api.login();
      await api.repo.addStop(
        'trip-a',
        placeId: '42',
        dayNo: 2,
        tripStartDate: DateTime(2026, 10, 28),
        startTime: '09:00',
        endTime: '10:30',
      );
      expect(api.lastBody, {
        'placeId': 42,
        'dayNo': 2,
        'plannedStartAt': '2026-10-29T09:00:00',
        'plannedEndAt': '2026-10-29T10:30:00',
      });
      await api.repo.updateStop(
        'trip-a',
        'stop-a',
        dayNo: 2,
        tripStartDate: DateTime(2026, 10, 28),
        startTime: '11:00',
      );
      expect(api.requests.last.url.path, endsWith('/stops/stop-a'));
      expect(api.lastBody, {
        'dayNo': 2,
        'plannedStartAt': '2026-10-29T11:00:00',
      });
      await api.repo.updateStop(
        'trip-a',
        'stop-a',
        tripStartDate: DateTime(2026, 10, 28),
        endTime: '12:00',
      );
      expect(api.lastBody, {'clearTime': true});
      await api.repo.addStop(
        'trip-a',
        placeId: '42',
        dayNo: 1,
        tripStartDate: DateTime(2026, 10, 28),
        endTime: '12:00',
      );
      expect(api.lastBody, {'placeId': 42, 'dayNo': 1});
      api.trip['stops'] = [
        {
          'id': 'stop-a',
          'placeId': 42,
          'dayNo': 1,
          'name': 'Place',
          'plannedStartAt': '2026-10-28T09:00:00',
          'plannedEndAt': '2026-10-28T10:30:00',
          'hasCompleteInterval': true,
        },
      ];
      final stop = (await api.repo.detail('trip-a')).places.single;
      expect(stop.startTime, '09:00');
      expect(stop.endTime, '10:30');
      expect(stop.hasFullTime, true);
      expect(
        stop.copyWith(endTime: '', hasCompleteInterval: false).hasFullTime,
        false,
      );
    },
  );

  testWidgets('Create submits a same-day Trip without choosing an hour', (
    tester,
  ) async {
    _phoneSize(tester);
    GoMateMapUiSession.clearUserState();
    final trips = _Trips(_trip(true));
    final messages = _Messages();
    TripUi? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<TripUi>(
                    MaterialPageRoute(
                      builder: (_) => CreateTripScreen(
                        tripRepository: trips,
                        messageRepository: messages,
                      ),
                    ),
                  );
                },
                child: const Text('Open create'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open create'));
    await tester.pumpAndSettle();
    expect(find.text('Giờ bắt đầu dự kiến'), findsNothing);
    expect(find.byIcon(LucideIcons.clock), findsNothing);
    await tester.tap(find.byIcon(LucideIcons.pencil));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Date-only Trip');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn ngày'));
    await tester.pumpAndSettle();
    final picker = tester.widget<TripDateRangeContent>(
      find.byType(TripDateRangeContent),
    );
    expect(picker.minimumDate, DateTime(2026, 10, 21));
    expect(picker.currentDate!(), DateTime(2026, 10, 21));
    await _showOctober(tester);
    final day = find.byKey(const ValueKey('trip-date-2026-10-28'));
    await tester.tap(day);
    await tester.pump();
    await tester.tap(day);
    await tester.pump();
    await tester.tap(find.text('Hoàn tất'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo lịch trình').last);
    await tester.pumpAndSettle();
    expect(trips.clocks, 1);
    expect(trips.draft!.startDate, DateTime(2026, 10, 28));
    expect(trips.draft!.endDate, DateTime(2026, 10, 28));
    expect(result?.title, 'Date-only Trip');
    expect(GoMateMapUiSession.pinnedTrip, isNull);
    await tester.pumpWidget(const SizedBox());
    messages.dispose();
  });

  for (final leader in [false, true]) {
    testWidgets(
      'Detail has dates only and preserves edit permission: leader=$leader',
      (tester) async {
        _phoneSize(tester);
        GoMateMapUiSession.clearUserState();
        final trips = _Trips(_trip(leader));
        final messages = _Messages();
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
        expect(find.text('Giờ bắt đầu dự kiến'), findsNothing);
        expect(find.byIcon(LucideIcons.clock), findsNothing);
        await tester.ensureVisible(find.text(trips.current.dateRangeLabel));
        await tester.tap(find.text(trips.current.dateRangeLabel));
        await tester.pumpAndSettle();
        expect(trips.clocks, leader ? 1 : 0);
        if (leader) {
          final picker = tester.widget<TripDateRangeContent>(
            find.byType(TripDateRangeContent),
          );
          expect(picker.minimumDate, DateTime(2026, 10, 21));
          await tester.tap(find.byKey(const ValueKey('trip-date-2026-10-29')));
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('trip-date-2026-10-30')));
          await tester.pump();
          await tester.tap(find.text('Hoàn tất'));
          await tester.pumpAndSettle();
          expect(trips.saves, 1);
          expect(trips.current.startDate, DateTime(2026, 10, 29));
          expect(trips.current.endDate, DateTime(2026, 10, 30));
        } else {
          expect(find.byType(TripDateRangeContent), findsNothing);
          expect(trips.saves, 0);
        }
        expect(GoMateMapUiSession.pinnedTrip, isNull);
        await tester.pumpWidget(const SizedBox());
        messages.dispose();
      },
    );
  }

  testWidgets(
    'Calendar locks past dates, restarts on earlier second tap and allows same-day range',
    (tester) async {
      _phoneSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripDateRangeContent(
              initialStart: DateTime(2026, 10, 25),
              initialEnd: DateTime(2026, 10, 26),
              minimumDate: DateTime(2026, 10, 21),
            ),
          ),
        ),
      );
      final past = find.byKey(const ValueKey('trip-date-2026-10-20'));
      final today = find.byKey(const ValueKey('trip-date-2026-10-21'));
      expect(tester.widget<InkWell>(past).onTap, isNull);
      expect(tester.widget<InkWell>(today).onTap, isNotNull);
      await tester.tap(find.byKey(const ValueKey('trip-date-2026-10-25')));
      await tester.pump();
      await tester.tap(today);
      await tester.pump();
      expect(find.textContaining('Đã chọn 21/10'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Hoàn tất'))
            .onPressed,
        isNull,
      );
      await tester.tap(past, warnIfMissed: false);
      await tester.pump();
      expect(find.textContaining('Đã chọn 21/10'), findsOneWidget);
      await tester.tap(today);
      await tester.pump();
      expect(find.textContaining('21/10 - 21/10'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Hoàn tất'))
            .onPressed,
        isNotNull,
      );
      final label = tester.widget<Text>(
        find.descendant(of: past, matching: find.byType(Text)),
      );
      expect(label.style?.color, isNot(Colors.black));
    },
  );

  test(
    'D-2/D-1 preserve server body and calendar metadata through read ACK',
    () {
      final two = GoMateNotificationItem.fromJson(reminderJson(2));
      final one = GoMateNotificationItem.fromJson(reminderJson(1));
      expect(two.id, isNot(one.id));
      expect(two.reminderId, isNot(one.reminderId));
      for (final n in [two, one]) {
        expect(n.type, GoMateNotificationType.tripStartReminder);
        expect(n.isPendingInvitation, false);
        expect(n.invitationId, isNull);
        expect(n.actorName, isEmpty);
        expect(n.message, reminderJson(n.reminderDaysBefore!)['message']);
        expect(n.reminderOffsetMinutes, isNull);
        expect(n.plannedStartAt, isNull);
        final read = n.copyWith(isRead: true);
        expect(read.isRead, true);
        expect(read.message, n.message);
        expect(read.reminderDaysBefore, n.reminderDaysBefore);
        expect(read.tripStartDate, '2026-10-28');
        expect(
          read.reminderDate,
          n.reminderDaysBefore == 2 ? '2026-10-26' : '2026-10-27',
        );
        expect(read.reminderTimezone, 'Asia/Ho_Chi_Minh');
        expect(read.tripId, 'trip-a');
      }
    },
  );

  for (final offset in [60, 30]) {
    test(
      'Historical T-$offset remains readable with original body and timestamp',
      () {
        final n = GoMateNotificationItem.fromJson({
          'id': 'old-$offset',
          'type': 'TRIP_START_REMINDER',
          'message': 'Nhắc trước giờ bắt đầu dự kiến $offset phút.',
          'occurredAt': '2026-10-21T03:00:00Z',
          'reminderId': 'old-reminder-$offset',
          'reminderOffsetMinutes': offset,
          'plannedStartAt': '2026-10-21T04:00:00Z',
          'tripId': 'trip-a',
        }).copyWith(isRead: true);
        expect(n.message, 'Nhắc trước giờ bắt đầu dự kiến $offset phút.');
        expect(n.reminderOffsetMinutes, offset);
        expect(n.plannedStartAt, DateTime.utc(2026, 10, 21, 4));
        expect(n.reminderDaysBefore, isNull);
        expect(n.tripStartDate, isNull);
        expect(n.reminderDate, isNull);
        expect(n.reminderTimezone, isNull);
        expect(n.isPendingInvitation, false);
      },
    );
  }

  for (final failRead in [false, true]) {
    testWidgets(
      'Reminder push read ACK precedes current Trip lookup: failRead=$failRead',
      (tester) async {
        GoMateMapUiSession.clearUserState();
        final inbox = _Inbox([GoMateNotificationItem.fromJson(reminderJson(1))])
          ..failRead = failRead;
        var loads = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: GoMateNotificationScreen(
              focusPendingInvitationId: 'n-d1',
              repository: inbox,
              loadTrip: (_) async {
                loads++;
                expect(inbox.readIds, ['n-d1']);
                // Access is still resolved by the server, not the push payload.
                throw StateError('Trip is no longer accessible');
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(inbox.readIds, ['n-d1']);
        expect(inbox.rows.single.isRead, !failRead);
        expect(loads, failRead ? 0 : 1);
        expect(find.byType(TripDetailScreen), findsNothing);
        expect(GoMateMapUiSession.pinnedTrip, isNull);
        await tester.pumpWidget(const SizedBox());
        inbox.dispose();
      },
    );
  }

  for (final offline in [false, true]) {
    testWidgets(
      'Stale/unreachable date reminder cannot navigate or affect pin: offline=$offline',
      (tester) async {
        GoMateMapUiSession.clearUserState();
        final inbox = _Inbox([
          GoMateNotificationItem.fromJson(reminderJson(2, tripId: null)),
        ])..fail = offline;
        var loads = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: GoMateNotificationScreen(
              repository: inbox,
              loadTrip: (_) async {
                loads++;
                throw StateError('must not open');
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Chấp nhận'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('n-d2')));
        await tester.pumpAndSettle();
        expect(inbox.resolves, 1);
        expect(loads, 0);
        expect(GoMateMapUiSession.pinnedTrip, isNull);
        await tester.pumpWidget(const SizedBox());
        inbox.dispose();
      },
    );
  }
}
