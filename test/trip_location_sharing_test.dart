import 'package:gomate/core/services/content_access_changes.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/network/api_exception.dart';
import 'package:gomate/features/map/models/map_member.dart';
import 'package:gomate/features/map/services/mapbox_layer_controller.dart';
import 'package:gomate/features/map/state/map_ui_session.dart';
import 'package:gomate/features/map/utils/last_known_location_label.dart';
import 'package:gomate/features/trip/models/trip_ui_models.dart';
import 'package:gomate/features/trip/data/trip_repository.dart';
import 'package:gomate/features/trip/location/location_runtime_driver.dart';
import 'package:gomate/features/trip/location/location_runtime_models.dart';
import 'package:gomate/features/trip/location/location_publishing_repository.dart';
import 'package:gomate/features/trip/location/trip_location_publishing_service.dart';
import 'package:gomate/features/trip/location/trip_location_realtime_service.dart';

const id = '11111111-1111-4111-8111-111111111111';
const trip = TripUi(
  id: id,
  title: 'Location Trip',
  days: 2,
  destination: 'Test',
  isGroup: true,
);
final DateTime epoch = DateTime.utc(2026, 10, 16);
// Runtime fixtures use an actual timestamp; no default coordinate is used by app code.
final fix = TripLocationSample(11.94, 108.44, 12, epoch);

class _Auth extends AuthService {
  String? actor = 'b';
  final pins = <String, TripUi>{};
  bool failUnpin = false;
  Completer<void>? unpinGate;
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final user = actor!;
    final tripId = path.split('/')[2];
    if (method == 'DELETE') {
      await unpinGate?.future;
      if (failUnpin) throw StateError('offline');
      if (pins[user]?.id == tripId) pins.remove(user);
      return {};
    }
    pins[user] = trip.copyWith(id: tripId);
    return {
      'id': tripId,
      'title': 'Location Trip',
      'pinned': true,
      'tripType': 'GROUP',
      'members': [
        {'userId': user, 'role': 'MEMBER'},
      ],
    };
  }

  @override
  bool get signedIn => actor != null;
  @override
  Map<String, dynamic>? get user =>
      actor == null ? null : {'id': actor, 'displayName': actor};
  void switchUser(String? id) {
    actor = id;
    notifyListeners();
  }
}

class _Store extends PendingUnpinStore {
  final Map<String, Set<String>> trips = {};
  @override
  Future<Set<String>> pendingTrips(String id) async => Set.of(trips[id] ?? {});
  @override
  Future<void> setTripPending(String user, String id, bool v) async {
    final rows = trips.putIfAbsent(user, () => {});
    if (v) {
      rows.add(id);
    } else {
      rows.remove(id);
    }
  }
}

class _Driver implements TripLocationDriver {
  TripLocationCapability cap = const TripLocationCapability(
    serviceOn: true,
    foregroundAllowed: true,
    backgroundAllowed: true,
    android: true,
  );
  final service = StreamController<bool>.broadcast(sync: true);
  late final fixes = StreamController<TripLocationSample>.broadcast(
    sync: true,
    onCancel: () {
      backgroundStops++;
    },
  );
  int backgroundStarts = 0;
  int backgroundStops = 0;
  int samples = 0;
  Duration? interval;
  Completer<TripLocationSample>? gate;
  @override
  Future<TripLocationCapability> capability({bool request = false}) async =>
      cap;
  @override
  Future<TripLocationSample> current() async {
    samples++;
    return gate == null ? fix : await gate!.future;
  }

  @override
  Stream<bool> serviceChanges() => service.stream;
  @override
  Stream<TripLocationSample> backgroundPositions(Duration cadence) {
    interval = cadence;
    backgroundStarts++;
    return fixes.stream;
  }

  void dispose() {
    unawaited(service.close());
    unawaited(fixes.close());
  }
}

