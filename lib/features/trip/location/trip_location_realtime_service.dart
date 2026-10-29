import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../../../core/network/api_exception.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/content_access_changes.dart';
import '../../map/data/spring_map_gateway.dart';
import '../../map/models/map_member.dart';
import '../../map/state/map_ui_session.dart';
import 'trip_location_publishing_service.dart';

class TripLocationSignal {
  const TripLocationSignal({
    this.tripId,
    this.userId,
    this.updatedAt,
    this.unavailable = false,
    this.accessChanged = false,
  });
  final String? tripId;
  final String? userId;
  final DateTime? updatedAt;
  final bool unavailable;
  final bool accessChanged;
}

abstract class TripLocationEventClient {
  Stream<TripLocationSignal> connect(String tripId);
  void disconnect();
}

class SseTripLocationEventClient implements TripLocationEventClient {
  SseTripLocationEventClient(this.auth, {http.Client Function()? clientFactory})
    : _factory = clientFactory ?? http.Client.new;
  final AuthService auth;
  final http.Client Function() _factory;
  http.Client? _client;
  int _generation = 0;
  @override
  Stream<TripLocationSignal> connect(String tripId) {
    disconnect();
    final client = _factory();
    _client = client;
    return _read(client, tripId, _generation);
  }

  Stream<TripLocationSignal> _read(
    http.Client client,
    String tripId,
    int generation,
  ) async* {
    try {
      final response = await auth.openEventStream(
        client,
        path: '/trips/$tripId/locations/stream',
      );
      String type = '';
      final data = <String>[];
      int length = 0;
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(const Duration(seconds: 45))) {
        if (generation != _generation) return;
        if (line.isEmpty) {
          if (type == 'ready') {
            yield const TripLocationSignal();
          } else if ((type == 'tripLocationUpdated' ||
                  type == 'tripLocationRemoved' ||
                  type == 'tripLocationsInvalidated' ||
                  type == 'tripUnavailable') &&
              data.isNotEmpty) {
            final json = jsonDecode(data.join('\n')) as Map;
            if (type == 'tripLocationsInvalidated' &&
                json['eventKind'] == type &&
                json['tripId'] == tripId) {
              yield TripLocationSignal(tripId: tripId, accessChanged: true);
            } else if (type == 'tripUnavailable' &&
                json['eventKind'] == type &&
                json['tripId'] == tripId) {
              yield TripLocationSignal(tripId: tripId, unavailable: true);
            } else if ((json['eventKind'] == 'tripLocationUpdated' ||
                    json['eventKind'] == 'tripLocationRemoved') &&
                json['tripId'] == tripId &&
                json['userId'] is String) {
              yield TripLocationSignal(
                tripId: tripId,
                userId: json['userId'] as String,
                updatedAt: DateTime.parse(json['updatedAt'] as String),
              );
            }
          }
          type = '';
          data.clear();
          length = 0;
        } else if (line.startsWith('event:')) {
          type = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          data.add(line.substring(5).trimLeft());
          length += line.length;
          if (length > 4096) {
            throw const FormatException('Location signal too large');
          }
        }
      }
    } catch (_) {
      if (generation == _generation) rethrow;
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }

  @override
  void disconnect() {
    _generation++;
    _client?.close();
    _client = null;
  }
}

class TripMemberLocationSnapshot {
  const TripMemberLocationSnapshot(this.tripId, this.members);
  final String? tripId;
  final List<GoMateMapMember> members;
}

