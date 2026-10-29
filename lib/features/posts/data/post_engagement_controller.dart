import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_exception.dart';
import 'post_repository.dart';
import 'post_interaction_changes.dart';

/// A single mounted card owns optimistic state, never a global permission cache.
class PostEngagementController extends ChangeNotifier {
  final PostRepository repository;
  final int id;
  final VoidCallback? onUnavailable;
  final ValueChanged<Map<String, dynamic>>? onAcknowledged;
  final Object? _actor;
  bool liked = false, saved = false, liking = false, saving = false;
  int likeCount = 0;
  String? error;
  bool _disposed = false;
  late final StreamSubscription<PostInteractionChange> _changes;
  PostEngagementController(
    this.repository,
    this.id,
    Map<String, dynamic> data, {
    this.onUnavailable,
    this.onAcknowledged,
  }) : _actor = repository.auth.user?['id'] {
    update(data);
    repository.auth.addListener(_session);
    _changes = PostInteractionChanges.stream.listen((change) {
      if (!_disposed &&
          change.belongsTo(repository.auth) &&
          change.postId == id &&
          change.engagement != null) {
        update(change.engagement!);
        notifyListeners();
      }
    });
  }
  void _session() {
    if (_actor != repository.auth.user?['id']) {
      liked = saved = false;
      likeCount = 0;
      notifyListeners();
    }
  }

  void update(Map<String, dynamic> data) {
    if (!liking) {
      liked = data['likedByMe'] == true;
      likeCount = (data['likeCount'] as num?)?.toInt() ?? 0;
    }
    if (!saving) saved = data['savedByMe'] == true;
  }

  Future<bool> like(bool value) => _set(true, value);
  Future<bool> save(bool value) => _set(false, value);
  Future<bool> _set(bool isLike, bool value) async {
    if (_disposed ||
        _actor == null ||
        _actor != repository.auth.user?['id'] ||
        (isLike ? liking : saving)) {
      return false;
    }
    if (isLike ? liked == value : saved == value) return true;
    final previous = isLike ? liked : saved;
    final count = likeCount;
    error = null;
    if (isLike) {
      liking = true;
      liked = value;
      likeCount += value ? 1 : -1;
    } else {
      saving = true;
      saved = value;
    }
    notifyListeners();
    try {
      final data = await repository.engagement(
        id,
        isLike ? 'like' : 'save',
        value,
      );
      if (_disposed || _actor != repository.auth.user?['id']) return false;
      if (isLike) {
        liked = data['likedByMe'] == true;
        likeCount = (data['likeCount'] as num).toInt();
        if (!saving) saved = data['savedByMe'] == true;
      } else {
        saved = data['savedByMe'] == true;
        if (!liking) {
          liked = data['likedByMe'] == true;
          likeCount = (data['likeCount'] as num).toInt();
        }
      }
      onAcknowledged?.call(data);
      return true;
    } catch (e) {
      if (!_disposed && _actor == repository.auth.user?['id']) {
        if (isLike) {
          liked = previous;
          likeCount = count;
        } else {
          saved = previous;
        }
        error = 'Không cập nhật được tương tác. Vui lòng thử lại.';
        if (e is ApiException && (e.status == 404 || e.status == 403)) {
          onUnavailable?.call();
        }
      }
      return false;
    } finally {
      if (!_disposed) {
        if (isLike) {
          liking = false;
        } else {
          saving = false;
        }
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_changes.cancel());
    repository.auth.removeListener(_session);
    super.dispose();
  }
}
