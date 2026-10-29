import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/session_store.dart';
import 'package:gomate/features/notifications/data/notification_realtime_client.dart';
import 'package:gomate/features/notifications/data/notification_repository.dart';
import 'package:gomate/features/notifications/screens/notification_screen.dart';

class _Store implements SessionStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
}

class _Realtime implements NotificationRealtimeClient {
  final channels = <StreamController<NotificationRealtimeEvent>>[];
  var connects = 0;
  var disconnects = 0;
  @override
  Stream<NotificationRealtimeEvent> connect() {
    connects++;
    final channel = StreamController<NotificationRealtimeEvent>();
    channels.add(channel);
    return channel.stream;
  }

  @override
  void disconnect() {
    disconnects++;
  }

  void signal(String id, {String kind = 'CREATED', String eventId = 'event'}) {
    channels.last.add(
      NotificationRealtimeEvent(
        eventId: eventId,
        eventKind: kind,
        notificationId: id,
      ),
    );
  }
}

class _Fixture {
  final rows = <String, Map<String, dynamic>>{};
  final realtime = _Realtime();
  late final AuthService auth;
  late final NotificationRepository inbox;
  var account = 'B';
  var polls = 0;
  var refreshes = 0;
  var offline = false;
  Completer<void>? pause;
  Completer<void>? pauseDetail;

  _Fixture() {
    auth = AuthService(
      store: _Store(),
      baseUrl: 'http://localhost/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          account = (jsonDecode(request.body) as Map)['email'] as String;
          return _response(_session());
        }
        if (request.url.path.endsWith('/refresh')) {
          refreshes++;
          return _response(_session(token: 'rotated-$refreshes'));
        }
        if (request.url.path.endsWith('/force-refresh') &&
            request.headers['Authorization'] == 'Bearer token') {
          return http.Response('{}', 401);
        }
        if (request.url.path.endsWith('/force-refresh')) {
          return _response({'ok': true});
        }
        if (request.url.path.endsWith('/notifications')) {
          polls++;
          final body = jsonEncode({
            'items': rows.values.toList(),
            'total': rows.length,
            'unreadCount': rows.values
                .where((r) => r['isRead'] == false)
                .length,
          });
          if (pause != null) await pause!.future;
          if (offline) throw http.ClientException('network unavailable');
          return http.Response(body, 200);
        }
        final row = rows[request.url.path.split('/').last];
        final response = row == null
            ? http.Response('{}', 404)
            : _response(row);
        final detailWait = pauseDetail;
        pauseDetail = null;
        if (detailWait != null) await detailWait.future;
        return response;
      }),
    );
    inbox = NotificationRepository(
      auth: auth,
      realtime: realtime,
      reconnectDelay: const Duration(milliseconds: 100),
    );
  }

  Map<String, dynamic> _session({String token = 'token'}) => {
    'accessToken': token,
    'refreshToken': 'refresh',
    'user': {'id': account},
  };
  http.Response _response(Object json) => http.Response(jsonEncode(json), 200);
  Future<void> login([String id = 'B']) =>
      auth.login(email: id, password: 'test', remember: false);
  void add(
    String id, {
    String status = 'PENDING',
    String type = 'TRIP_INVITATION',
  }) {
    rows[id] = {
      'id': id,
      'type': type,
      'actorId': 'A',
      'actorName': 'Actor A',
      'invitationId': 'invitation-$id',
      'invitationStatus': status,
      'tripId': 'trip-1',
      'tripName': 'Test Trip',
      'occurredAt': DateTime.utc(2026, 10, 15, 8).toIso8601String(),
      'isRead': false,
    };
  }

  void dispose() {
    inbox.dispose();
    auth.dispose();
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
}

class _StreamingClient extends http.BaseClient {
  _StreamingClient(this.sendRequest, {this.onClose});
  final Future<http.StreamedResponse> Function(http.BaseRequest) sendRequest;
  final void Function()? onClose;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      sendRequest(request);
  @override
  void close() {
    if (closed) return;
    closed = true;
    onClose?.call();
  }
}

