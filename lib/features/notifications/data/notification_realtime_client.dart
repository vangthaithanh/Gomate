import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/services/auth_service.dart';

class NotificationRealtimeEvent {
  const NotificationRealtimeEvent({
    required this.eventId,
    required this.eventKind,
    this.notificationId,
  });

  const NotificationRealtimeEvent.ready()
    : eventId = '',
      eventKind = 'READY',
      notificationId = null;

  final String eventId;
  final String eventKind;
  final String? notificationId;

  factory NotificationRealtimeEvent.fromJson(Map<String, dynamic> json) {
    final kind = json['eventKind'];
    final id = json['eventId'];
    if (id is! String ||
        id.isEmpty ||
        !const ['CREATED', 'UPDATED', 'INBOX_INVALIDATED', 'ACCESS_CHANGED'].contains(kind)) {
      throw const FormatException('Invalid notification signal');
    }
    DateTime.parse(json['occurredAt'] as String);
    return NotificationRealtimeEvent(
      eventId: id,
      eventKind: kind as String,
      notificationId: json['notificationId'] as String?,
    );
  }
}

abstract class NotificationRealtimeClient {
  Stream<NotificationRealtimeEvent> connect();
  void disconnect();
}

/// No UI subscriptions or replay cache. Every signal is reconciled through REST.
class SseNotificationRealtimeClient implements NotificationRealtimeClient {
  SseNotificationRealtimeClient({
    required AuthService auth,
    http.Client Function()? clientFactory,
  }) : _auth = auth,
       _clientFactory = clientFactory ?? http.Client.new;

  final AuthService _auth;
  final http.Client Function() _clientFactory;
  http.Client? _client;
  int _generation = 0;

  @override
  Stream<NotificationRealtimeEvent> connect() {
    disconnect();
    final client = _clientFactory();
    _client = client;
    return _read(client, _generation);
  }

  Stream<NotificationRealtimeEvent> _read(
    http.Client client,
    int generation,
  ) async* {
    try {
      final response = await _auth.openEventStream(client);
      var type = '';
      final data = <String>[];
      var length = 0;
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(seconds: 45));
      await for (final line in lines) {
        if (generation != _generation) return;
        if (line.isEmpty) {
          if (type == 'ready') {
            yield const NotificationRealtimeEvent.ready();
          } else if (type == 'notification' && data.isNotEmpty) {
            yield NotificationRealtimeEvent.fromJson(
              Map<String, dynamic>.from(jsonDecode(data.join('\n')) as Map),
            );
          }
          type = '';
          data.clear();
          length = 0;
        } else if (line.startsWith('event:')) {
          type = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          data.add(line.substring(5).trimLeft());
          length += line.length;
          if (length > 8192) {
            throw const FormatException('Notification signal too large');
          }
        }
      }
    } catch (_) {
      // Closing the dedicated HTTP client is expected on background/logout.
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
