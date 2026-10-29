import 'dart:async';
import '../../../core/services/content_access_changes.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/widgets/profile_ui_widgets.dart';
import 'post_repository.dart';
import 'post_interaction_changes.dart';

GoMateProfilePostPreview profilePost(Map<String, dynamic> post) =>
    GoMateProfilePostPreview(
      id: '${post['id']}',
      authorId: post['authorId'] as String,
      authorName: post['authorName'] as String? ?? '',
      authorAvatar: post['authorAvatar'] as String?,
      location: post['placeName'] as String?,
      caption: [
        post['caption'] as String,
        ...(post['hashtags'] as List).map((t) => '#$t'),
      ].where((s) => s.isNotEmpty).join('\n'),
      media: (post['media'] as List).map((m) => m['url'] as String).toList(),
      likeCount: (post['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (post['commentCount'] as num?)?.toInt() ?? 0,
      server: post,
    );

/// Mounted tiles may survive revalidation, but must stay hidden until its ACK.
class ProfilePostsController extends ChangeNotifier {
  final PostRepository repository;
  final String Function() author;
  List<GoMateProfilePostPreview> items = [];
  bool loading = false;
  bool revalidating = false;
  String? error;
  String? cursor;
  int _request = 0;
  bool _disposed = false;
  Object? _actor;
  String? _author;
  late final StreamSubscription<PostInteractionChange> _interactions;
  ProfilePostsController(this.author, {PostRepository? repository})
    : repository = repository ?? PostRepository() {
    this.repository.auth.addListener(refresh);
    PostChanges.revision.addListener(refresh);
    ContentAccessChanges.revision.addListener(refresh);
    _interactions = PostInteractionChanges.stream.listen((change) {
      if (_disposed ||
          !change.belongsTo(this.repository.auth) ||
          change.engagement == null) {
        return;
      }
      items = items
          .map(
            (post) => post.id == '${change.postId}' && post.server != null
                ? profilePost({
                    ...post.server!,
                    ...change.engagement!,
                    'id': change.postId,
                  })
                : post,
          )
          .toList();
      notifyListeners();
    });
  }
  Future<void> refresh() => load(reset: true);
  Future<void> load({bool reset = false}) async {
    if (_disposed || (!reset && (loading || cursor == null))) return;
    final user = repository.auth.user?['id'];
    final owner = author();
    final request = ++_request;
    if (reset) {
      if (user != _actor || owner != _author) items = [];
      cursor = null;
      revalidating = true;
    }
    _actor = user;
    _author = owner;
    error = null;
    if (owner.isEmpty || user == null) {
      items = [];
      loading = false;
      revalidating = false;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      final page = await repository.profile(
        owner,
        cursor: reset ? null : cursor,
      );
      if (_disposed ||
          request != _request ||
          user != repository.auth.user?['id'] ||
          owner != author()) {
        return;
      }
      final previous = reset ? <GoMateProfilePostPreview>[] : items;
      final seen = previous.map((p) => p.id).toSet();
      items = [
        ...previous,
        ...(page['items'] as List)
            .map((p) => profilePost(Map<String, dynamic>.from(p)))
            .where((p) => seen.add(p.id)),
      ];
      cursor = page['nextCursor'] as String?;
    } catch (_) {
      if (!_disposed && request == _request) {
        if (reset) items = [];
        error = 'Không tải được bài viết. Thử lại';
      }
    } finally {
      if (!_disposed && request == _request) {
        loading = false;
        revalidating = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_interactions.cancel());
    _request++;
    repository.auth.removeListener(refresh);
    PostChanges.revision.removeListener(refresh);
    ContentAccessChanges.revision.removeListener(refresh);
    super.dispose();
  }
}

class ProfilePostStatus extends StatelessWidget {
  final ProfilePostsController state;
  const ProfilePostStatus({super.key, required this.state});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: state.loading
          ? const CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryIcon,
            )
          : TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryText,
              ),
              onPressed: state.items.isEmpty
                  ? state.refresh
                  : () => state.load(),
              child: Text(state.error ?? 'Thử lại'),
            ),
    ),
  );
}