/// Separate from the notification receiver: no inbox, popup, badge or FCM calls.
class TripLocationRealtimeService with WidgetsBindingObserver {
  TripLocationRealtimeService({
    AuthService? auth,
    TripLocationEventClient? client,
    Future<List<GoMateMapMember>> Function(String)? loadMembers,
    TripLocationPublishingService? publishing,
    this.fallbackInterval = const Duration(seconds: 30),
  }) : _auth = auth ?? AuthService.instance,
       _client =
           client ?? SseTripLocationEventClient(auth ?? AuthService.instance),
       _loadMembers = loadMembers ?? SpringGoMateMapGateway().loadTripMembers,
       _publishing = publishing;
  static final instance = TripLocationRealtimeService(
    publishing: TripLocationPublishingService.instance,
  );
  final AuthService _auth;
  final TripLocationEventClient _client;
  final Future<List<GoMateMapMember>> Function(String) _loadMembers;
  final TripLocationPublishingService? _publishing;
  final Duration fallbackInterval;
  final _updates = StreamController<TripMemberLocationSnapshot>.broadcast(
    sync: true,
  );
  Stream<TripMemberLocationSnapshot> get updates => _updates.stream;
  TripMemberLocationSnapshot snapshot = const TripMemberLocationSnapshot(
    null,
    [],
  );
  StreamSubscription<TripLocationSignal>? _subscription;
  Timer? _retry;
  Timer? _poll;
  String? _target;
  String? _identity;
  bool _started = false;
  bool _foreground = true;
  int _generation = 0;
  int _failures = 0;
  int _accessRevision = 0;
  final Set<(int, int)> _loading = {};
  final Set<(int, int)> _refreshPending = {};
  String? get target => _target;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _auth.addListener(_contextChanged);
    _publishing?.addListener(_contextChanged);
    GoMateMapUiSession.revision.addListener(_contextChanged);
    GoMateMapUiSession.mapVisible.addListener(_contextChanged);
    ContentAccessChanges.revision.addListener(_accessChanged);
    _contextChanged();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) return;
    _foreground = state == AppLifecycleState.resumed;
    _contextChanged();
  }

  void _contextChanged() {
    final detailId = _publishing?.visibleDetailTripId;
    final trip = detailId != null
        ? GoMateMapUiSession.tripById(detailId)
        : GoMateMapUiSession.displayedTrip;
    final user = _auth.signedIn
        ? (_auth.user?['id'] ?? _auth.user?['userId'])?.toString()
        : null;
    final wanted =
        _started &&
            _foreground &&
            user != null &&
            _publishing?.endingSession != true &&
            (GoMateMapUiSession.mapVisible.value || detailId != null) &&
            trip?.isGroup == true
        ? trip?.id
        : null;
    if (wanted == _target && user == _identity) return;
    _disconnect();
    _target = wanted;
    _identity = user;
    snapshot = TripMemberLocationSnapshot(wanted, const []);
    _updates.add(snapshot);
    if (wanted != null) {
      _connect();
      unawaited(refresh());
      _poll = Timer.periodic(fallbackInterval, (_) => unawaited(refresh()));
    }
  }

  void _connect() {
    final id = _target;
    if (id == null) return;
    final generation = _generation;
    _log('connect');
    _subscription = _client
        .connect(id)
        .listen(
          (signal) {
            if (generation != _generation ||
                (signal.tripId != null && signal.tripId != id)) {
              return;
            }
            _failures = 0;
            if (signal.unavailable) {
              _unavailable(id);
              return;
            }
            if (signal.accessChanged) {
              _accessChanged();
              return;
            }
            unawaited(refresh());
          },
          onError: (Object error) {
            if (generation != _generation) return;
            if (error is ApiException &&
                [401, 403, 404, 422].contains(error.status)) {
              _disconnect();
              _target = null;
              snapshot = const TripMemberLocationSnapshot(null, []);
              _updates.add(snapshot);
              if (error.status == 403 || error.status == 404) {
                GoMateMapUiSession.removeTrip(id);
              }
            } else {
              _retryConnect(generation);
            }
          },
          onDone: () => _retryConnect(generation),
        );
  }

  void _retryConnect(int generation) {
    if (generation != _generation || _target == null || _retry != null) return;
    _client.disconnect();
    unawaited(_subscription?.cancel());
    _subscription = null;
    final seconds = (1 << _failures.clamp(0, 5)).clamp(1, 30);
    _failures++;
    _retry = Timer(Duration(seconds: seconds), () {
      _retry = null;
      if (generation == _generation) _connect();
    });
  }

  Future<void> refresh() async {
    final id = _target;
    final generation = _generation;
    final access = _accessRevision;
    final key = (generation, access);
    if (id == null) return;
    if (!_loading.add(key)) {
      _refreshPending.add(key);
      return;
    }
    try {
      final members = await _loadMembers(id);
      if (generation != _generation ||
          access != _accessRevision ||
          id != _target)
        return;
      snapshot = TripMemberLocationSnapshot(id, List.unmodifiable(members));
      _updates.add(snapshot);
    } on ApiException catch (e) {
      if (generation == _generation &&
          access == _accessRevision &&
          [403, 404, 422].contains(e.status)) {
        _disconnect();
        _target = null;
        snapshot = const TripMemberLocationSnapshot(null, []);
        _updates.add(snapshot);
        GoMateMapUiSession.removeTrip(id);
      }
    } catch (_) {
      _log('REST reconcile unavailable; keep last-known snapshot');
    } finally {
      _loading.remove(key);
      if (_refreshPending.remove(key) &&
          generation == _generation &&
          access == _accessRevision) {
        unawaited(refresh());
      }
    }
  }

  void _accessChanged() {
    if (_target == null) return;
    _accessRevision++;
    // Fail closed while permissions revalidate. Publisher/Pin/Trip are untouched.
    snapshot = TripMemberLocationSnapshot(_target, const []);
    _updates.add(snapshot);
    unawaited(refresh());
  }

  void _unavailable(String id) {
    GoMateMapUiSession.removeTrip(id);
    if (_target == id) {
      _disconnect();
      _target = null;
      snapshot = const TripMemberLocationSnapshot(null, []);
      _updates.add(snapshot);
    }
  }

  void _disconnect() {
    _generation++;
    _retry?.cancel();
    _poll?.cancel();
    _retry = null;
    _poll = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _client.disconnect();
    _failures = 0;
  }

  void dispose() {
    _started = false;
    _disconnect();
    _auth.removeListener(_contextChanged);
    _publishing?.removeListener(_contextChanged);
    GoMateMapUiSession.revision.removeListener(_contextChanged);
    GoMateMapUiSession.mapVisible.removeListener(_contextChanged);
    ContentAccessChanges.revision.removeListener(_accessChanged);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_updates.close());
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[trip-location-sse] $message');
  }
}
