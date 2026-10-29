import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/session_store.dart';
import 'package:gomate/features/map/state/map_ui_session.dart';
import 'package:gomate/features/map/widgets/map_add_place_flow_panel.dart';
import 'package:gomate/features/trip/data/trip_repository.dart';
import 'package:gomate/features/trip/models/trip_ui_models.dart';

class _Store implements SessionStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  late AuthService auth;
  late RealTripRepository repo;
  late List<http.Request> requests;
  late Map<String, dynamic> detail;
  setUp(() async {
    GoMateMapUiSession.clearUserState();
    requests = [];
    detail = {
      'id': 'trip',
      'title': 'Saved times',
      'tripType': 'PERSONAL',
      'timezone': 'America/New_York',
      'startDate': '2030-07-01',
      'endDate': '2030-07-03',
      'memberCount': 1,
      'stopCount': 3,
      'members': [
        {'userId': 'owner', 'role': 'LEADER'},
      ],
      'stops': [
        for (final id in ['a1', 'b', 'a2'])
          {
            'id': id,
            'placeId': id == 'b' ? 2 : 1,
            'name': id,
            'dayNo': 2,
            'plannedStartAt': '2030-07-02T14:02:00Z',
            'plannedEndAt': '2030-07-02T15:03:00Z',
            'plannedLocalStartAt': '2030-07-02T10:02:00',
            'plannedLocalEndAt': '2030-07-02T11:03:00',
            'hasCompleteInterval': true,
          },
      ],
    };
    auth = AuthService(
      store: _Store(),
      baseUrl: 'http://fixture.invalid/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(
            jsonEncode({
              'accessToken': 'fixture',
              'refreshToken': 'fixture',
              'user': {'id': 'owner'},
            }),
            200,
          );
        }
        requests.add(request);
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/trips') && request.method == 'GET'
                ? [
                    {...detail}
                      ..remove('stops')
                      ..remove('members'),
                  ]
                : detail,
          ),
          200,
        );
      }),
    );
    repo = RealTripRepository(auth: auth);
    await auth.login(email: 'fixture', password: 'fixture', remember: false);
  });
  tearDown(() {
    auth.dispose();
    GoMateMapUiSession.clearUserState();
  });

  test(
    'Trip-local hydration ignores device timezone and retains occurrence identity',
    () async {
      final trip = await repo.detail('trip');
      expect(trip.isDetail, true);
      expect(trip.places.map((p) => p.id), ['a1', 'b', 'a2']);
      expect(trip.places.last.startTime, '10:02');
      expect(trip.places.last.endTime, '11:03');
      expect(trip.places.last.plannedStartAt, '2030-07-02T14:02:00Z');
    },
  );

  test(
    'Summary refresh cannot replace displayed detailed stop times with placeholders',
    () async {
      final trip = await repo.detail('trip');
      GoMateMapUiSession.selectTrip(trip);
      GoMateMapUiSession.pinTrip(trip);
      GoMateMapUiSession.registerTrips(await repo.list());
      final selected = GoMateMapUiSession.displayedTrip!;
      expect(selected.isDetail, false); // one fresh detail is still required
      expect(selected.places.last.id, 'a2');
      expect(selected.places.last.startTime, '10:02');
      GoMateMapUiSession.updateTrip(await repo.detail('trip'));
      expect(GoMateMapUiSession.displayedTrip!.isDetail, true);
    },
  );

  test(
    'Omitted PATCH time is preserved; clear is explicit; invalid input never clears',
    () async {
      await repo.updateStop('trip', 'a2', placeId: '2');
      expect(jsonDecode(requests.last.body), {'placeId': 2});
      expect(requests.last.method, 'PATCH');
      expect(requests.last.url.path, endsWith('/stops/a2'));
      await repo.updateStop('trip', 'a2', clearTime: true);
      expect(jsonDecode(requests.last.body), {'clearTime': true});
      final before = requests.length;
      await expectLater(
        repo.updateStop('trip', 'a2', startTime: 'garbage'),
        throwsArgumentError,
      );
      expect(requests.length, before);
    },
  );

  test(
    'Selected day uses calendar arithmetic and delegates IANA resolution to Spring',
    () async {
      await repo.addStop(
        'trip',
        placeId: '1',
        dayNo: 2,
        tripStartDate: DateTime(2030, 7, 1),
        startTime: '10:02',
        endTime: '11:03',
      );
      expect(jsonDecode(requests.last.body), {
        'placeId': 1,
        'dayNo': 2,
        'plannedStartAt': '2030-07-02T10:02:00',
        'plannedEndAt': '2030-07-02T11:03:00',
      });
      await repo.addStop(
        'trip',
        placeId: '1',
        dayNo: 1,
        tripStartDate: DateTime(2030, 7, 1),
      );
      expect(jsonDecode(requests.last.body), {'placeId': 1, 'dayNo': 1});
    },
  );

  Future<void> panel(
    WidgetTester tester, {
    String? time,
    String? error,
    bool saving = false,
    required ValueChanged<String> changed,
    required VoidCallback submit,
  }) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: GoMateMapAddPlaceFlowPanel(
              trip: TripUi(
                id: 'trip',
                title: 'Test',
                days: 3,
                destination: 'Test',
              ),
              step: GoMateMapAddPlaceStep.startTime,
              selectedDay: 2,
              selectedTime: time,
              errorText: error,
              saving: saving,
              onDayChanged: (_) {},
              onTimeChanged: changed,
              onContinue: submit,
              onSkip: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Untouched optional picker does not invent midnight; explicit tap can choose it',
    (tester) async {
      String? chosen;
      var submitted = 0;
      await panel(
        tester,
        changed: (v) => chosen = v,
        submit: () => submitted++,
      );
      expect(chosen, isNull);
      await tester.tap(find.text('Tiếp tục'));
      expect(chosen, isNull);
      expect(submitted, 1);
      final picker = tester.widget<CupertinoPicker>(
        find.byType(CupertinoPicker).first,
      );
      final center = tester.getCenter(find.byWidget(picker));
      await tester.tapAt(center);
      await tester.pumpAndSettle();
      expect(chosen, '00:00');
    },
  );

  testWidgets(
    'Prefill preserves exact minutes; wheel changes reach the API body',
    (tester) async {
      String? chosen;
      await panel(
        tester,
        time: '10:02',
        changed: (v) => chosen = v,
        submit: () {},
      );
      final pickers = tester
          .widgetList<CupertinoPicker>(find.byType(CupertinoPicker))
          .toList();
      expect(pickers.first.scrollController!.selectedItem, 10);
      expect(pickers.last.scrollController!.selectedItem, 1); // 00,02,05,...
      pickers.first.scrollController!.jumpToItem(11);
      await tester.pumpAndSettle();
      expect(chosen, '11:02');
      await repo.updateStop(
        'trip',
        'a2',
        dayNo: 2,
        tripStartDate: DateTime(2030, 7, 1),
        startTime: chosen,
      );
      expect(
        jsonDecode(requests.last.body)['plannedStartAt'],
        '2030-07-02T11:02:00',
      );
      expect(requests.last.url.path, endsWith('/stops/a2'));
    },
  );

  testWidgets(
    'Inline rejection keeps hydrated values and saving disables repeated submit',
    (tester) async {
      var submitted = 0;
      await panel(
        tester,
        time: '10:02',
        error: 'Giờ bắt đầu phải ở tương lai.',
        saving: true,
        changed: (_) {},
        submit: () => submitted++,
      );
      expect(find.text('Giờ bắt đầu phải ở tương lai.'), findsOneWidget);
      expect(
        tester
            .widget<CupertinoPicker>(find.byType(CupertinoPicker).first)
            .scrollController!
            .selectedItem,
        10,
      );
      await tester.tap(find.text('Đang lưu…'));
      expect(submitted, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