void main() {
  testWidgets('D2/D1 each popup once across SSE and polling', (tester) async {
    final f = _Fixture();
    await f.login();
    final popups = <String>[];
    f.inbox.events.listen((item) => popups.add(item.id));
    f.inbox.start();
    await _settle(tester);
    for (final days in [2, 1]) {
      final id = 'reminder-d$days';
      f.add(id, type: 'TRIP_START_REMINDER', status: 'UNAVAILABLE');
      f.rows[id]!.remove('invitationId');
      f.rows[id]!['reminderId'] = id;
      f.rows[id]!['reminderDaysBefore'] = days;
      f.rows[id]!['tripStartDate'] = '2026-10-28';
      f.rows[id]!['reminderDate'] = '2026-10-${28 - days}';
      f.rows[id]!['reminderTimezone'] = 'Asia/Ho_Chi_Minh';
      f.rows[id]!['message'] = 'Prepare for Trip in $days days';
      f.realtime.signal(id, eventId: 'event-d$days');
      await _settle(tester);
      await f.inbox.refresh();
      f.realtime.signal(id, eventId: 'repeat-d$days');
      await _settle(tester);
    }
    await tester.pump(const Duration(seconds: 13));
    await _settle(tester);
    expect(f.inbox.error, isNull);
    expect(f.inbox.items.length, 2);
    expect(popups, ['reminder-d2', 'reminder-d1']);
    expect(f.inbox.items.map((n) => n.reminderDaysBefore).toSet(), {2, 1});
    expect(f.inbox.items.every((n) => n.tripStartDate == '2026-10-28'), true);
    expect(
      f.inbox.items.every((n) => n.reminderTimezone == 'Asia/Ho_Chi_Minh'),
      true,
    );
    expect(f.inbox.items.every((n) => !n.isPendingInvitation), true);
    f.dispose();
  });

  testWidgets(
    'FRT01 one global receiver, repeated start/foreground does not subscribe twice',
    (tester) async {
      final f = _Fixture();
      await f.login();
      f.inbox.start();
      f.inbox.start();
      f.inbox.setForeground(true);
      await _settle(tester);
      expect(f.realtime.connects, 1);
      f.dispose();
    },
  );

  testWidgets(
    'FRT02/03/05 realtime reconciles one row/popup; duplicate signals and polling do not duplicate',
    (tester) async {
      final f = _Fixture();
      await f.login();
      var popups = 0;
      f.inbox.events.listen((_) => popups++);
      f.inbox.start();
      await _settle(tester);
      f.add('new-1');
      f.realtime.signal('new-1');
      await _settle(tester);
      expect(f.inbox.items.single.id, 'new-1');
      expect(popups, 1);
      f.realtime.signal('new-1');
      f.realtime.signal(
        'new-1',
        eventId: 'different-delivery-same-notification',
      );
      await _settle(tester);
      await f.inbox.refresh();
      expect(f.inbox.items.length, 1);
      expect(popups, 1);
      f.dispose();
    },
  );

  testWidgets('FRT06 polling first then realtime shows a popup once', (
    tester,
  ) async {
    final f = _Fixture();
    await f.login();
    var popups = 0;
    f.inbox.events.listen((_) => popups++);
    f.inbox.start();
    await _settle(tester);
    f.add('poll-first');
    await f.inbox.refresh();
    f.realtime.signal('poll-first');
    await _settle(tester);
    expect(f.inbox.items.length, 1);
    expect(popups, 1);
    f.dispose();
  });

  testWidgets(
    'FRT07 CANCELLED removes Accept immediately with no cancellation popup',
    (tester) async {
      final f = _Fixture()..add('pending');
      await f.login();
      var popups = 0;
      f.inbox.events.listen((_) => popups++);
      f.inbox.start();
      await _settle(tester);
      await tester.pumpWidget(
        MaterialApp(home: GoMateNotificationScreen(repository: f.inbox)),
      );
      await _settle(tester);
      expect(find.text('Chấp nhận'), findsOneWidget);
      f.rows['pending']!['invitationStatus'] = 'CANCELLED';
      f.realtime.signal('pending', kind: 'UPDATED');
      await _settle(tester);
      expect(find.text('Chấp nhận'), findsNothing);
      expect(f.inbox.items.single.invitationStatus, 'CANCELLED');
      expect(popups, 0);
      await tester.pumpWidget(const SizedBox());
      f.dispose();
    },
  );

  testWidgets(
    'FRT08 reordered stale signals fetch current truth; re-invite remains distinct',
    (tester) async {
      final f = _Fixture()..add('old', status: 'CANCELLED');
      await f.login();
      final popups = <String>[];
      f.inbox.events.listen((item) => popups.add(item.id));
      f.inbox.start();
      await _settle(tester);
      f.add('reinvite');
      f.realtime.signal('reinvite');
      await _settle(tester);
      f.realtime.signal('old', eventId: 'late-created-signal');
      await _settle(tester);
      expect(f.inbox.items.length, 2);
      expect(f.inbox.byId('old')!.invitationStatus, 'CANCELLED');
      expect(popups, ['reinvite']);
      f.dispose();
    },
  );

  testWidgets(
    'FRT09 logout disconnects and late old-account events cannot leak',
    (tester) async {
      final f = _Fixture();
      await f.login();
      var popups = 0;
      f.inbox.events.listen((_) => popups++);
      f.inbox.start();
      await _settle(tester);
      final old = f.realtime.channels.single;
      final before = f.realtime.disconnects;
      await f.auth.clearLocal();
      expect(f.realtime.disconnects, greaterThan(before));
      f.rows.clear();
      await f.login('C');
      await _settle(tester);
      old.add(
        const NotificationRealtimeEvent(
          eventId: 'old-event',
          eventKind: 'CREATED',
          notificationId: 'old-user-row',
        ),
      );
      await _settle(tester);
      expect(f.inbox.items, isEmpty);
      expect(popups, 0);
      expect(f.realtime.connects, 2);
      f.dispose();
    },
  );

  testWidgets(
    'FRT10 reconnect ready reconciles missed notifications without duplicates',
    (tester) async {
      final f = _Fixture();
      await f.login();
      var popups = 0;
      f.inbox.events.listen((_) => popups++);
      f.inbox.start();
      await _settle(tester);
      f.offline = true;
      f.realtime.channels.last.addError(StateError('disconnected'));
      await tester.pump();
      f.add('missed');
      f.offline = false;
      await _settle(tester);
      await _settle(tester);
      f.realtime.channels.last.add(const NotificationRealtimeEvent.ready());
      await _settle(tester);
      expect(f.realtime.connects, 2);
      expect(f.inbox.items.single.id, 'missed');
      expect(popups, 1);
      f.realtime.signal('missed');
      await _settle(tester);
      expect(popups, 1);
      f.dispose();
    },
  );

  testWidgets(
    'Background disconnects, resume refreshes without recreating UI subscriptions',
    (tester) async {
      final f = _Fixture();
      await f.login();
      f.inbox.start();
      await _settle(tester);
      f.inbox.setForeground(false);
      f.add('background');
      await tester.pump(const Duration(seconds: 20));
      expect(f.realtime.connects, 1);
      expect(f.inbox.items, isEmpty);
      f.inbox.setForeground(true);
      await _settle(tester);
      expect(f.realtime.connects, 2);
      expect(f.inbox.items.single.id, 'background');
      f.dispose();
    },
  );

  testWidgets(
    'Unchanged 12 second polling remains usable when SSE is unavailable',
    (tester) async {
      final f = _Fixture();
      await f.login();
      f.inbox.start();
      await _settle(tester);
      f.add('fallback');
      await tester.pump(const Duration(seconds: 12));
      await tester.pump();
      expect(f.inbox.items.single.id, 'fallback');
      expect(f.realtime.connects, 1);
      f.dispose();
    },
  );

  testWidgets(
    'A signal during an old poll cannot be lost or restore stale pending state',
    (tester) async {
      final f = _Fixture()..add('pending');
      await f.login();
      f.inbox.start();
      await _settle(tester);
      f.pause = Completer<void>();
      final oldPoll = f.inbox.refresh();
      f.rows['pending']!['invitationStatus'] = 'CANCELLED';
      f.realtime.signal('pending', kind: 'UPDATED');
      await _settle(tester);
      f.pause!.complete();
      f.pause = null;
      await oldPoll;
      await _settle(tester);
      expect(f.inbox.items.single.invitationStatus, 'CANCELLED');
      f.dispose();
    },
  );

  testWidgets(
    'Credential rotation reconnects once without clearing the current inbox',
    (tester) async {
      final f = _Fixture()..add('history');
      await f.login();
      f.inbox.start();
      await _settle(tester);
      await f.auth.request('GET', '/force-refresh');
      await _settle(tester);
      expect(f.refreshes, 1);
      expect(f.realtime.connects, 2);
      expect(f.inbox.items.single.id, 'history');
      f.dispose();
    },
  );

  testWidgets('A stale detail response cannot undo a realtime cancellation', (
    tester,
  ) async {
    final f = _Fixture()..add('pending');
    await f.login();
    f.inbox.start();
    await _settle(tester);
    final wait = Completer<void>();
    f.pauseDetail = wait;
    final oldDetail = f.inbox.resolve('pending');
    await tester.pump();
    f.rows['pending']!['invitationStatus'] = 'CANCELLED';
    f.realtime.signal('pending', kind: 'UPDATED');
    await _settle(tester);
    wait.complete();
    await oldDetail;
    expect(f.inbox.items.single.invitationStatus, 'CANCELLED');
    f.dispose();
  });

  testWidgets(
    'Stopping and restarting the app shell does not leave reconciliation blocked',
    (tester) async {
      final f = _Fixture();
      await f.login();
      f.inbox.start();
      await _settle(tester);
      f.inbox.stop();
      f.inbox.start();
      await _settle(tester);
      f.add('after-restart');
      f.realtime.signal('after-restart');
      await _settle(tester);
      expect(f.realtime.connects, 2);
      expect(f.inbox.items.single.id, 'after-restart');
      f.dispose();
    },
  );

  test(
    'SSE uses the shared auth header, parses fragmented frames and closes the dedicated client',
    () async {
      final f = _Fixture();
      await f.login();
      final data = StreamController<List<int>>();
      final client = _StreamingClient((request) async {
        expect(
          request.url.toString(),
          'http://localhost/api/v1/notifications/stream',
        );
        expect(request.url.hasQuery, false);
        expect(request.headers['Authorization'], 'Bearer token');
        return http.StreamedResponse(
          data.stream,
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });
      final sse = SseNotificationRealtimeClient(
        auth: f.auth,
        clientFactory: () => client,
      );
      final events = <NotificationRealtimeEvent>[];
      final done = Completer<void>();
      final subscription = sse.connect().listen((event) {
        events.add(event);
        if (events.length == 2) done.complete();
      });
      data.add(
        utf8.encode(
          'event:ready\r\ndata:{}\r\n\r\n:keepalive\r\n\r\nevent:notifi',
        ),
      );
      data.add(
        utf8.encode(
          'cation\ndata:${jsonEncode({'eventId': 'event-1', 'eventKind': 'CREATED', 'notificationId': 'item-1', 'occurredAt': '2026-10-15T08:00:00Z'})}\n\n',
        ),
      );
      await done.future.timeout(const Duration(seconds: 3));
      expect(events.map((event) => event.eventKind), ['READY', 'CREATED']);
      expect(events.last.notificationId, 'item-1');
      sse.disconnect();
      expect(client.closed, true);
      await data.close();
      await subscription.cancel();
      f.dispose();
    },
  );

  test('SSE intentional disconnect consumes the HTTP close error', () async {
    final f = _Fixture();
    await f.login();
    final data = StreamController<List<int>>();
    final client = _StreamingClient(
      (_) async => http.StreamedResponse(
        data.stream,
        200,
        headers: {'content-type': 'text/event-stream'},
      ),
      onClose: () {
        data.addError(http.ClientException('Connection closed by client'));
        unawaited(data.close());
      },
    );
    final sse = SseNotificationRealtimeClient(
      auth: f.auth,
      clientFactory: () => client,
    );
    final ready = Completer<void>();
    final errors = <Object>[];
    final done = Completer<void>();
    sse.connect().listen(
      (_) => ready.complete(),
      onError: (Object error) => errors.add(error),
      onDone: done.complete,
    );
    data.add(utf8.encode('event:ready\ndata:{}\n\n'));
    await ready.future.timeout(const Duration(seconds: 3));
    sse.disconnect();
    await done.future.timeout(const Duration(seconds: 3));
    expect(client.closed, true);
    expect(errors, isEmpty);
    f.dispose();
  });

  test('SSE real network failure remains visible for reconnect', () async {
    final f = _Fixture();
    await f.login();
    final data = StreamController<List<int>>();
    final client = _StreamingClient(
      (_) async => http.StreamedResponse(
        data.stream,
        200,
        headers: {'content-type': 'text/event-stream'},
      ),
    );
    final sse = SseNotificationRealtimeClient(
      auth: f.auth,
      clientFactory: () => client,
    );
    final ready = Completer<void>();
    final errors = <Object>[];
    final done = Completer<void>();
    sse.connect().listen(
      (_) => ready.complete(),
      onError: (Object error) => errors.add(error),
      onDone: done.complete,
    );
    data.add(utf8.encode('event:ready\ndata:{}\n\n'));
    await ready.future.timeout(const Duration(seconds: 3));
    data.addError(http.ClientException('Network disconnected'));
    await done.future.timeout(const Duration(seconds: 3));
    expect(errors.single, isA<http.ClientException>());
    expect(client.closed, true);
    await data.close();
    f.dispose();
  });
}
