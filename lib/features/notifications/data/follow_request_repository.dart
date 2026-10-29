import '../../../core/services/auth_service.dart';
import '../../../core/services/content_access_changes.dart';

class FollowRequestItem {
  final String id;
  final String requesterId;
  final String name;
  final String? avatarUrl;
  final DateTime createdAt;
  const FollowRequestItem({
    required this.id,
    required this.requesterId,
    required this.name,
    this.avatarUrl,
    required this.createdAt,
  });
  factory FollowRequestItem.fromJson(Map<String, dynamic> json) =>
      FollowRequestItem(
        id: json['id'] as String,
        requesterId: json['requesterId'] as String,
        name: json['fullName'] as String? ?? json['nickname'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}

/// The owner's durable request queue, separate from Trip notifications.
class FollowRequestRepository {
  final AuthService auth;
  FollowRequestRepository({AuthService? auth})
    : auth = auth ?? AuthService.instance;

  Future<({List<FollowRequestItem> items, int total})> pending({
    int page = 0,
  }) async {
    if (!auth.signedIn) return (items: <FollowRequestItem>[], total: 0);
    final json = await auth.request(
      'GET',
      '/users/me/follow-requests?page=$page&size=20',
    );
    return (
      items: (json['items'] as List? ?? [])
          .map(
            (row) => FollowRequestItem.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> respond(String id, {required bool accept}) async {
    await auth.request(
      'POST',
      '/users/me/follow-requests/${Uri.encodeComponent(id)}/${accept ? 'accept' : 'reject'}',
    );
    ContentAccessChanges.changed();
  }
}
