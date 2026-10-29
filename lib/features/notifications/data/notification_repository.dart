import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/content_access_changes.dart';
import '../../trip/data/trip_repository.dart';
import '../../trip/models/trip_ui_models.dart';
import '../models/gomate_notification.dart';
import 'notification_realtime_client.dart';

/// One account-scoped inbox: SSE invalidation + durable REST/polling fallback.
class NotificationRepository extends ChangeNotifier {
  NotificationRepository({
    AuthService? auth,
    Future<TripUi> Function(String)? acceptInvitation,
    NotificationRealtimeClient? realtime,
    Duration reconnectDelay = const Duration(seconds: 1),
  }) : _auth = auth ?? AuthService.instance,
       _acceptInvitation =
           acceptInvitation ?? RealTripRepository.instance.acceptInvitation,
       _reconnectDelay = reconnectDelay {
    _realtime = realtime ?? SseNotificationRealtimeClient(auth: _auth);
  }

  static final instance = NotificationRepository();
  final AuthService _auth;
  final Future<TripUi> Function(String) _acceptInvitation;
  final _events = StreamController<GoMateNotificationItem>.broadcast(
    sync: true,
  );
  late final NotificationRealtimeClient _realtime;
  final Duration _reconnectDelay;
  StreamSubscription<NotificationRealtimeEvent>? _realtimeSubscription;
  Timer? _reconnect;
  Timer? _reconcileTimer;
  final _signalIds = <String>{};
  bool _needsReconcile = false;
  bool _reconciling = false;
  bool _connecting = false;
  int _connectionEpoch = 0;
  int _reconnectAttempts = 0;
  int _credentialRevision = -1;
  final _items = <String, GoMateNotificationItem>{};
  final _seen = <String>{};
  final _resolvedIds = <String>{};
  Timer? _poll;
  String? _accountId;
  int _generation = 0;
  int _mutationRevision = 0;
  int _page = 0;
  int _total = 0;
  int unreadCount = 0;
  bool loading = false;
  bool loadingMore = false;
  bool _started = false;
  bool _foreground = true;
  bool _initialized = false;
  Future<void>? _refreshing;
  String? error;

  Stream<GoMateNotificationItem> get events => _events.stream;
  AuthService get auth => _auth;
  GoMateNotificationItem? byId(String id) => _items[id];
  void suppressPopup(String id) => _seen.add(id);
  void invalidate(String id) {
    if (_canConnect) _queueReconcile(id);
  }

  bool get hasMore => _items.length < _total;
  List<GoMateNotificationItem> get items =>
      _items.values.toList()..sort((a, b) {
        final time = b.occurredAt!.compareTo(a.occurredAt!);
        return time == 0 ? b.id.compareTo(a.id) : time;
      });

  void start() {
    if (_started) return;
    _started = true;
    _auth.addListener(_authChanged);
    _authChanged();
    setForeground(true);
  }

  void stop() {
    _poll?.cancel();
    _poll = null;
    if (_started) _auth.removeListener(_authChanged);
    _started = false;
    _disconnectRealtime();
    _generation++;
    _refreshing = null;
    _reconciling = false;
    _needsReconcile = false;
    _signalIds.clear();
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    _poll?.cancel();
    _poll = null;
    if (!foreground || !_started || !_auth.signedIn) {
      _disconnectRealtime();
      return;
    }
    unawaited(refresh());
    _poll = Timer.periodic(
      const Duration(seconds: 12),
      (_) => unawaited(refresh()),
    );
    _connectRealtime();
  }

  void _authChanged() {
    final user = _auth.user;
    final id = _auth.signedIn
        ? (user?['userId'] ?? user?['id'])?.toString()
        : null;
    final credentialsChanged = _credentialRevision != _auth.credentialRevision;
    _credentialRevision = _auth.credentialRevision;
    if (id == _accountId) {
      if (credentialsChanged) {
        _disconnectRealtime();
        _connectRealtime();
      }
      return;
    }
    _disconnectRealtime();
    _accountId = id;
    _generation++;
    _items.clear();
    _seen.clear();
    _resolvedIds.clear();
    _signalIds.clear();
    _needsReconcile = false;
    _reconciling = false;
    _reconnectAttempts = 0;
    _page = 0;
    _total = 0;
    unreadCount = 0;
    _initialized = false;
    loading = false;
    loadingMore = false;
    _refreshing = null;
    error = null;
    notifyListeners();
    setForeground(_foreground);
  }

  bool get _canConnect => _started && _foreground && _auth.signedIn;

