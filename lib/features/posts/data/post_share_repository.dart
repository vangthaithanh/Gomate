import '../../../core/services/auth_service.dart';
import '../../home/models/post_interaction_models.dart';
import 'comment_repository.dart';
import 'post_repository.dart';

class SharePartialFailure implements Exception {
  final Set<String> sent;
  final String message;
  final Map<String, String> failures;
  SharePartialFailure(this.sent, this.message, [this.failures = const {}]);
}

/// One mounted sheet owns one unresolved request; retries reuse its durable key.
class PostShareRepository extends ApiPostInteractionRepository {
  final String postId;
  late final String? _owner = auth.user?['id']?.toString();
  Map<String, dynamic>? _share;
  String? _batchId;
  String? _text;
  bool get draftLocked => _batchId != null;
  PostShareRepository({required AuthService auth, required this.postId})
    : super(auth: auth);
  @override
  bool get commitPending => _share != null;
  void _guard() {
    if (_owner == null || _owner != auth.user?['id']?.toString())
      throw StateError('Tài khoản đã thay đổi');
  }

  Future<List<ShareContact>> _targets(String query) async {
    _guard();
    final data = await auth.requestJson(
      'GET',
      Uri(
        path: '/posts/$postId/share-targets',
        queryParameters: {'q': query},
      ).toString(),
    );
    _guard();
    return (data as List)
        .map(
          (r) => ShareContact(
            id: '${r['type']}:${r['targetId']}',
            name: r['name'] as String,
            subtitle: r['subtitle'] as String? ?? '',
            avatarAsset: r['avatarUrl'] as String? ?? '',
            type: r['type'] == 'GROUP'
                ? ShareTargetType.group
                : ShareTargetType.user,
          ),
        )
        .toList();
  }

  @override
  Future<List<ShareContact>> getShareContacts() => _targets('');
  @override
  Future<List<ShareContact>> searchShareContacts(String query) =>
      _targets(query);
  @override
  Future<void> sharePost({
    required String postId,
    required Set<String> recipientIds,
    String? message,
  }) async {
    _guard();
    if (postId != this.postId) throw ArgumentError('Sai bài viết');
    _batchId ??= newPostRequestId();
    _text ??= message ?? '';
    _share ??= {
      'clientRequestId': _batchId,
      'message': _text,
      'targets': recipientIds
          .map(
            (key) => {
              'type': key.split(':').first,
              'targetId': key.split(':').last,
            },
          )
          .toList(),
    };
    final data = await auth.requestJson(
      'POST',
      '/posts/$postId/shares',
      body: _share,
    );
    _guard();
    final rows = data as List;
    final expected = (_share!['targets'] as List)
        .map((t) => '${t['type']}:${t['targetId']}')
        .toSet();
    final received = rows.map((r) => '${r['type']}:${r['targetId']}').toSet();
    if (expected.length != received.length || !expected.containsAll(received))
      throw StateError('Chưa xác nhận đủ đích gửi. Hãy thử lại.');
    final sent = rows
        .where((r) => r['success'] == true)
        .map((r) => '${r['type']}:${r['targetId']}')
        .toSet();
    _share = null;
    if (sent.length != rows.length) {
      final failures = rows
          .where((r) => r['success'] != true)
          .map((r) => r['message'] ?? 'Không thể gửi')
          .toSet()
          .join('\n');
      throw SharePartialFailure(sent, failures, {
        for (final r in rows.where((r) => r['success'] != true))
          '${r['type']}:${r['targetId']}':
              r['message'] as String? ?? 'Không thể gửi',
      });
    }
  }
}