class _Repo extends TripLocationPublishingRepository {
  _Repo(this.auth);
  final _Auth auth;
  bool fail = false;
  int? publishError;
  final List<String> publishes = [];
  @override
  Future<TripUi?> pinned() async {
    if (fail) throw StateError('offline');
    return auth.pins[auth.actor];
  }

  @override
  Future<void> unpin(String id) => RealTripRepository(auth: auth).unpin(id);
  @override
  Future<DateTime> publish(
    String id,
    TripLocationSample sample, {
    required bool background,
  }) async {
    if (fail) throw StateError('offline');
    if (publishError != null) {
      throw ApiException(publishError!, 'NOT_FOUND', 'revoked');
    }
    publishes.add('${auth.actor}:$id:$background');
    return epoch.add(Duration(seconds: publishes.length));
  }
}

class _Fixture {
  bool _disposed = false;
  final auth = _Auth();
  final driver = _Driver();
  final store = _Store();
  late final repo = _Repo(auth);
  late final publishing = TripLocationPublishingService(
    auth: auth,
    repository: repo,
    driver: driver,
    unpinStore: store,
  );
  Future<void> start(WidgetTester tester, {bool pin = false}) async {
    publishing.start();
    await flush(tester);
    GoMateMapUiSession.registerTrips([trip]);
    GoMateMapUiSession.selectTrip(trip);
    if (pin) {
      await RealTripRepository(auth: auth).pin(id);
    }
    GoMateMapUiSession.mapVisible.value = true;
    await publishing.reconcile();
    await flush(tester);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    publishing.dispose();
    driver.dispose();
    auth.dispose();
    GoMateMapUiSession.mapVisible.value = false;
    GoMateMapUiSession.clearUserState();
  }
}

Future<void> flush(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  for (int i = 0; i < 12; i++) {
    await tester.pump();
  }
}

class _Channel implements TripLocationEventClient {
  int connects = 0;
  int disconnects = 0;
  final List<StreamController<TripLocationSignal>> streams = [];
  @override
  Stream<TripLocationSignal> connect(String id) {
    connects++;
    final s = StreamController<TripLocationSignal>.broadcast(sync: true);
    streams.add(s);
    return s.stream;
  }

  @override
  void disconnect() {
    disconnects++;
  }

  void dispose() {
    for (final s in streams) {
      unawaited(s.close());
    }
  }
}

GoMateMapMember member(String user, {double lat = 11.9}) => GoMateMapMember(
  userId: user,
  displayName: user,
  assetIcon: 'fixture-missing.png',
  position: mapbox.Position(108.4, lat),
  updatedAt: epoch,
  isStale: true,
);

class _Annotations implements mapbox.PointAnnotationManager {
  int creates = 0;
  int deletes = 0;
  int clears = 0;
  final List<String> updates = [];
  @override
  Future<mapbox.PointAnnotation> create(mapbox.PointAnnotationOptions o) async {
    creates++;
    return mapbox.PointAnnotation(
      id: 'native-$creates',
      geometry: o.geometry,
      image: o.image,
      iconSize: o.iconSize,
    );
  }

  @override
  Future<void> update(mapbox.PointAnnotation a) async {
    updates.add(a.id);
  }

  @override
  Future<void> delete(mapbox.PointAnnotation a) async {
    deletes++;
  }

