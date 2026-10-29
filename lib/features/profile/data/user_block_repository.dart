import 'package:flutter/foundation.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/content_access_changes.dart';

class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.name,
    this.nickname = '',
    this.avatarUrl,
    this.blockedAt,
  });
  final String id, name, nickname;
  final String? avatarUrl;
  final DateTime? blockedAt;
  factory BlockedUser.fromJson(Map json) => BlockedUser(
    id: json['userId'] as String,
    name:
        (json['displayName'] ??
                json['name'] ??
                json['nickname'] ??
                'Người dùng')
            as String,
    nickname: (json['nickname'] ?? '') as String,
    avatarUrl: json['avatarUrl'] as String?,
    blockedAt: DateTime.tryParse(json['blockedAt']?.toString() ?? ''),
  );
}

/// API-only account block. DIRECT legacy endpoints delegate to this same policy.
class UserBlockRepository extends ChangeNotifier {
  UserBlockRepository({AuthService? auth})
    : auth = auth ?? AuthService.instance;
  static final instance = UserBlockRepository();
  final AuthService auth;
  Future<Map<String, dynamic>> page({int page = 0}) =>
      auth.request('GET', '/users/me/blocked?page=$page&size=50');
  Future<List<BlockedUser>> groupMembers(String id) async {
    final rows = await auth.requestJson(
      'GET',
      '/conversations/$id/blocked-members',
    );
    return (rows as List).map((r) => BlockedUser.fromJson(r as Map)).toList();
  }

  Future<void> setBlocked(String id, bool value) async {
    final owner = auth.user?['id'];
    final generation = auth.sessionGeneration;
    await auth.request(
      value ? 'PUT' : 'DELETE',
      '/users/${Uri.encodeComponent(id)}/block',
    );
    if (owner == null ||
        owner != auth.user?['id'] ||
        generation != auth.sessionGeneration) {
      throw StateError('Phiên đăng nhập đã thay đổi.');
    }
    ContentAccessChanges.changed();
    notifyListeners();
    try {
      await auth.loadProfile();
    } catch (_) {
      /* Mutation already acknowledged. */
    }
  }
}
