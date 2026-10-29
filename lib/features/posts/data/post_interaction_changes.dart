import 'dart:async';
import '../../../core/services/auth_service.dart';

/// Transient mutation ACKs, not a cache of Posts, permissions or private bytes.
class PostInteractionChange {
  final AuthService auth;
  final Object? actor;
  final int postId;
  final String kind;
  final Map<String, dynamic>? engagement;
  final int? commentId;
  final int? parentCommentId;
  final bool removed;
  const PostInteractionChange({
    required this.auth,
    required this.actor,
    required this.postId,
    required this.kind,
    this.engagement,
    this.commentId,
    this.parentCommentId,
    this.removed = false,
  });
  bool belongsTo(AuthService value) =>
      identical(auth, value) && actor != null && actor == value.user?['id'];
}

class PostInteractionChanges {
  static final _events = StreamController<PostInteractionChange>.broadcast(
    sync: true,
  );
  static Stream<PostInteractionChange> get stream => _events.stream;
  static void acknowledged(PostInteractionChange change) {
    if (change.belongsTo(change.auth)) _events.add(change);
  }
}