  @override
  Future<void> deleteAll() async {
    clears++;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugPrint = debugPrintSynchronously;
  setUp(GoMateMapUiSession.clearUserState);
  tearDown(GoMateMapUiSession.clearUserState);
  testWidgets('View/detail without own pin never starts location publishing', (
    tester,
  ) async {
    final f = _Fixture();
    addTearDown(f.dispose);
    await f.start(tester);
    f.publishing.enterTripDetail(id);
    await tester.pump(const Duration(seconds: 61));
    await flush(tester);
    expect(f.repo.publishes, isEmpty);
    expect(f.driver.backgroundStarts, 0);
    f.dispose();
  });
  testWidgets('Pin alone starts existing 15s clock and one 60s native stream', (
    tester,
  ) async {
    final f = _Fixture();
    addTearDown(f.dispose);
    await f.start(tester, pin: true);
    final before = f.repo.publishes.length;
    expect(before, 1);
    for (int i = 0; i < 5; i++) {
      GoMateMapUiSession.selectTrip(trip);
      await flush(tester);
    }
    await tester.pump(const Duration(seconds: 14));
    await flush(tester);
    expect(f.repo.publishes.length, before);
    await tester.pump(const Duration(seconds: 1));
    await flush(tester);
    expect(f.repo.publishes.length, before + 1);
    expect(
      f.publishing.lastAcceptedAt,
      epoch.add(Duration(seconds: before + 1)),
    );
    expect(f.driver.backgroundStarts, 1);
    expect(f.driver.interval, const Duration(seconds: 60));
    f.dispose();
  });
  testWidgets('Unpin pauses before API ACK while UI retains server truth', (
    tester,
  ) async {
    final f = _Fixture();
    addTearDown(f.dispose);
    await f.start(tester, pin: true);
    f.auth.unpinGate = Completer<void>();
    final done = RealTripRepository(auth: f.auth).unpin(id);
    await flush(tester);
    expect(GoMateMapUiSession.pinnedTrip?.id, id);
    expect(f.publishing.backgroundRunning, false);
    final sent = f.repo.publishes.length;
    await tester.pump(const Duration(seconds: 5));
    await flush(tester);
    expect(f.repo.publishes.length, sent);
    f.auth.unpinGate!.complete();
    await flush(tester);
    await done;
    expect(GoMateMapUiSession.pinnedTrip, isNull);
    expect(await f.store.pendingTrips('b'), isEmpty);
    f.dispose();
  });
  testWidgets(
    'Failed unpin stays suspended and retry metadata is account scoped',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.start(tester, pin: true);
      f.auth.failUnpin = true;
      Object? failure;
      unawaited(
        RealTripRepository(auth: f.auth).unpin(id).catchError((Object e) {
          failure = e;
        }),
      );
      await flush(tester);
      expect(failure, isNotNull);
      expect(f.publishing.suspended, true);
      expect(GoMateMapUiSession.pinnedTrip?.id, id);
      final count = f.repo.publishes.length;
      await tester.pump(const Duration(seconds: 31));
      await flush(tester);
      expect(f.repo.publishes.length, count);
      expect(await f.store.pendingTrips('b'), contains(id));
      f.auth.switchUser('c');
      await flush(tester);
      expect(await f.store.pendingTrips('c'), isEmpty);
      expect(GoMateMapUiSession.pinnedTrip, isNull);
      f.auth.failUnpin = false;
      f.auth.switchUser('b');
      await flush(tester);
      expect(GoMateMapUiSession.pinnedTrip, isNull);
      expect(await f.store.pendingTrips('b'), isEmpty);
      f.dispose();
    },
  );
  testWidgets(
    'Background callbacks stop on unpin and resume on explicit re-pin',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.start(tester, pin: true);
      f.publishing.didChangeAppLifecycleState(AppLifecycleState.paused);
      f.driver.fixes.add(fix);
      await flush(tester);
      expect(f.repo.publishes.last, endsWith(':true'));
      unawaited(RealTripRepository(auth: f.auth).unpin(id));
      await flush(tester);
      final sent = f.repo.publishes.length;
      f.driver.fixes.add(fix);
      await tester.pump(const Duration(seconds: 61));
      await flush(tester);
      expect(f.repo.publishes.length, sent);
      expect(f.publishing.backgroundRunning, false);
      f.publishing.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await flush(tester);
      await RealTripRepository(auth: f.auth).pin(id);
      await flush(tester);
      expect(f.publishing.backgroundRunning, true);
      f.dispose();
    },
  );
  testWidgets('Native stream failure has no immediate restart loop', (
    tester,
  ) async {
    final f = _Fixture();
    addTearDown(f.dispose);
    await f.start(tester, pin: true);
    f.driver.fixes.addError(StateError('unavailable'));
    await flush(tester);
    expect(f.publishing.backgroundRunning, false);
    await tester.pump(const Duration(seconds: 14));
    await flush(tester);
    expect(f.driver.backgroundStarts, 1);
    f.dispose();
  });
  for (final serviceOff in [false, true]) {
    testWidgets(
      'Capability loss suspends but never unpins, serviceOff=$serviceOff',
      (tester) async {
        final f = _Fixture();
        addTearDown(f.dispose);
        await f.start(tester, pin: true);
        f.driver.cap = TripLocationCapability(
          serviceOn: !serviceOff,
          foregroundAllowed: false,
          backgroundAllowed: false,
          android: true,
        );
        if (serviceOff) {
          f.driver.service.add(false);
        } else {
          unawaited(f.publishing.reconcile());
        }
        await flush(tester);
        final sent = f.repo.publishes.length;
        await tester.pump(const Duration(seconds: 61));
        await flush(tester);
        expect(f.repo.publishes.length, sent);
        expect(f.publishing.backgroundRunning, false);
        expect(GoMateMapUiSession.pinnedTrip?.id, id);
        f.driver.cap = const TripLocationCapability(
          serviceOn: true,
          foregroundAllowed: true,
          backgroundAllowed: true,
          android: true,
        );
        f.publishing.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await flush(tester);
        expect(f.publishing.backgroundRunning, true);
        f.dispose();
      },
    );
  }
  testWidgets('WhileUsing alone cannot run a restored Android pin', (
    tester,
  ) async {
    final f = _Fixture();
    addTearDown(f.dispose);
    f.driver.cap = const TripLocationCapability(
      serviceOn: true,
      foregroundAllowed: true,
      backgroundAllowed: false,
      android: true,
    );
    await f.start(tester, pin: true);
    expect(f.repo.publishes, isEmpty);
    expect(f.publishing.backgroundRunning, false);
    expect(GoMateMapUiSession.pinnedTrip?.id, id);
    f.dispose();
  });
  testWidgets(
    'Logout stops only local runtime and restores same server pin on login',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.start(tester, pin: true);
      for (final callback in f.auth.beforeLogout) {
        await callback();
      }
      final sent = f.repo.publishes.length;
      f.driver.fixes.add(fix);
      await tester.pump(const Duration(seconds: 61));
      await flush(tester);
      expect(f.repo.publishes.length, sent);
      expect(f.auth.pins['b']?.id, id);
      expect(await f.store.pendingTrips('b'), isEmpty);
      f.auth.switchUser('c');
      await flush(tester);
      expect(GoMateMapUiSession.pinnedTrip, isNull);
      f.auth.switchUser('b');
      await flush(tester);
      expect(GoMateMapUiSession.pinnedTrip?.id, id);
      expect(f.publishing.backgroundRunning, true);
      f.dispose();
    },
  );
  testWidgets('Resume reconciles remote unpin before restarting runtime', (
    tester,
  ) async {
    final f = _Fixture();
    addTearDown(f.dispose);
    await f.start(tester, pin: true);
    f.publishing.didChangeAppLifecycleState(AppLifecycleState.paused);
    f.auth.pins.clear();
    f.publishing.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await flush(tester);
    final count = f.repo.publishes.length;
    await tester.pump(const Duration(seconds: 31));
    await flush(tester);
    expect(f.repo.publishes.length, count);
    expect(f.publishing.backgroundRunning, false);
    f.dispose();
  });
  for (final action in ['unpin', 'switchPin', 'switchAccount', 'permission']) {
    testWidgets('Late GPS sample is discarded after $action', (tester) async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.start(tester);
      f.driver.gate = Completer<TripLocationSample>();
      await RealTripRepository(auth: f.auth).pin(id);
      await flush(tester);
      switch (action) {
        case 'unpin':
          unawaited(RealTripRepository(auth: f.auth).unpin(id));
          break;
        case 'switchPin':
          await RealTripRepository(auth: f.auth).pin('other');
          break;
        case 'switchAccount':
          f.auth.switchUser('c');
          break;
        default:
          f.driver.cap = const TripLocationCapability(
            serviceOn: false,
            foregroundAllowed: false,
            backgroundAllowed: false,
            android: true,
          );
      }
      await flush(tester);
      f.driver.gate!.complete(fix);
      await flush(tester);
      expect(f.repo.publishes, isEmpty);
      f.dispose();
    });
  }
  testWidgets(
    'Unrelated Trip refresh/unpin cannot replace pin or restart native driver',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.start(tester, pin: true);
      GoMateMapUiSession.updateTrip(trip.copyWith(id: 'other', isActive: true));
      unawaited(RealTripRepository(auth: f.auth).unpin('other'));
      await flush(tester);
      expect(GoMateMapUiSession.pinnedTrip?.id, id);
      expect(f.driver.backgroundStarts, 1);
      f.dispose();
    },
  );
  testWidgets('Passive pin restore preserves a different viewed Trip and day', (
    tester,
  ) async {
    final f = _Fixture();
    addTearDown(f.dispose);
    await f.start(tester, pin: true);
    final preview = trip.copyWith(id: 'preview');
    GoMateMapUiSession.updateTrip(preview);
    GoMateMapUiSession.selectTrip(preview, day: 2);
    f.publishing.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await flush(tester);
    expect(GoMateMapUiSession.pinnedTrip?.id, id);
    expect(GoMateMapUiSession.displayedTrip?.id, 'preview');
    expect(GoMateMapUiSession.selectedDay, 2);
    expect(f.driver.backgroundStarts, 1);
    f.dispose();
  });

  testWidgets(
    'Pin switch retargets visible Map SSE immediately and ignores old REST response',
    (tester) async {
      final auth = _Auth();
      final channel = _Channel();
      final oldResponse = Completer<List<GoMateMapMember>>();
      final loads = <String>[];
      final realtime = TripLocationRealtimeService(
        auth: auth,
        client: channel,
        loadMembers: (target) async {
          loads.add(target);
          return target == id ? oldResponse.future : [member('new-member')];
        },
      );
      addTearDown(() {
        realtime.dispose();
        channel.dispose();
        auth.dispose();
        GoMateMapUiSession.mapVisible.value = false;
        GoMateMapUiSession.clearUserState();
      });
      GoMateMapUiSession.pinTrip(trip);
      GoMateMapUiSession.mapVisible.value = true;
      realtime.start();
      await flush(tester);
      await RealTripRepository(auth: auth).pin('new-trip');
      await flush(tester);
      expect(GoMateMapUiSession.displayedTrip?.id, 'new-trip');
      expect(realtime.target, 'new-trip');
      expect(realtime.snapshot.members.single.userId, 'new-member');
      expect(loads, [id, 'new-trip']);
      expect(channel.connects, 2);
      oldResponse.complete([member('old-member')]);
      await flush(tester);
      expect(realtime.snapshot.members.single.userId, 'new-member');
      // Same pin ACK/ordinary refresh must not reconnect or add REST calls.
      GoMateMapUiSession.pinTrip(trip.copyWith(id: 'new-trip'));
      await flush(tester);
      expect(loads, [id, 'new-trip']);
      expect(channel.connects, 2);
      GoMateMapUiSession.mapVisible.value = false;
      await flush(tester);
    },
  );

  testWidgets(
    'Global Block invalidation discards stale REST without touching Pin or publisher',
    (tester) async {
      final auth = _Auth();
      final channel = _Channel();
      final old = Completer<List<GoMateMapMember>>();
      int loads = 0;
      final realtime = TripLocationRealtimeService(
        auth: auth,
        client: channel,
        loadMembers: (_) async {
          loads++;
          if (loads == 2) return old.future;
          return loads == 1
              ? [member('blocked-b'), member('allowed-c')]
              : [member('allowed-c')];
        },
      );
      addTearDown(() {
        realtime.dispose();
        channel.dispose();
        auth.dispose();
        GoMateMapUiSession.mapVisible.value = false;
        GoMateMapUiSession.clearUserState();
      });
      GoMateMapUiSession.pinTrip(trip);
      GoMateMapUiSession.mapVisible.value = true;
      realtime.start();
      await flush(tester);
      expect(realtime.snapshot.members.length, 2);
      unawaited(realtime.refresh());
      await flush(tester);
      ContentAccessChanges.changed();
      await flush(tester);
      expect(realtime.snapshot.members.map((m) => m.userId), ['allowed-c']);
      old.complete([member('blocked-b'), member('allowed-c')]);
      await flush(tester);
      expect(realtime.snapshot.members.map((m) => m.userId), ['allowed-c']);
      expect(GoMateMapUiSession.pinnedTrip?.id, id);
      expect(channel.connects, 1);
      final before = loads;
      channel.streams.last.add(
        const TripLocationSignal(tripId: id, accessChanged: true),
      );
      await flush(tester);
      expect(loads, before + 1);
      expect(GoMateMapUiSession.pinnedTrip?.id, id);
      GoMateMapUiSession.mapVisible.value = false;
      await flush(tester);
    },
  );

  testWidgets('Explicit same-Trip re-pin resumes a failed-unpin suspension', (
    tester,
  ) async {
    final f = _Fixture();
    addTearDown(f.dispose);
    await f.start(tester, pin: true);
    f.auth.failUnpin = true;
    unawaited(
      RealTripRepository(auth: f.auth).unpin(id).catchError((Object _) {}),
    );
    await flush(tester);
    expect(f.publishing.suspended, true);
    await RealTripRepository(auth: f.auth).pin(id);
    await flush(tester);
    expect(f.publishing.suspended, false);
    expect(f.publishing.backgroundRunning, true);
    expect(await f.store.pendingTrips('b'), isEmpty);
    f.dispose();
  });
  testWidgets(
    'Unavailable SSE removes current Trip/runtime; view-only still receives location updates',
    (tester) async {
      final f = _Fixture();
      addTearDown(f.dispose);
      await f.start(tester, pin: true);
      final channel = _Channel();
      int reads = 0;
      final realtime = TripLocationRealtimeService(
        auth: f.auth,
        publishing: f.publishing,
        client: channel,
        loadMembers: (_) async {
          reads++;
          return [member('a')];
        },
      );
      realtime.start();
      await flush(tester);
      expect(realtime.target, id);
      channel.streams.last.add(
        TripLocationSignal(tripId: id, userId: 'a', updatedAt: epoch),
      );
      await flush(tester);
      expect(reads, 2);
      expect(channel.connects, 1);
      channel.streams.last.add(
        const TripLocationSignal(tripId: id, unavailable: true),
      );
      await flush(tester);
      expect(realtime.target, isNull);
      expect(realtime.snapshot.members, isEmpty);
      expect(f.publishing.backgroundRunning, false);
      realtime.dispose();
      channel.dispose();
      f.dispose();
    },
  );
  testWidgets(
    'F11 F13 F15 F16 one trip SSE, only location REST, no fake marker or old-target leakage',
    (tester) async {
      final auth = _Auth();
      final channel = _Channel();
      int loads = 0;
      final realtime = TripLocationRealtimeService(
        auth: auth,
        client: channel,
        loadMembers: (_) async {
          loads++;
          return [member('b')];
        },
      );
      final batches = <TripMemberLocationSnapshot>[];
      final sub = realtime.updates.listen(batches.add);
      addTearDown(() {
        unawaited(sub.cancel());
        realtime.dispose();
        channel.dispose();
        auth.dispose();
        GoMateMapUiSession.mapVisible.value = false;
        GoMateMapUiSession.clearUserState();
      });
      GoMateMapUiSession.registerTrips([trip]);
      GoMateMapUiSession.selectTrip(trip);
      GoMateMapUiSession.mapVisible.value = true;
      realtime.start();
      await flush(tester);
      for (int i = 0; i < 10; i++) {
        GoMateMapUiSession.selectTrip(trip);
      }
      await flush(tester);
      expect(channel.connects, 1);
      expect(loads, 1);
      channel.streams.last.add(
        TripLocationSignal(tripId: id, userId: 'b', updatedAt: epoch),
      );
      await flush(tester);
      expect(loads, 2);
      expect(batches.last.members.single.userId, 'b');
      GoMateMapUiSession.mapVisible.value = false;
      await flush(tester);
      channel.streams.first.add(
        TripLocationSignal(tripId: id, userId: 'b', updatedAt: epoch),
      );
      await flush(tester);
      expect(loads, 2);
      expect(batches.last.members, isEmpty);
    },
  );
  testWidgets(
    'F12 F16 incremental marker update does not delete/recreate others or touch route',
    (tester) async {
      final native = _Annotations();
      final layers = GoMateMapboxLayerController(memberManager: native);
      addTearDown(layers.dispose);
      await tester.runAsync(
        () => layers.showPreviewMembers([
          member('a'),
          member('b'),
        ], currentUserId: 'viewer'),
      );
      expect(native.creates, 2);
      expect(native.clears, 0);
      await tester.runAsync(
        () => layers.showPreviewMembers([
          member('a', lat: 12),
          member('b'),
        ], currentUserId: 'viewer'),
      );
      expect(native.creates, 2);
      expect(native.updates, ['native-1']);
      expect(native.clears, 0);
      await layers.setMapInteractionActive(true);
      await layers.showPreviewMembers([
        member('a', lat: 13),
        member('b'),
      ], currentUserId: 'viewer');
      expect(native.updates.length, 1);
      await tester.runAsync(() => layers.setMapInteractionActive(false));
      expect(native.updates.length, 2);
      await layers.hidePreviewMembers();
      expect(native.clears, 1);
    },
  );
  testWidgets(
    'Location signal during REST reconciles once after in-flight read',
    (tester) async {
      final auth = _Auth();
      final channel = _Channel();
      final gate = Completer<List<GoMateMapMember>>();
      int loads = 0;
      final realtime = TripLocationRealtimeService(
        auth: auth,
        client: channel,
        loadMembers: (_) async {
          loads++;
          return loads == 1 ? gate.future : [member('b', lat: 12)];
        },
      );
      GoMateMapUiSession.selectTrip(trip);
      GoMateMapUiSession.mapVisible.value = true;
      realtime.start();
      await flush(tester);
      channel.streams.last.add(
        TripLocationSignal(tripId: id, userId: 'b', updatedAt: epoch),
      );
      channel.streams.last.add(
        TripLocationSignal(tripId: id, userId: 'b', updatedAt: epoch),
      );
      await flush(tester);
      expect(loads, 1);
      gate.complete([member('b')]);
      await flush(tester);
      expect(loads, 2);
      expect(realtime.snapshot.members.single.position.lat, 12);
      realtime.dispose();
      channel.dispose();
      auth.dispose();
      GoMateMapUiSession.mapVisible.value = false;
      GoMateMapUiSession.clearUserState();
    },
  );
  test('F17 last-known age has no LIVE or invented stale cutoff', () {
    expect(
      lastKnownLocationLabel(epoch, now: epoch.add(const Duration(minutes: 2))),
      '2 phút trước',
    );
    expect(lastKnownLocationLabel(epoch, now: epoch), 'Vừa cập nhật');
    expect(
      lastKnownLocationLabel(epoch, now: epoch.add(const Duration(hours: 18))),
      '18 giờ trước',
    );
  });
}
