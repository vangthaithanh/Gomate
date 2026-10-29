import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:gomate/features/map/services/location_service.dart';
import 'package:gomate/features/map/state/map_ui_session.dart';
import 'package:gomate/features/map/widgets/map_controls.dart';
import 'package:gomate/features/map/widgets/map_day_route_panel.dart';
import 'package:gomate/features/map/widgets/map_trip_header.dart';
import 'package:gomate/features/map/widgets/map_trip_pin_button.dart';
import 'package:gomate/features/trip/data/trip_repository.dart';
import 'package:gomate/features/trip/models/trip_ui_models.dart';

TripUi _trip(String id, {bool pinned = false}) =>
    TripUi(id: id, title: id, days: 2, destination: 'Test', isActive: pinned);

class _Trips implements RealTripRepository {
  final calls = <String>[];
  final unpinCalls = <String>[];
  final snapshots = <String>[];
  Completer<TripUi>? response;
  Completer<void>? unpinResponse;
  bool fail = false;
  bool failUnpin = false;

  @override
  Future<TripUi> pin(String tripId) async {
    calls.add(tripId);
    if (fail) throw StateError('fixture network failure');
    return response == null ? _trip(tripId, pinned: true) : response!.future;
  }

  @override
  Future<void> unpin(String tripId) async {
    unpinCalls.add(tripId);
    await unpinResponse?.future;
    if (failUnpin) throw StateError('fixture unpin failure');
  }

  @override
  Future<void> publishLocation(
    String tripId, {
    required double latitude,
    required double longitude,
    double? accuracyM,
  }) async {
    snapshots.add('$tripId|$latitude|$longitude');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Location extends GoMateLocationService {
  GoMateLocationState state = GoMateLocationState.ready;
  int checks = 0;
  int appSettings = 0;
  int gpsSettings = 0;
  Completer<GoMateLocationResult>? current;

  @override
  Future<GoMateLocationResult> ensureAlwaysForPinnedTrip() async {
    checks++;
    return GoMateLocationResult(state);
  }

  @override
  Future<GoMateLocationResult> getCurrentLocation({
    bool requestPermission = true,
  }) async {
    if (current != null) return current!.future;
    throw StateError('GPS unavailable after pin');
  }

  @override
  Future<void> openAppSettings() async => appSettings++;

  @override
  Future<void> openLocationSettings() async => gpsSettings++;
}

Future<void> _pinHarness(
  WidgetTester tester,
  _Trips trips,
  _Location location, {
  String id = 'new',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: GoMateMapTripPinButton(
            trip: _trip(id),
            tripRepository: trips,
            locationService: location,
          ),
        ),
      ),
    ),
  );
}

