import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/network/api_exception.dart';
import '../../home/data/post_interaction_repository.dart';
import '../../home/models/post_interaction_models.dart';
import 'post_repository.dart';
import 'post_interaction_changes.dart';

class CommentPage {
  final List<PostComment> items;
  final String? nextCursor;
  CommentPage(Map<String, dynamic> data)
    : items = (data['items'] as List)
          .map((r) => PostComment.fromApi(Map<String, dynamic>.from(r as Map)))
          .toList(),
      nextCursor = data['nextCursor'] as String?;
}

/// One sheet owns its draft/upload retry IDs. No production demo fallback.
class ApiPostInteractionRepository extends PostInteractionRepository {
  final AuthService auth;
  late final String? _actor = auth.user?['id']?.toString();
  final _ids = <String, String>{};
  final _uploaded = <String, String>{};
  Map<String, dynamic>? _pending;
  String? _pendingPost;
  ApiPostInteractionRepository({required this.auth}) {
    _check();
  }
  void _check() {
    if (_actor == null || _actor != auth.user?['id']?.toString())
      throw StateError('Tài khoản đã thay đổi');
  }

  Future<CommentPage> page(String post, {String? cursor}) async {
    _check();
    final data = await auth.request(
      'GET',
      '/posts/$post/comments${cursor == null ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}'}',
    );
    _check();
    return CommentPage(data);
  }

  Future<CommentPage> replies(String id, {String? cursor}) async {
    _check();
    final data = await auth.request(
      'GET',
      '/comments/$id/replies${cursor == null ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}'}',
    );
    _check();
    return CommentPage(data);
  }

  @override
  Future<List<PostComment>> getComments(String postId) async =>
      (await page(postId)).items;
  @override
  Future<PostComment> createComment({
    required String postId,
    required String body,
    String? parentId,
    List<String> mediaAssets = const [],
  }) async {
    _check();
    if (body.characters.length > 2000 ||
        mediaAssets.length > 6 ||
        (body.trim().isEmpty && mediaAssets.isEmpty))
      throw StateError(
        'Bình luận cần nội dung (tối đa 2.000 ký tự) hoặc 1–6 ảnh',
      );
    try {
      if (_pending == null) {
        final media = <String>[];
        for (final path in mediaAssets) {
          final key = '$postId:$path';
          if (!_uploaded.containsKey(key)) {
            final r = await auth.multipartRequest(
              '/posts/$postId/comments/media',
              fileField: 'file',
              filePath: path,
              fields: {'uploadId': _ids.putIfAbsent(key, newPostRequestId)},
              timeout: const Duration(minutes: 3),
            );
            _check();
            _uploaded[key] = r['mediaId'] as String;
          }
          media.add(_uploaded[key]!);
        }
        _pendingPost = postId;
        _pending = {
          'clientRequestId': newPostRequestId(),
          'body': body,
          'parentId': parentId == null ? null : int.parse(parentId),
          'mediaIds': media,
        };
      }
      final result = await auth.request(
        'POST',
        '/posts/$_pendingPost/comments',
        body: _pending,
      );
      _check();
      _pending = null;
      _ids.clear();
      _uploaded.clear();
      final comment = PostComment.fromApi(result);
      PostInteractionChanges.acknowledged(
        PostInteractionChange(
          auth: auth,
          actor: _actor,
          postId: int.parse(postId),
          kind: 'comment',
          commentId: int.parse(comment.id),
          parentCommentId: int.tryParse(comment.parentId ?? ''),
        ),
      );
      return comment;
    } on ApiException catch (e) {
      if (e.status >= 400 && e.status < 500 && e.status != 408) {
        _pending = null;
        if (e.code == 'COMMENT_MEDIA_BUSY' ||
            e.code == 'COMMENT_MEDIA_NOT_READY') {
          _ids.clear();
          _uploaded.clear();
        }
      }
      rethrow;
    }
  }

  bool get commitPending => _pending != null;
  @override
  Future<void> deleteComment(
    String id, {
    String? postId,
    String? parentId,
  }) async {
    _check();
    await auth.request('DELETE', '/comments/$id');
    _check();
    if (postId != null) {
      PostInteractionChanges.acknowledged(
        PostInteractionChange(
          auth: auth,
          actor: _actor,
          postId: int.parse(postId),
          kind: 'comment',
          commentId: int.parse(id),
          parentCommentId: int.tryParse(parentId ?? ''),
          removed: true,
        ),
      );
    }
  }

  @override
  Future<PostComment> toggleCommentLike(PostComment c) async {
    _check();
    final r = await auth.request(
      c.isLiked ? 'DELETE' : 'PUT',
      '/comments/${c.id}/like',
    );
    _check();
    return PostComment.fromApi(r);
  }

  @override
  Future<List<ShareContact>> getShareContacts() => throw UnsupportedError('P4');
  @override
  Future<List<ShareContact>> searchShareContacts(String query) =>
      throw UnsupportedError('P4');
  @override
  Future<void> sharePost({
    required String postId,
    required Set<String> recipientIds,
    String? message,
  }) => throw UnsupportedError('P4');
}