  void _connectRealtime() {
    if (!_canConnect || _connecting || _realtimeSubscription != null) return;
    _connecting = true;
    final epoch = ++_connectionEpoch;
    unawaited(_openRealtime(epoch));
  }

  Future<void> _openRealtime(int epoch) async {
    // Establish the REST baseline first; ready then reconciles the connection gap.
    await refresh();
    if (epoch != _connectionEpoch || !_canConnect) return;
    try {
      if (kDebugMode) debugPrint('[notifications] connect');
      _realtimeSubscription = _realtime.connect().listen(
        (event) {
          if (epoch != _connectionEpoch || !_canConnect) return;
          if (event.eventKind == 'ACCESS_CHANGED') {
            ContentAccessChanges.changed();
          } else if (event.eventKind == 'READY') {
            _reconnectAttempts = 0;
            _queueReconcile(null);
          } else {
            if (kDebugMode) {
              debugPrint('[notifications] event received ${event.eventKind}');
            }
            _queueReconcile(event.notificationId);
          }
        },
        onError: (Object _) => _realtimeDisconnected(epoch),
        onDone: () => _realtimeDisconnected(epoch),
        cancelOnError: true,
      );
      _connecting = false;
    } catch (_) {
      _realtimeDisconnected(epoch);
    }
  }

  void _realtimeDisconnected(int epoch) {
    if (epoch != _connectionEpoch) return;
    _disconnectRealtime();
    if (!_canConnect) return;
    final attempt = _reconnectAttempts++;
    final multiplier = 1 << attempt.clamp(0, 5);
    final milliseconds = (_reconnectDelay.inMilliseconds * multiplier).clamp(
      1,
      30000,
    );
    if (kDebugMode) debugPrint('[notifications] reconnect scheduled');
    _reconnect = Timer(Duration(milliseconds: milliseconds), _connectRealtime);
  }

  void _disconnectRealtime() {
    _connectionEpoch++;
    _connecting = false;
    _reconnect?.cancel();
    _reconnect = null;
    _reconcileTimer?.cancel();
    _reconcileTimer = null;
    final subscription = _realtimeSubscription;
    _realtimeSubscription = null;
    final cancelling = subscription?.cancel();
    _realtime.disconnect();
    if (subscription != null) {
      unawaited(cancelling!.catchError((Object _) {}));
      if (kDebugMode) debugPrint('[notifications] disconnect');
    }
  }

  void _queueReconcile(String? id) {
    if (id != null) {
      _signalIds.add(id);
      _resolvedIds.add(id);
    }
    _needsReconcile = true;
    _mutationRevision++;
    if (_reconciling || _reconcileTimer != null) return;
    _reconcileTimer = Timer(const Duration(milliseconds: 80), () {
      _reconcileTimer = null;
      unawaited(_reconcileSignals(_generation));
    });
  }

  Future<void> _reconcileSignals(int generation) async {
    if (generation != _generation || !_canConnect || _reconciling) return;
    _reconciling = true;
    try {
      while (_needsReconcile && generation == _generation && _canConnect) {
        _needsReconcile = false;
        final ids = _signalIds.toList();
        _signalIds.clear();
        if (kDebugMode) debugPrint('[notifications] reconcile triggered');
        // An invalidation during an in-flight poll requires a subsequent read.
        await _refreshing;
        if (generation != _generation || !_canConnect) return;
        await refresh();
        for (final id in ids) {
          final revision = _mutationRevision;
          try {
            final json = await _auth.request(
              'GET',
              '/notifications/${Uri.encodeComponent(id)}',
            );
            if (generation != _generation || !_canConnect) return;
            if (revision != _mutationRevision) {
              _signalIds.add(id);
              _needsReconcile = true;
              continue;
            }
            _mutationRevision++;
            _merge([GoMateNotificationItem.fromJson(json)]);
            notifyListeners();
          } catch (_) {
            // Keep resolved IDs: the unchanged 12s poll also refreshes old rows.
          }
        }
      }
    } finally {
      if (generation == _generation) _reconciling = false;
    }
  }

  void _merge(List<GoMateNotificationItem> rows) {
    final unseen = rows
        .where(
          (item) =>
              !item.isRead &&
              !_seen.contains(item.id) &&
              (item.isPendingInvitation ||
                  item.type == GoMateNotificationType.tripInvitationAccepted ||
                  item.type == GoMateNotificationType.tripStartReminder ||
                  item.isPostInteraction),
        )
        .toList();
    _items.addEntries(rows.map((item) => MapEntry(item.id, item)));
    _seen.addAll(rows.map((item) => item.id));
    if (_initialized && unseen.isNotEmpty && _foreground) {
      _events.add(unseen.first);
    }
  }