Future<void> _panelHarness(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double bottomInset = 88,
  bool empty = false,
  bool canEdit = false,
  ReorderCallback? onReorder,
  ValueChanged<int>? onPlaceTap,
  ValueChanged<int>? onRemove,
  VoidCallback? onOptimize,
  VoidCallback? onMapBuild,
}) async {
  tester.view.reset();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final top = 24 + 12 + GoMateMapTripHeader.expandedHeightFor(size.width) + 8;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Builder(
                builder: (_) {
                  onMapBuild?.call();
                  return const ColoredBox(color: Colors.green);
                },
              ),
            ),
            Positioned(
              top: top,
              left: 0,
              right: 0,
              bottom: 0,
              child: GoMateMapDayRoutePanel(
                places: empty
                    ? const []
                    : List.generate(
                        20,
                        (index) => TripPlaceUi(
                          id: 'stop-$index',
                          placeId: '${index % 3}',
                          name: 'Place $index',
                          day: 1,
                        ),
                      ),
                canEdit: canEdit,
                bottomInset: bottomInset,
                onPlaceTap: onPlaceTap ?? (_) {},
                onReorder: onReorder,
                onRemove: onRemove,
                onOptimize: onOptimize,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  final panel = find.byKey(const ValueKey('map-day-route-panel'));
  final handle = find.byKey(const ValueKey('map-day-route-drag-handle'));
  final pin = find.byKey(const ValueKey('map-pin-trip'));

  setUp(() {
    for (final trip in GoMateMapUiSession.availableTrips.toList()) {
      GoMateMapUiSession.removeTrip(trip.id);
    }
    GoMateMapUiSession.clearPinnedTrip();
  });

  testWidgets(
    'panel drag stays below header and above collapsed limit; map is not rebuilt',
    (tester) async {
      var builds = 0;
      await _panelHarness(tester, onMapBuild: () => builds++);
      final initial = tester.getRect(panel);
      expect(
        initial.height,
        closeTo(GoMateMapDayRoutePanel.collapsedHeightFor(390), 0.1),
      );
      await tester.drag(handle, const Offset(0, -1500));
      await tester.pumpAndSettle();
      final expanded = tester.getRect(panel);
      final headerBottom = 24 + 12 + GoMateMapTripHeader.expandedHeightFor(390);
      expect(expanded.top, closeTo(headerBottom + 8, 0.1));
      expect(expanded.bottom, initial.bottom);
      await tester.drag(handle, const Offset(0, 1500));
      await tester.pumpAndSettle();
      expect(tester.getRect(panel), initial);
      expect(builds, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'swiping list expands sheet, then scrolls to last stop above navigation',
    (tester) async {
      await _panelHarness(tester);
      final initial = tester.getRect(panel);
      await tester.drag(find.text('Place 0'), const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(tester.getRect(panel).height, greaterThan(initial.height));
      await tester.drag(handle, const Offset(0, -1500));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Place 19'),
        200,
        scrollable: find
            .descendant(of: panel, matching: find.byType(Scrollable))
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Place 19')).bottom, lessThan(844 - 88));
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 640), const Size(640, 360)]) {
    testWidgets('empty panel remains draggable and bounded at $size', (
      tester,
    ) async {
      await _panelHarness(tester, size: size, empty: true);
      await tester.drag(handle, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(panel).top,
        closeTo(
          24 + 12 + GoMateMapTripHeader.expandedHeightFor(size.width) + 8,
          0.1,
        ),
      );
      expect(tester.getRect(panel).bottom, size.height);
      await tester.drag(handle, const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('last card clears a tall navigation inset', (tester) async {
    await _panelHarness(tester, bottomInset: 140);
    await tester.drag(handle, const Offset(0, -1500));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Place 19'),
      200,
      scrollable: find
          .descendant(of: panel, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    final card = find
        .ancestor(of: find.text('Place 19'), matching: find.byType(Material))
        .first;
    expect(tester.getRect(card).bottom, lessThanOrEqualTo(844 - 140));
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing callbacks and long-press reorder still work', (
    tester,
  ) async {
    int? tapped;
    int? removed;
    List<int>? reordered;
    var optimized = false;
    await _panelHarness(
      tester,
      canEdit: true,
      onPlaceTap: (i) => tapped = i,
      onRemove: (i) => removed = i,
      onOptimize: () => optimized = true,
      onReorder: (a, b) => reordered = [a, b],
    );
    await tester.drag(handle, const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Place 0'));
    await tester.tap(find.byIcon(LucideIcons.x).first);
    await tester.tap(find.text('Tối ưu lộ trình'));
    expect(tapped, 0);
    expect(removed, 0);
    expect(optimized, isTrue);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Place 0')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(reordered, isNotNull);
    expect(reordered!.first, 0);
    expect(reordered!.last, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only list remains draggable without edit actions', (
    tester,
  ) async {
    var edits = 0;
    await _panelHarness(tester, onPlaceTap: (_) => edits++);
    await tester.tap(find.text('Place 0'));
    expect(edits, 0);
    expect(find.byIcon(LucideIcons.x), findsNothing);
    expect(find.text('Tối ưu lộ trình'), findsNothing);
    await tester.drag(handle, const Offset(0, -150));
    await tester.pumpAndSettle();
    final height = tester.getSize(panel).height;
    await _panelHarness(tester);
    expect(tester.getSize(panel).height, height);
    expect(tester.takeException(), isNull);
  });

  test(
    'switching pin immediately replaces the displayed Trip without tab changes',
    () {
      GoMateMapUiSession.pinTrip(_trip('old'));
      GoMateMapUiSession.selectDay(2);
      final revision = GoMateMapUiSession.revision.value;

      GoMateMapUiSession.pinTrip(_trip('new'));

      expect(GoMateMapUiSession.pinnedTrip!.id, 'new');
      expect(GoMateMapUiSession.displayedTrip!.id, 'new');
      expect(GoMateMapUiSession.displayedTrip!.isActive, isTrue);
      expect(GoMateMapUiSession.selectedDay, 1);
      expect(GoMateMapUiSession.revision.value, revision + 1);
      GoMateMapUiSession.selectDay(2);
      GoMateMapUiSession.pinTrip(_trip('new'));
      expect(GoMateMapUiSession.selectedDay, 2);
    },
  );

  testWidgets('pin waits for ACK, uses selected ID and prevents double tap', (
    tester,
  ) async {
    final trips = _Trips()..response = Completer<TripUi>();
    final location = _Location()..current = Completer<GoMateLocationResult>();
    GoMateMapUiSession.registerTrips([
      _trip('old', pinned: true),
      _trip('new'),
    ]);
    GoMateMapUiSession.pinTrip(_trip('old'));
    GoMateMapUiSession.selectTrip(_trip('new'), day: 2);
    await _pinHarness(tester, trips, location);
    await tester.tap(pin);
    await tester.pump();
    await tester.tap(pin);
    expect(trips.calls, ['new']);
    expect(GoMateMapUiSession.pinnedTrip!.id, 'old');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    trips.response!.complete(_trip('new', pinned: true));
    await tester.pump();
    expect(GoMateMapUiSession.pinnedTrip!.id, 'new');
    expect(GoMateMapUiSession.selectedDay, 2);
    expect(
      GoMateMapUiSession.availableTrips.where((t) => t.isActive).single.id,
      'new',
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<GoMateMapControlButton>(pin).selected, isTrue);
    await tester.tap(pin);
    await tester.pump();
    expect(trips.calls.length, 1);
    expect(trips.unpinCalls, ['new']);
    expect(
      trips.snapshots,
      isEmpty,
    ); // Button never sends GPS itself; the global pin-driven runtime does.
    await tester.pumpAndSettle();
    expect(GoMateMapUiSession.pinnedTrip, isNull);
    expect(tester.widget<GoMateMapControlButton>(pin).selected, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pin API failure retains previous pin and allows retry', (
    tester,
  ) async {
    final trips = _Trips()..fail = true;
    final location = _Location();
    GoMateMapUiSession.registerTrips([
      _trip('old', pinned: true),
      _trip('new'),
    ]);
    GoMateMapUiSession.pinTrip(_trip('old'));
    await _pinHarness(tester, trips, location);
    await tester.tap(pin);
    await tester.pumpAndSettle();
    expect(GoMateMapUiSession.pinnedTrip!.id, 'old');
    expect(GoMateMapUiSession.displayedTrip!.id, 'old');
    expect(find.textContaining('fixture network failure'), findsOneWidget);
    trips.fail = false;
    await tester.tap(pin);
    await tester.pumpAndSettle();
    expect(GoMateMapUiSession.pinnedTrip!.id, 'new');
    expect(GoMateMapUiSession.displayedTrip!.id, 'new');
    expect(trips.calls, ['new', 'new']);
  });

  testWidgets(
    'unpin waits for ACK, skips GPS and preserves the viewed day/stops',
    (tester) async {
      final trips = _Trips()..unpinResponse = Completer<void>();
      final location = _Location()..state = GoMateLocationState.serviceOff;
      GoMateMapUiSession.registerTrips([_trip('new', pinned: true)]);
      GoMateMapUiSession.pinTrip(_trip('new'));
      GoMateMapUiSession.selectTrip(_trip('new', pinned: true), day: 2);
      await _pinHarness(tester, trips, location);
      expect(find.byTooltip('Bỏ ghim lịch trình'), findsOneWidget);
      await tester.tap(pin);
      await tester.pump();
      await tester.tap(pin);
      expect(trips.unpinCalls, ['new']);
      expect(location.checks, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(GoMateMapUiSession.pinnedTrip!.id, 'new');
      GoMateMapUiSession.updateTrip(
        _trip('new', pinned: true).copyWith(
          places: const [
            TripPlaceUi(id: 'stop', placeId: '7', name: 'Updated stop', day: 2),
          ],
        ),
      );
      trips.unpinResponse!.complete();
      await tester.pumpAndSettle();
      expect(GoMateMapUiSession.pinnedTrip, isNull);
      expect(GoMateMapUiSession.selectedTrip!.id, 'new');
      expect(GoMateMapUiSession.selectedTrip!.isActive, isFalse);
      expect(
        GoMateMapUiSession.selectedTrip!.places.single.name,
        'Updated stop',
      );
      expect(GoMateMapUiSession.selectedDay, 2);
      expect(GoMateMapUiSession.availableTrips.single.isActive, isFalse);
      expect(tester.widget<GoMateMapControlButton>(pin).selected, isFalse);
      expect(find.byTooltip('Ghim lịch trình đang xem'), findsOneWidget);
      expect(find.text('Đã bỏ ghim lịch trình'), findsOneWidget);
      expect(trips.calls, isEmpty);
      expect(trips.snapshots, isEmpty);
    },
  );

  testWidgets(
    'unpin failure retains pin and allows retry without location permission',
    (tester) async {
      final trips = _Trips()..failUnpin = true;
      final location = _Location()
        ..state = GoMateLocationState.permissionDeniedForever;
      GoMateMapUiSession.registerTrips([_trip('new', pinned: true)]);
      GoMateMapUiSession.pinTrip(_trip('new'));
      await _pinHarness(tester, trips, location);
      await tester.tap(pin);
      await tester.pumpAndSettle();
      expect(GoMateMapUiSession.pinnedTrip!.id, 'new');
      expect(GoMateMapUiSession.selectedTrip!.isActive, isTrue);
      expect(tester.widget<GoMateMapControlButton>(pin).selected, isTrue);
      expect(find.textContaining('fixture unpin failure'), findsOneWidget);
      trips.failUnpin = false;
      await tester.tap(pin);
      await tester.pumpAndSettle();
      expect(trips.unpinCalls, ['new', 'new']);
      expect(GoMateMapUiSession.pinnedTrip, isNull);
      expect(location.checks, 0);
      expect(location.appSettings, 0);
      expect(location.gpsSettings, 0);
    },
  );

  testWidgets('unpin ACK survives button disposal', (tester) async {
    final trips = _Trips()..unpinResponse = Completer<void>();
    GoMateMapUiSession.registerTrips([_trip('new', pinned: true)]);
    GoMateMapUiSession.pinTrip(_trip('new'));
    await _pinHarness(tester, trips, _Location());
    await tester.tap(pin);
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    trips.unpinResponse!.complete();
    await tester.pumpAndSettle();
    expect(GoMateMapUiSession.pinnedTrip, isNull);
    expect(GoMateMapUiSession.selectedTrip!.isActive, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final pinOther in [false, true]) {
    testWidgets(
      'unpin ACK preserves changed selection and newer pin: $pinOther',
      (tester) async {
        final trips = _Trips()..unpinResponse = Completer<void>();
        GoMateMapUiSession.registerTrips([
          _trip('new', pinned: true),
          _trip('other'),
        ]);
        GoMateMapUiSession.pinTrip(_trip('new'));
        await _pinHarness(tester, trips, _Location());
        await tester.tap(pin);
        await tester.pump();
        GoMateMapUiSession.selectTrip(_trip('other'), day: 2);
        if (pinOther) {
          GoMateMapUiSession.pinTrip(_trip('other', pinned: true));
        }
        await _pinHarness(tester, trips, _Location(), id: 'other');
        trips.unpinResponse!.complete();
        await tester.pumpAndSettle();
        expect(trips.unpinCalls, ['new']);
        expect(GoMateMapUiSession.displayedTrip!.id, 'other');
        expect(GoMateMapUiSession.selectedDay, 2);
        expect(GoMateMapUiSession.pinnedTrip?.id, pinOther ? 'other' : null);
        expect(tester.widget<GoMateMapControlButton>(pin).selected, pinOther);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final state in [
    GoMateLocationState.serviceOff,
    GoMateLocationState.whileInUseOnly,
    GoMateLocationState.permissionDenied,
    GoMateLocationState.permissionDeniedForever,
  ]) {
    testWidgets('pin respects existing permission gate: $state', (
      tester,
    ) async {
      final trips = _Trips();
      final location = _Location()..state = state;
      await _pinHarness(tester, trips, location);
      await tester.tap(pin);
      await tester.pumpAndSettle();
      expect(trips.calls, isEmpty);
      expect(GoMateMapUiSession.pinnedTrip, isNull);
      expect(
        location.gpsSettings,
        state == GoMateLocationState.serviceOff ? 1 : 0,
      );
      expect(
        location.appSettings,
        state == GoMateLocationState.whileInUseOnly ||
                state == GoMateLocationState.permissionDeniedForever
            ? 1
            : 0,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  }

  testWidgets('successful ACK survives button disposal', (tester) async {
    final trips = _Trips()..response = Completer<TripUi>();
    await _pinHarness(tester, trips, _Location());
    await tester.tap(pin);
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    trips.response!.complete(_trip('new', pinned: true));
    await tester.pumpAndSettle();
    expect(GoMateMapUiSession.pinnedTrip!.id, 'new');
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection change during request does not pin the wrong trip', (
    tester,
  ) async {
    final trips = _Trips()..response = Completer<TripUi>();
    GoMateMapUiSession.registerTrips([_trip('new'), _trip('other')]);
    GoMateMapUiSession.selectTrip(_trip('new'));
    await _pinHarness(tester, trips, _Location());
    await tester.tap(pin);
    await tester.pump();
    GoMateMapUiSession.selectTrip(_trip('other'), day: 2);
    await _pinHarness(tester, trips, _Location(), id: 'other');
    trips.response!.complete(_trip('new', pinned: true));
    await tester.pumpAndSettle();
    expect(trips.calls, ['new']);
    expect(GoMateMapUiSession.pinnedTrip!.id, 'new');
    expect(GoMateMapUiSession.displayedTrip!.id, 'other');
    expect(GoMateMapUiSession.selectedDay, 2);
    expect(tester.widget<GoMateMapControlButton>(pin).selected, isFalse);
  });

  testWidgets(
    'pin button delegates GPS publishing to the single global coordinator',
    (tester) async {
      final trips = _Trips();
      final location = _Location()..current = Completer<GoMateLocationResult>();
      await _pinHarness(tester, trips, location);
      await tester.tap(pin);
      await tester.pump();
      location.current!.complete(
        GoMateLocationResult(
          GoMateLocationState.ready,
          geo.Position(
            latitude: 11.94,
            longitude: 108.44,
            timestamp: DateTime.utc(2026),
            accuracy: 5,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(trips.snapshots, isEmpty);
      expect(GoMateMapUiSession.pinnedTrip!.id, 'new');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pin follows location without a gap for missing chat; chat is last',
    (tester) async {
      Widget controls({bool extra = false, bool chat = false}) => MaterialApp(
        home: Scaffold(
          body: GoMateMapControls(
            onSearch: () {},
            onTripPicker: () {},
            onLocation: () {},
            onCompass: () {},
            showCompass: false,
            bearing: 0,
            onChat: chat ? () {} : null,
            pinButton: extra
                ? const GoMateMapControlButton(
                    icon: LucideIcons.pin,
                    onTap: null,
                  )
                : null,
          ),
        ),
      );
      await tester.pumpWidget(controls());
      final before = tester.getRect(find.byIcon(LucideIcons.search));
      expect(find.byIcon(LucideIcons.pin), findsNothing);
      await tester.pumpWidget(controls(extra: true));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byIcon(LucideIcons.search)), before);
      expect(find.byIcon(LucideIcons.message_circle), findsNothing);
      final pinRect = tester.getRect(
        find.widgetWithIcon(GoMateMapControlButton, LucideIcons.pin),
      );
      final locationRect = tester.getRect(
        find.widgetWithIcon(GoMateMapControlButton, LucideIcons.locate_fixed),
      );
      final width = MediaQuery.sizeOf(
        tester.element(find.byType(GoMateMapControls)),
      ).width;
      expect(
        pinRect.top - locationRect.bottom,
        closeTo((width * 0.028).clamp(9.0, 12.0), 0.01),
      );
      await tester.pumpWidget(controls(extra: true, chat: true));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(
          find.widgetWithIcon(GoMateMapControlButton, LucideIcons.pin),
        ),
        pinRect,
      );
      expect(
        tester.getRect(find.byIcon(LucideIcons.message_circle)).top,
        greaterThan(tester.getRect(find.byIcon(LucideIcons.pin)).bottom),
      );
    },
  );
}
