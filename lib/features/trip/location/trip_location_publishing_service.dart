import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/auth_service.dart';
import '../../map/state/map_ui_session.dart';
import '../data/trip_repository.dart';
import 'location_runtime_driver.dart';
import 'location_runtime_models.dart';
import 'location_publishing_repository.dart';

/// The existing foreground clock/native location driver, authorized by own pin.
class TripLocationPublishingService extends ChangeNotifier
    with WidgetsBindingObserver {
  TripLocationPublishingService({
    AuthService? auth,
    TripLocationPublishingRepository? repository,
    TripLocationDriver? driver,
    PendingUnpinStore? unpinStore,
    this.foregroundInterval = const Duration(seconds: 15),
    this.backgroundInterval = const Duration(seconds: 60),
  }) : _auth = auth ?? AuthService.instance,
       _repository = repository ?? TripLocationPublishingRepository(auth: auth),
       _driver = driver ?? GeolocatorTripLocationDriver(),
       _unpinStore = unpinStore ?? const SecurePendingUnpinStore();

  static final instance = TripLocationPublishingService();
  final AuthService _auth;
  final TripLocationPublishingRepository _repository;
  final TripLocationDriver _driver;
  final PendingUnpinStore _unpinStore;
  final Duration foregroundInterval;
  final Duration backgroundInterval;
  final Set<String> _pendingUnpin = {};
  final Map<String, int> _detailContexts = {};
  Timer? _foregroundTimer;
  Timer? _retry;
  StreamSubscription<TripLocationSample>? _background;
  StreamSubscription<bool>? _serviceChanges;
  String? _backgroundTripId;
  String? _observedPinId;
  String? _userId;
  bool _started = false;
  bool _foreground = true;
  bool _pinReady = false;
  bool _loggingOut = false;
  bool _publishing = false;
  bool _reconciling = false;
  bool _reconcileAgain = false;
  bool _restoring = false;
  bool _backgroundStopping = false;
  int _generation = 0;
  int _runtimeVersion = 0;
  String? error;
  DateTime? lastAcceptedAt;
  bool get backgroundRunning => _background != null;
  bool get foregroundRunning => _foregroundTimer != null;
  bool get foreground => _foreground;
  bool get endingSession => _loggingOut;
  bool get suspended =>
      !_pinReady ||
      _loggingOut ||
      _pendingUnpin.contains(GoMateMapUiSession.pinnedTrip?.id);
  String? get visibleDetailTripId => _detailContexts.keys.lastOrNull;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _auth.addListener(_onAuth);
    _auth.beforeLogout.insert(0, _beforeLogout);
    RealTripRepository.beforeUnpin.add(_beforeUnpin);
    RealTripRepository.afterUnpin.add(_afterUnpin);
    RealTripRepository.afterPin.add(_afterPin);
    GoMateMapUiSession.revision.addListener(_onContext);
    _serviceChanges = _driver.serviceChanges().listen(
      (enabled) {
        if (!_started) return;
        if (!enabled) _stopRuntime();
        unawaited(reconcile());
      },
      onError: (Object _) {
        if (!_started) return;
        _stopRuntime();
        error = 'Không kiểm tra được GPS';
        notifyListeners();
      },
    );
    _onAuth();
  }

  void _onAuth() {
    final next = _auth.signedIn
        ? (_auth.user?['id'] ?? _auth.user?['userId'])?.toString()
        : null;
    if (next == _userId) return;
    _generation++;
    RealTripRepository.pinRevision++;
    _runtimeVersion++;
    _pinReady = false;
    _loggingOut = false;
    _stopRuntime();
    _pendingUnpin.clear();
    _detailContexts.clear();
    _observedPinId = null;
    _userId = next;
    error = null;
    lastAcceptedAt = null;
    GoMateMapUiSession.clearUserState();
    notifyListeners();
    if (next != null) unawaited(_restoreContext());
  }

  Future<void> _restoreContext() async {
    if (_restoring || !_started || _userId == null || _loggingOut) return;
    _restoring = true;
    final generation = _generation;
    final user = _userId!;
    try {
      _pendingUnpin.addAll(await _unpinStore.pendingTrips(user));
      if (generation != _generation) return;
      for (final id in _pendingUnpin.toList()) {
        try {
          await _repository.unpin(id);
        } on ApiException catch (e) {
          if (e.status != 403 && e.status != 404) rethrow;
        }
        if (generation != _generation) return;
        await _unpinStore.setTripPending(user, id, false);
        _pendingUnpin.remove(id);
      }
      final revision = RealTripRepository.pinRevision;
      final pin = await _repository.pinned();
      if (generation != _generation || _loggingOut) return;
      if (revision != RealTripRepository.pinRevision) {
        _scheduleRestore();
        return;
      }
      _pinReady = true;
      error = null;
      if (pin != null) {
        GoMateMapUiSession.pinTrip(pin, selectOnMap: false);
      } else {
        GoMateMapUiSession.clearPinnedTrip();
      }
      await reconcile();
    } catch (_) {
      if (generation == _generation) {
        // Keep persisted pin UI truth; never send while unpin is unresolved.
        error = 'Chưa đồng bộ được lịch trình đã ghim';
        _scheduleRestore();
        notifyListeners();
      }
    } finally {
      _restoring = false;
      if (generation != _generation && _started && _userId != null) {
        unawaited(_restoreContext());
      }
    }
  }

  Future<void> _beforeUnpin(String user, String tripId) async {
    if (user != _userId) return;
    _pendingUnpin.add(tripId);
    if (GoMateMapUiSession.pinnedTrip?.id == tripId) {
      _runtimeVersion++;
      _stopRuntime();
    }
    error = 'Đã dừng trên máy; đang xác nhận bỏ ghim';
    notifyListeners();
    await _unpinStore.setTripPending(user, tripId, true);
    if (user == _userId) _scheduleRestore();
  }

  Future<void> _afterUnpin(String user, String tripId) async {
    await _unpinStore.setTripPending(user, tripId, false);
    if (user != _userId) return;
    _pendingUnpin.remove(tripId);
    error = null;
    unawaited(reconcile());
  }

  Future<void> _afterPin(String user, String tripId) async {
    await _unpinStore.setTripPending(user, tripId, false);
    if (user != _userId) return;
    _pendingUnpin.remove(tripId);
    _pinReady = true;
    error = null;
    unawaited(reconcile());
  }

  void enterTripDetail(String tripId) {
    _detailContexts.update(tripId, (count) => count + 1, ifAbsent: () => 1);
    notifyListeners();
  }

  void leaveTripDetail(String tripId) {
    final count = _detailContexts[tripId] ?? 0;
    if (count <= 1) {
      _detailContexts.remove(tripId);
    } else {
      _detailContexts[tripId] = count - 1;
    }
    notifyListeners();
  }

  void _onContext() {
    final pin = GoMateMapUiSession.pinnedTrip?.id;
    if (_observedPinId == pin) return;
    _observedPinId = pin;
    _runtimeVersion++;
    _stopRuntime();
    unawaited(reconcile());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) return;
    _foreground = state == AppLifecycleState.resumed;
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    if (_foreground && !_loggingOut) {
      unawaited(_restoreContext());
    }
    notifyListeners();
  }

  void _scheduleRestore() {
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 10), () {
      if (_foreground) unawaited(_restoreContext());
    });
  }

  Future<void> reconcile() async {
    if (!_started || _userId == null || suspended) return;
    if (_reconciling) {
      _reconcileAgain = true;
      return;
    }
    _reconciling = true;
    final generation = _generation;
    final runtime = _runtimeVersion;
    final pin = GoMateMapUiSession.pinnedTrip?.id;
    try {
      final capability = await _driver.capability();
      if (generation != _generation ||
          runtime != _runtimeVersion ||
          suspended) {
        return;
      }
      final allowed =
          pin != null &&
          capability.canForeground &&
          (!capability.android || capability.canBackground);
      if (!allowed) {
        _stopRuntime();
      } else {
        if (_foreground && _foregroundTimer == null) {
          _foregroundTimer = Timer.periodic(
            foregroundInterval,
            (_) => unawaited(publishForeground()),
          );
          unawaited(publishForeground());
        }
        if (!capability.canBackground) {
          await _stopBackground();
        } else if (_foreground && _background == null && !_backgroundStopping) {
          // Keep the working Android foreground-service stack, started while visible.
          _backgroundTripId = pin;
          _background = _driver
              .backgroundPositions(backgroundInterval)
              .listen(
                (sample) {
                  if (!_foreground) {
                    unawaited(_publishBackground(sample, generation, pin));
                  }
                },
                onError: (Object _) {
                  if (!_started ||
                      generation != _generation ||
                      _backgroundTripId != pin) {
                    return;
                  }
                  unawaited(_stopBackground(reconcileAfterStop: false));
                  error =
                      'Gửi vị trí nền đã dừng; mở app để kiểm tra quyền/GPS';
                  notifyListeners();
                },
              );
        }
      }
      notifyListeners();
    } catch (_) {
      if (generation == _generation) {
        _stopRuntime();
        error = 'Tạm dừng: không kiểm tra được quyền/GPS';
        _scheduleRestore();
        notifyListeners();
      }
    } finally {
      _reconciling = false;
      if (_reconcileAgain) {
        _reconcileAgain = false;
        unawaited(reconcile());
      }
    }
  }

  bool _current(String id, int generation, int runtime) =>
      _started &&
      generation == _generation &&
      runtime == _runtimeVersion &&
      !suspended &&
      GoMateMapUiSession.pinnedTrip?.id == id;

  Future<void> publishForeground() async {
    final id = GoMateMapUiSession.pinnedTrip?.id;
    if (_publishing || !_foreground || suspended || id == null) return;
    _publishing = true;
    final generation = _generation;
    final runtime = _runtimeVersion;
    try {
      final sample = await _driver.current();
      if (!_foreground || !_current(id, generation, runtime)) return;
      await _publish(id, sample, false, generation, runtime);
    } catch (_) {
      if (_current(id, generation, runtime)) {
        error = 'Chưa gửi được vị trí; sẽ thử lại ở nhịp tiếp theo';
        notifyListeners();
      }
    } finally {
      _publishing = false;
    }
  }

  Future<void> _publishBackground(
    TripLocationSample sample,
    int generation,
    String id,
  ) async {
    if (_publishing || _foreground || suspended || _backgroundTripId != id) {
      return;
    }
    _publishing = true;
    final runtime = _runtimeVersion;
    try {
      if (_current(id, generation, runtime)) {
        await _publish(id, sample, true, generation, runtime);
      }
    } catch (_) {
      if (_current(id, generation, runtime)) _log('background publish failed');
    } finally {
      _publishing = false;
    }
  }

  Future<void> _publish(
    String id,
    TripLocationSample sample,
    bool background,
    int generation,
    int runtime,
  ) async {
    final capability = await _driver.capability();
    if (!_current(id, generation, runtime)) return;
    if (!capability.canForeground ||
        capability.android && !capability.canBackground) {
      _stopRuntime();
      notifyListeners();
      return;
    }
    if (background && (_foreground || !capability.canBackground)) return;
    try {
      final acceptedAt = await _repository.publish(
        id,
        sample,
        background: background,
      );
      if (!_current(id, generation, runtime)) return;
      lastAcceptedAt = acceptedAt;
      error = null;
      _log(background ? 'background publish ACK' : 'foreground publish ACK');
      notifyListeners();
    } on ApiException catch (e) {
      if (_current(id, generation, runtime) &&
          [401, 403, 404].contains(e.status)) {
        _pinReady = false;
        _stopRuntime();
        if (e.status == 404) GoMateMapUiSession.removeTrip(id);
        _scheduleRestore();
      }
      rethrow;
    }
  }

  Future<void> _beforeLogout() async {
    _loggingOut = true;
    _pinReady = false;
    _generation++;
    _runtimeVersion++;
    _stopRuntime();
    notifyListeners();
    // Logout is not an unpin and never writes server pin/share intent.
  }

  Future<void> _stopBackground({bool reconcileAfterStop = true}) async {
    final subscription = _background;
    _background = null;
    _backgroundTripId = null;
    if (subscription == null) return;
    _backgroundStopping = true;
    try {
      await subscription.cancel();
    } catch (_) {
      _log('native cancellation unavailable; local publishing is stopped');
    } finally {
      _backgroundStopping = false;
      if (reconcileAfterStop && _started && !suspended) unawaited(reconcile());
    }
  }

  void _stopRuntime() {
    _retry?.cancel();
    _retry = null;
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    unawaited(_stopBackground());
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[trip-location] $message');
  }

  @override
  void dispose() {
    _started = false;
    _pinReady = false;
    _generation++;
    _stopRuntime();
    unawaited(_serviceChanges?.cancel());
    _auth.removeListener(_onAuth);
    _auth.beforeLogout.remove(_beforeLogout);
    RealTripRepository.beforeUnpin.remove(_beforeUnpin);
    RealTripRepository.afterUnpin.remove(_afterUnpin);
    RealTripRepository.afterPin.remove(_afterPin);
    GoMateMapUiSession.revision.removeListener(_onContext);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
