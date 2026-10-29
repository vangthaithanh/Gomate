import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/auth_service.dart';
import 'firebase_push_messaging.dart';
import 'notification_repository.dart';

/// One application-level push receiver. Payloads are hints, never invitation state.
class NotificationPushService {
  NotificationPushService({
    AuthService? auth,
    NotificationRepository? inbox,
    PushMessaging? messaging,
    PushInstallationStore? installations,
  }) : _auth = auth ?? AuthService.instance,
       _inbox = inbox ?? NotificationRepository.instance,
       _messaging = messaging ?? FirebasePushMessaging(),
       _installations = installations ?? SecurePushInstallationStore();

  static final instance = NotificationPushService();
  final AuthService _auth;
  final NotificationRepository _inbox;
  final PushMessaging _messaging;
  final PushInstallationStore _installations;
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _handled = <String>{};
  Future<void> Function(String)? _route;
  PushHint? _pendingOpen;
  String? _account;
  String? _registeredToken;
  String? _latestToken;
  int _generation = 0;
  int _credentials = -1;
  bool _ready = false;
  bool _foreground = true;
  bool _syncRequested = false;
  bool _syncing = false;
  bool _opening = false;
  Future<void> _cleanup = Future.value();
  bool _cleanupRequired = false;
  Future<void>? _starting;
  Timer? _retry;
  bool permissionGranted = false;
  String? error;

  Future<void> start() => _starting ??= _start();
  Future<void> _start() async {
    try {
      _ready = await _messaging.initialize();
      if (!_ready) return;
      _auth.addListener(_authChanged);
      _auth.beforeLogout.add(_beforeLogout);
      _subscriptions.add(
        _messaging.tokenChanges.listen((token) {
          _latestToken = token;
          _scheduleSync();
        }),
      );
      _subscriptions.add(
        _messaging.foregroundMessages.listen((hint) {
          if (hint.recipientId != _account || !_auth.signedIn) return;
          // No local/OS notification, no separate GoMate popup. Same store/dedupe as SSE.
          _inbox.invalidate(hint.notificationId);
        }),
      );
      _subscriptions.add(_messaging.openedMessages.listen(_onOpen));
      final initial = await _messaging.initialMessage();
      if (initial != null) _onOpen(initial);
      _authChanged();
    } catch (_) {
      error = 'Push initialization unavailable; Inbox/SSE remain available.';
      if (kDebugMode) debugPrint('[push] initialization unavailable');
    }
  }

  void attachRouter(Future<void> Function(String) route) {
    _route = route;
    _scheduleSync();
    unawaited(_drainOpen());
  }

  void detachRouter() {
    _route = null;
  }

  void setForeground(bool foreground) {
    _foreground = foreground;
    if (foreground) {
      _scheduleSync();
      unawaited(_drainOpen());
    }
  }

  void _authChanged() {
    final user = _auth.user;
    final id = _auth.signedIn
        ? (user?['userId'] ?? user?['id'])?.toString()
        : null;
    final changed = id != _account;
    if (!changed && _credentials == _auth.credentialRevision) return;
    _credentials = _auth.credentialRevision;
    _generation++;
    if (changed) {
      if (_account != null) {
        _pendingOpen = null;
        _handled.clear();
        _latestToken = null;
        _cleanupRequired = true;
        _cleanup = _cleanup.then((_) async {
          try {
            await _messaging.deleteToken();
            _cleanupRequired = false;
          } catch (_) {
            error =
                'Push token cleanup pending; registration will retry safely.';
          }
        });
      }
      _account = id;
      _registeredToken = null;
      permissionGranted = false;
    }
    if (id != null) {
      _scheduleSync();
      unawaited(_drainOpen());
    }
  }

  void _scheduleSync() {
    if (!_ready || !_auth.signedIn || _route == null || !_foreground) return;
    _syncRequested = true;
    if (!_syncing) unawaited(_sync());
  }

  Future<void> _sync() async {
    _syncing = true;
    try {
      while (_syncRequested &&
          _ready &&
          _auth.signedIn &&
          _route != null &&
          _foreground) {
        _syncRequested = false;
        final generation = _generation;
        try {
          await _cleanup;
          if (_cleanupRequired) {
            await _messaging.deleteToken();
            _cleanupRequired = false;
          }
          final allowed = await _messaging.permission();
          if (generation != _generation) continue;
          permissionGranted = allowed;
          final installation = await _installations.installationId();
          if (!allowed) {
            await _auth.request(
              'DELETE',
              '/notification-devices/current',
              body: {'installationId': installation},
            );
            _registeredToken = null;
            continue;
          }
          final token = _latestToken ?? await _messaging.token();
          if (generation != _generation || token == null || token.isEmpty) {
            continue;
          }
          // Re-register on resume too: active session and user binding are server-owned.
          await _auth.request(
            'POST',
            '/notification-devices',
            body: {
              'installationId': installation,
              'token': token,
              'platform': 'ANDROID',
            },
          );
          if (generation != _generation) continue;
          _registeredToken = token;
          error = null;
          if (kDebugMode) debugPrint('[push] device registered');
        } catch (_) {
          error = 'Push registration unavailable; Inbox/SSE remain available.';
          _retry?.cancel();
          _retry = Timer(const Duration(seconds: 30), _scheduleSync);
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _beforeLogout() async {
    if (!_ready) return;
    try {
      final installation = await _installations.installationId();
      await _auth.request(
        'DELETE',
        '/notification-devices/current',
        body: {'installationId': installation},
      );
    } catch (_) {
      // Server-side session revocation also excludes this device from delivery.
    }
    try {
      await _messaging.deleteToken();
    } catch (_) {
      /* Retried on account change. */
    }
    _registeredToken = null;
    _latestToken = null;
    _pendingOpen = null;
  }

  void _onOpen(PushHint hint) {
    if (_handled.contains(hint.messageId)) return;
    _pendingOpen = hint;
    if (hint.recipientId == _account) _inbox.suppressPopup(hint.notificationId);
    unawaited(_drainOpen());
  }

  Future<void> _drainOpen() async {
    if (!_ready ||
        _opening ||
        !_foreground ||
        _route == null ||
        !_auth.signedIn ||
        _pendingOpen == null) {
      return;
    }
    final hint = _pendingOpen!;
    if (hint.recipientId != _account) {
      _pendingOpen = null;
      return;
    }
    if (_handled.contains(hint.messageId)) {
      _pendingOpen = null;
      return;
    }
    final generation = _generation;
    _opening = true;
    try {
      _inbox.suppressPopup(hint.notificationId);
      await _inbox.resolve(hint.notificationId);
      if (generation != _generation ||
          hint.recipientId != _account ||
          _route == null) {
        return;
      }
      _handled.add(hint.messageId);
      if (_pendingOpen?.messageId == hint.messageId) _pendingOpen = null;
      await _route!(hint.notificationId);
    } catch (_) {
      if (kDebugMode) debugPrint('[push] notification open deferred');
      // Do not navigate from unverified payloads. Retry reconciliation on next resume.
      error = 'Cannot resolve push notification from server.';
    } finally {
      _opening = false;
      if (_pendingOpen != null && _pendingOpen?.messageId != hint.messageId) {
        unawaited(_drainOpen());
      }
    }
  }

  bool get registered => _registeredToken != null;

  void dispose() {
    _ready = false;
    _generation++;
    _retry?.cancel();
    _auth.removeListener(_authChanged);
    _auth.beforeLogout.remove(_beforeLogout);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    _pendingOpen = null;
    _handled.clear();
    _route = null;
  }
}
