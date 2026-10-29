import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/session_store.dart';
import 'package:gomate/features/notifications/data/firebase_push_messaging.dart';
import 'package:gomate/features/notifications/data/notification_push_service.dart';
import 'package:gomate/features/notifications/data/notification_repository.dart';
import 'package:gomate/features/notifications/models/gomate_notification.dart';

class _Store implements SessionStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
}

class _Installation implements PushInstallationStore {
  @override
  Future<String> installationId() async =>
      '6bc95996-df54-4f3d-a4a6-54d622dd3000';
}

class _Messaging implements PushMessaging {
  final tokens = StreamController<String>.broadcast();
  final foreground = StreamController<PushHint>.broadcast();
  final opens = StreamController<PushHint>.broadcast();
  PushHint? initial;
  bool allowed = true;
  bool supported = true;
  String currentToken = 'token-1';
  int deletes = 0;
  @override
  Future<bool> initialize() async => supported;
  @override
  Stream<String> get tokenChanges => tokens.stream;
  @override
  Stream<PushHint> get foregroundMessages => foreground.stream;
  @override
  Stream<PushHint> get openedMessages => opens.stream;
  @override
  Future<PushHint?> initialMessage() async => initial;
  @override
  Future<bool> permission() async => allowed;
  @override
  Future<String?> token() async => currentToken;
  @override
  Future<void> deleteToken() async {
    deletes++;
    currentToken = 'after-delete-$deletes';
  }
}

class _Inbox extends NotificationRepository {
  _Inbox(AuthService auth) : super(auth: auth);
  String status = 'PENDING';
  int resolutions = 0;
  int invalidations = 0;
  String? resolvedStatus;
  Completer<void>? block;
  bool fail = false;
  @override
  void invalidate(String id) {
    invalidations++;
  }

  @override
  Future<GoMateNotificationItem> resolve(String id) async {
    resolutions++;
    if (block != null) await block!.future;
    if (fail) throw StateError('offline');
    resolvedStatus = status;
    return GoMateNotificationItem.fromJson({
      'id': id,
      'type': 'TRIP_INVITATION',
      'actorName': 'Sender',
      'actorId': 'A',
      'invitationId': 'invite-$id',
      'invitationStatus': status,
      'tripId': 'trip-1',
      'tripName': 'Trip',
      'isRead': false,
      'occurredAt': '2026-10-15T08:00:00Z',
    });
  }
}

