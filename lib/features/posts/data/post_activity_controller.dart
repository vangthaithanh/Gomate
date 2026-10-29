import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/services/content_access_changes.dart';
import 'post_repository.dart';
import 'comment_repository.dart';
import 'post_interaction_changes.dart';

enum PostActivityKind { likes, comments, saved }

class PostActivityItem {
  final Map<String, dynamic> post;
  final int? commentId, parentCommentId;
  final String body, authorName;
  final String? avatarUrl, parentBody, parentAuthor, parentAvatar;
  final DateTime createdAt;
  int get postId => (post['id'] as num).toInt();
  String get id => '${commentId ?? postId}';
  PostActivityItem.fromApi(Map<String, dynamic> data)
    : post = Map<String, dynamic>.from(data['post'] as Map),
      commentId = (data['commentId'] as num?)?.toInt(),
      parentCommentId = (data['parentCommentId'] as num?)?.toInt(),
      body = data['body'] as String? ?? '',
      authorName = data['authorName'] as String? ?? '',
      avatarUrl = data['avatarUrl'] as String?,
      parentBody = data['parentBody'] as String?,
      parentAuthor = data['parentAuthor'] as String?,
      parentAvatar = data['parentAvatar'] as String?,
      createdAt = DateTime.parse(
        (data['createdAt'] ?? data['likedAt'] ?? data['savedAt']) as String,
      );
}

class PostActivityController extends ChangeNotifier {
  final PostRepository repository;
  final PostActivityKind kind;
  List<PostActivityItem> items = [];
  String? cursor, error;
  bool loading = false, revalidating = false, removing = false;
  bool _disposed = false;
  int _request = 0;
  Object? _actor;
  bool? _private;
  Future<void>? _refreshing;
  late final StreamSubscription<PostInteractionChange> _changes;
  PostActivityController(this.kind, this.repository) {
    _actor = repository.auth.user?['id'];
    _private = repository.auth.user?['isPrivate'] == true;
    repository.auth.addListener(_session);
    PostChanges.revision.addListener(_changed);
    ContentAccessChanges.revision.addListener(_changed);
    _changes = PostInteractionChanges.stream.listen(_acknowledged);
  }
  String get _path => switch (kind) {
    PostActivityKind.likes => 'liked-posts',
    PostActivityKind.saved => 'saved-posts',
    PostActivityKind.comments => 'comments',
  };
  void _session() {
    final actor = repository.auth.user?['id'];
    final privacy = repository.auth.user?['isPrivate'] == true;
    if (actor == _actor && privacy == _private) return;
    _actor = actor;
    _private = privacy;
    _request++;
    _refreshing = null;
    items = [];
    cursor = null;
    error = null;
    loading = revalidating = false;
    notifyListeners();
    unawaited(refresh());
  }

  void _changed() {
    if (!_disposed && !removing) {
      _request++;
      _refreshing = null;
      unawaited(refresh());
    }
  }

  void _acknowledged(PostInteractionChange change) {
    if (_disposed || !change.belongsTo(repository.auth)) return;
    final matches = switch (kind) {
      PostActivityKind.likes => change.kind == 'like',
      PostActivityKind.saved => change.kind == 'save',
      PostActivityKind.comments => change.kind == 'comment',
    };
    if (!matches) return;
    if (change.removed) {
      items = items
          .where(
            (item) => kind == PostActivityKind.comments
                ? item.commentId != change.commentId &&
                      item.parentCommentId != change.commentId
                : item.postId != change.postId,
          )
          .toList();
      notifyListeners();
    }
    if (removing) {
      // An older page must not restore a relation after its removal ACK.
      _request++;
      _refreshing = null;
    } else {
      _changed();
    }
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    if (_refreshing != null) return _refreshing!;
    final done = Completer<void>();
    final future = done.future;
    _refreshing = future;
    _load(reset: true).whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
      done.complete();
    });
    return future;
  }

  Future<void> more() => _load(reset: false);
  Future<void> _load({required bool reset}) async {
    if (_disposed || (!reset && (loading || cursor == null))) return;
    final request = ++_request;
    final actor = repository.auth.user?['id'];
    if (reset) {
      cursor = null;
      revalidating = true;
    }
    loading = true;
    error = null;
    if (actor == null) {
      items = [];
      loading = revalidating = false;
      notifyListeners();
      return;
    }
    notifyListeners();
    try {
      final result = await repository.activity(
        _path,
        cursor: reset ? null : cursor,
      );
      if (_disposed ||
          request != _request ||
          actor != repository.auth.user?['id']) {
        return;
      }
      final previous = reset ? <PostActivityItem>[] : items;
      final seen = previous.map((item) => item.id).toSet();
      items = [
        ...previous,
        ...(result['items'] as List)
            .map(
              (item) => PostActivityItem.fromApi(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .where((item) => seen.add(item.id)),
      ];
      cursor = result['nextCursor'] as String?;
    } catch (_) {
      if (!_disposed && request == _request) {
        if (reset) items = [];
        error = 'Không tải được danh sách. Thử lại';
      }
    } finally {
      if (!_disposed && request == _request) {
        loading = revalidating = false;
        notifyListeners();
      }
    }
  }

  /// Individual ACKs remove only successful items; failures stay selectable.
  Future<Map<String, String>> remove(Set<String> ids) async {
    if (removing || _disposed) {
      return {for (final id in ids) id: 'Đang cập nhật'};
    }
    final actor = repository.auth.user?['id'];
    final selected = items.where((item) => ids.contains(item.id)).toList();
    final failures = <String, String>{};
    final changedPosts = <int>{};
    removing = true;
    notifyListeners();
    try {
      for (final item in selected) {
        if (_disposed ||
            actor == null ||
            actor != repository.auth.user?['id']) {
          break;
        }
        try {
          if (kind == PostActivityKind.comments) {
            await ApiPostInteractionRepository(
              auth: repository.auth,
            ).deleteComment(
              item.id,
              postId: '${item.postId}',
              parentId: item.parentCommentId?.toString(),
            );
            changedPosts.add(item.postId);
          } else {
            await repository.engagement(
              item.postId,
              kind == PostActivityKind.likes ? 'like' : 'save',
              false,
            );
          }
        } catch (_) {
          if (actor == repository.auth.user?['id']) {
            failures[item.id] = 'Chưa cập nhật được. Thử lại';
          }
        }
      }
      if (!_disposed && actor == repository.auth.user?['id']) {
        for (final id in changedPosts) {
          PostChanges.changed(id: id);
        }
      }
    } finally {
      if (!_disposed) {
        removing = false;
        await refresh();
      }
    }
    return failures;
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    unawaited(_changes.cancel());
    repository.auth.removeListener(_session);
    PostChanges.revision.removeListener(_changed);
    ContentAccessChanges.revision.removeListener(_changed);
    super.dispose();
  }
}