  Future<void> refresh() {
    if (!_auth.signedIn) return Future.value();
    final generation = _generation;
    return _refreshing ??= _refresh(generation).whenComplete(() {
      if (generation == _generation) _refreshing = null;
    });
  }

  Future<void> _refresh(int generation) async {
    final revision = _mutationRevision;
    loading = _items.isEmpty;
    notifyListeners();
    try {
      // Refresh every loaded page so accept state from another device propagates.
      final pages = await Future.wait([
        for (var page = 0; page <= _page; page++) _fetchPage(page),
      ]);
      final rows = [for (final page in pages) ..._rows(page)];
      final loadedIds = rows.map((item) => item.id).toSet();
      for (final id in _resolvedIds.toList()) {
        if (loadedIds.contains(id)) continue;
        final json = await _auth.request(
          'GET',
          '/notifications/${Uri.encodeComponent(id)}',
        );
        rows.add(GoMateNotificationItem.fromJson(json));
      }
      if (generation != _generation || revision != _mutationRevision) return;
      _merge(rows);
      _total = (pages.first['total'] as num).toInt();
      unreadCount = (pages.first['unreadCount'] as num).toInt();
      error = null;
      _initialized = true;
    } catch (failure) {
      if (generation == _generation) error = failure.toString();
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<Map<String, dynamic>> _fetchPage(int page) =>
      _auth.request('GET', '/notifications?page=$page&size=30');

  List<GoMateNotificationItem> _rows(Map<String, dynamic> page) =>
      (page['items'] as List)
          .map(
            (row) => GoMateNotificationItem.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    final generation = _generation;
    final revision = _mutationRevision;
    loadingMore = true;
    notifyListeners();
    try {
      final response = await _fetchPage(_page + 1);
      if (generation != _generation || revision != _mutationRevision) return;
      for (final item in _rows(response)) {
        _items[item.id] = item;
        _seen.add(item.id);
      }
      _page++;
      _mutationRevision++;
      _total = (response['total'] as num).toInt();
      error = null;
    } catch (failure) {
      if (generation == _generation) error = failure.toString();
    } finally {
      if (generation == _generation) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<GoMateNotificationItem> resolve(String id) async {
    final generation = _generation;
    final revision = _mutationRevision;
    final json = await _auth.request(
      'GET',
      '/notifications/${Uri.encodeComponent(id)}',
    );
    if (generation != _generation) throw StateError('Phiên đã thay đổi');
    if (revision != _mutationRevision) return resolve(id);
    final item = GoMateNotificationItem.fromJson(json);
    _resolvedIds.add(id);
    _mutationRevision++;
    _items[item.id] = item;
    notifyListeners();
    return item;
  }

  Future<void> markRead(String id) async {
    final generation = _generation;
    final revision = _mutationRevision;
    final json = await _auth.request(
      'PATCH',
      '/notifications/${Uri.encodeComponent(id)}/read',
    );
    if (generation != _generation) return;
    if (revision != _mutationRevision) {
      await resolve(id);
      await refresh();
      return;
    }
    final wasUnread = _items[id]?.isRead == false;
    _mutationRevision++;
    _items[id] = GoMateNotificationItem.fromJson(json);
    if (wasUnread && unreadCount > 0) unreadCount--;
    notifyListeners();
  }

  Future<Map<String, dynamic>> postTarget(String id) async {
    final generation = _generation;
    final result = await _auth.request(
      'GET',
      '/notifications/${Uri.encodeComponent(id)}/post-target',
    );
    if (generation != _generation) throw StateError('Phiên đã thay đổi');
    return result;
  }

  Future<TripUi> accept(GoMateNotificationItem item) async {
    final generation = _generation;
    final fresh = await resolve(item.id);
    if (fresh.invitationId == null ||
        (!fresh.isPendingInvitation && fresh.invitationStatus != 'ACCEPTED')) {
      throw StateError('Lời mời không còn khả dụng.');
    }
    if (generation != _generation) throw StateError('Phiên đã thay đổi');
    final trip = await _acceptInvitation(fresh.invitationId!);
    if (generation != _generation) throw StateError('Phiên đã thay đổi');
    _mutationRevision++;
    _items[item.id] = fresh.copyWith(invitationStatus: 'ACCEPTED');
    notifyListeners();
    unawaited(refresh());
    return trip;
  }

  @override
  void dispose() {
    stop();
    _events.close();
    super.dispose();
  }
}