class _Fixture {
  late final AuthService auth;
  late final _Inbox inbox;
  late final NotificationPushService push;
  final messaging = _Messaging();
  final registrations = <Map<String, dynamic>>[];
  final operations = <String>[];
  final routes = <String>[];
  final statusesAtRoute = <String?>[];
  _Fixture() {
    auth = AuthService(
      store: _Store(),
      baseUrl: 'http://localhost/api/v1',
      client: MockClient((request) async {
        operations.add('${request.method} ${request.url.path}');
        if (request.url.path.endsWith('/login')) {
          final id = (jsonDecode(request.body) as Map)['email'];
          return http.Response(
            jsonEncode({
              'accessToken': 'access-$id',
              'refreshToken': 'refresh-$id',
              'user': {'id': id},
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/notification-devices')) {
          registrations.add(
            Map<String, dynamic>.from(jsonDecode(request.body) as Map),
          );
        }
        return http.Response('', 204);
      }),
    );
    inbox = _Inbox(auth);
    push = NotificationPushService(
      auth: auth,
      inbox: inbox,
      messaging: messaging,
      installations: _Installation(),
    );
  }
  Future<void> login([String id = 'B']) =>
      auth.login(email: id, password: 'test', remember: false);
  void attach() => push.attachRouter((id) async {
    routes.add(id);
    statusesAtRoute.add(inbox.resolvedStatus);
  });
  void dispose() {
    push.dispose();
    inbox.dispose();
    auth.dispose();
  }
}

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets(
    'PUSH-F01 one registration after authenticated startup AND navigator ready',
    (tester) async {
      final f = _Fixture();
      await f.push.start();
      await f.push.start();
      await f.login();
      await _flush(tester);
      expect(f.registrations, isEmpty);
      f.attach();
      await _flush(tester);
      expect(f.registrations.length, 1);
      expect(f.registrations.single['platform'], 'ANDROID');
      expect(f.registrations.single.containsKey('userId'), false);
      expect(f.push.registered, true);
      f.dispose();
    },
  );

  testWidgets('PUSH-F02 token refresh rebinds the same installation', (
    tester,
  ) async {
    final f = _Fixture();
    await f.push.start();
    await f.login();
    f.attach();
    await _flush(tester);
    f.messaging.tokens.add('token-2');
    await _flush(tester);
    expect(f.registrations.last['token'], 'token-2');
    expect(
      f.registrations.first['installationId'],
      f.registrations.last['installationId'],
    );
    f.dispose();
  });

  testWidgets(
    'PUSH-F03 logout unregisters before session revocation and deletes FCM token',
    (tester) async {
      final f = _Fixture();
      await f.push.start();
      await f.login();
      f.attach();
      await _flush(tester);
      await f.auth.logout();
      await _flush(tester);
      final unregister = f.operations.indexOf(
        'DELETE /api/v1/notification-devices/current',
      );
      final logout = f.operations.indexOf('POST /api/v1/auth/logout');
      expect(unregister, greaterThanOrEqualTo(0));
      expect(unregister, lessThan(logout));
      expect(f.messaging.deletes, greaterThanOrEqualTo(1));
      expect(f.push.registered, false);
      f.dispose();
    },
  );

  testWidgets(
    'PUSH-F04 foreground FCM only invalidates existing store, never navigates or builds a second popup',
    (tester) async {
      final f = _Fixture();
      await f.push.start();
      await f.login();
      f.attach();
      await _flush(tester);
      f.messaging.foreground.add(
        const PushHint('notification-1', 'B', 'message-1'),
      );
      await _flush(tester);
      expect(f.inbox.invalidations, 1);
      expect(f.routes, isEmpty);
      f.dispose();
    },
  );

  for (final status in ['PENDING', 'CANCELLED', 'ACCEPTED']) {
    testWidgets(
      'PUSH-F05/06/07 push opens using current server $status, not payload state',
      (tester) async {
        final f = _Fixture();
        f.inbox.status = status;
        await f.push.start();
        await f.login();
        f.attach();
        await _flush(tester);
        f.messaging.opens.add(
          const PushHint('notification-1', 'B', 'message-1'),
        );
        await _flush(tester);
        expect(f.routes, ['notification-1']);
        expect(f.statusesAtRoute, [status]);
        f.dispose();
      },
    );
  }

  testWidgets(
    'PUSH-F08 cold start waits for auth/navigation and initial+opened message routes once',
    (tester) async {
      final f = _Fixture();
      f.messaging.initial = const PushHint('notification-1', 'B', 'message-1');
      await f.push.start();
      expect(f.routes, isEmpty);
      expect(f.inbox.resolutions, 0);
      await f.login();
      await _flush(tester);
      expect(f.routes, isEmpty);
      f.attach();
      await _flush(tester);
      f.messaging.opens.add(f.messaging.initial!);
      await _flush(tester);
      expect(f.routes, ['notification-1']);
      f.dispose();
    },
  );

  testWidgets(
    'PUSH-F09 account switch drops old hints and late in-flight resolution',
    (tester) async {
      final f = _Fixture();
      await f.push.start();
      await f.login();
      f.attach();
      await _flush(tester);
      final wait = Completer<void>();
      f.inbox.block = wait;
      f.messaging.opens.add(
        const PushHint('old-notification', 'B', 'old-message'),
      );
      await tester.pump();
      await f.auth.clearLocal();
      await f.login('C');
      wait.complete();
      f.inbox.block = null;
      await _flush(tester);
      f.messaging.foreground.add(
        const PushHint('old-notification', 'B', 'old-message'),
      );
      f.messaging.opens.add(
        const PushHint('old-notification', 'B', 'old-message'),
      );
      await _flush(tester);
      expect(f.routes, isEmpty);
      expect(f.inbox.invalidations, 0);
      expect(f.messaging.deletes, greaterThanOrEqualTo(1));
      f.dispose();
    },
  );

  testWidgets(
    'PUSH-F10 permission denial is real, unregisters device and leaves Auth/Inbox usable',
    (tester) async {
      final f = _Fixture();
      f.messaging.allowed = false;
      await f.push.start();
      await f.login();
      f.attach();
      await _flush(tester);
      expect(f.registrations, isEmpty);
      expect(f.push.permissionGranted, false);
      expect(f.push.registered, false);
      expect(f.auth.signedIn, true);
      expect(
        f.operations,
        contains('DELETE /api/v1/notification-devices/current'),
      );
      expect(
        (await f.inbox.resolve('notification-1')).isPendingInvitation,
        true,
      );
      f.dispose();
    },
  );

  testWidgets(
    'Unverified payload cannot navigate, resume retries server reconciliation',
    (tester) async {
      final f = _Fixture();
      f.inbox.fail = true;
      await f.push.start();
      await f.login();
      f.attach();
      await _flush(tester);
      f.messaging.opens.add(const PushHint('notification-1', 'B', 'message-1'));
      await _flush(tester);
      expect(f.routes, isEmpty);
      f.inbox.fail = false;
      f.push.setForeground(true);
      await _flush(tester);
      expect(f.routes, ['notification-1']);
      f.dispose();
    },
  );

  testWidgets(
    'Distinct re-invite notification/message identities are not collapsed',
    (tester) async {
      final f = _Fixture();
      await f.push.start();
      await f.login();
      f.attach();
      await _flush(tester);
      f.messaging.opens.add(
        const PushHint('notification-old', 'B', 'message-old'),
      );
      await _flush(tester);
      f.messaging.opens.add(
        const PushHint('notification-new', 'B', 'message-new'),
      );
      await _flush(tester);
      expect(f.routes, ['notification-old', 'notification-new']);
      f.dispose();
    },
  );
}
