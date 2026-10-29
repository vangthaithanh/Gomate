import 'dart:async';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PushHint {
  const PushHint(this.notificationId, this.recipientId, this.messageId);
  final String notificationId;
  final String recipientId;
  final String messageId;

  static PushHint? fromMessage(RemoteMessage message) {
    final id = message.data['notificationId'];
    final recipient = message.data['recipientUserId'];
    if (id is! String ||
        id.isEmpty ||
        recipient is! String ||
        recipient.isEmpty) {
      return null;
    }
    return PushHint(id, recipient, message.messageId ?? id);
  }
}

abstract class PushMessaging {
  Future<bool> initialize();
  Stream<String> get tokenChanges;
  Stream<PushHint> get foregroundMessages;
  Stream<PushHint> get openedMessages;
  Future<PushHint?> initialMessage();
  Future<bool> permission();
  Future<String?> token();
  Future<void> deleteToken();
}

abstract class PushInstallationStore {
  Future<String> installationId();
}

class SecurePushInstallationStore implements PushInstallationStore {
  final _storage = const FlutterSecureStorage();
  Future<String>? _loading;
  @override
  Future<String> installationId() => _loading ??= _load();

  Future<String> _load() async {
    const key = 'gomate.push.installation.v1';
    final existing = await _storage.read(key: key);
    if (existing != null) return existing;
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _storage.write(key: key, value: id);
    return id;
  }
}

@pragma('vm:entry-point')
Future<void> goMateBackgroundMessage(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  // Notification+data is displayed by Android. Never create a second notification,
  // navigate, read Auth storage, or mutate business state from this isolate.
}

class FirebasePushMessaging implements PushMessaging {
  final _storage = const FlutterSecureStorage();
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<bool> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(goMateBackgroundMessage);
    return true;
  }

  @override
  Stream<String> get tokenChanges => _messaging.onTokenRefresh;
  @override
  Stream<PushHint> get foregroundMessages => FirebaseMessaging.onMessage
      .map(PushHint.fromMessage)
      .where((hint) => hint != null)
      .cast<PushHint>();
  @override
  Stream<PushHint> get openedMessages => FirebaseMessaging.onMessageOpenedApp
      .map(PushHint.fromMessage)
      .where((hint) => hint != null)
      .cast<PushHint>();
  @override
  Future<PushHint?> initialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : PushHint.fromMessage(message);
  }

  @override
  Future<bool> permission() async {
    var settings = await _messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      return true;
    }
    const askedKey = 'gomate.push.permission.asked.v1';
    if (await _storage.read(key: askedKey) != 'true') {
      // Android 13 reports both never-requested and denied as denied.
      await _storage.write(key: askedKey, value: 'true');
      settings = await _messaging.requestPermission();
    }
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> token() => _messaging.getToken();
  @override
  Future<void> deleteToken() => _messaging.deleteToken();
}
