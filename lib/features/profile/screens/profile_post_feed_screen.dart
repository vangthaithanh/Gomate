import 'dart:async';
import '../../../core/services/content_access_changes.dart';
import 'package:flutter/material.dart';
import '../../posts/data/post_engagement_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../../home/data/post_interaction_repository.dart';
import '../../home/widgets/comment_sheet_content.dart';
import '../../home/widgets/share_post_content.dart';
import '../../home/widgets/post_action_content.dart';
import '../../home/widgets/report_reason_content.dart';
import '../ui_preview/profile_ui_preview.dart';
import '../../search/screens/search_screen.dart';
import '../../search/models/search_models.dart';
import '../widgets/profile_ui_widgets.dart';
import 'public_profile_screen.dart';
import '../../../core/widgets/gomate_main_tab_header.dart';
import '../../posts/ui_preview/post_ui_demo_store.dart';
import '../../posts/widgets/post_audience_content.dart';
import '../../posts/widgets/post_menu_actions.dart';
import '../../posts/widgets/post_likers_content.dart';
import '../../posts/widgets/post_media_widget.dart';
import '../../posts/widgets/protected_post_media.dart';
import '../../posts/data/post_repository.dart';
import '../../posts/data/comment_repository.dart';
import '../../posts/data/post_share_repository.dart';
import '../../search/data/search_repository.dart';
import '../../posts/data/profile_posts_controller.dart';

/// Shared GoMate viewer for real Posts and isolated legacy UI previews.
class GoMateProfilePostFeedScreen extends StatefulWidget {
  final List<GoMateProfilePostPreview> posts;
  final int initialIndex;
  final bool remote;
  final int? postId;
  final PostRepository? repository;
  final bool showCommentsOnOpen;
  final bool sharedReference;
  final bool commentUnavailable;
  final String unavailableBackLabel;
  const GoMateProfilePostFeedScreen({
    super.key,
    required this.posts,
    this.initialIndex = 0,
    this.remote = false,
    this.postId,
    this.repository,
    this.showCommentsOnOpen = false,
    this.sharedReference = false,
    this.commentUnavailable = false,
    this.unavailableBackLabel = 'Quay lại tin nhắn',
  });

  @override
  State<GoMateProfilePostFeedScreen> createState() =>
      _GoMateProfilePostFeedScreenState();
}

class _GoMateProfilePostFeedScreenState
    extends State<GoMateProfilePostFeedScreen>
    with WidgetsBindingObserver {
  final PostInteractionRepository _interactions =
      DemoPostInteractionRepository();
  final Set<String> _hidden = <String>{};
  late final _repo = widget.repository ?? PostRepository();
  late final _postMenu = PostMenuActions(_repo);
  int _revision = 0;
  String? _actor;
  bool? _privacy;
  bool _openedComments = false;
  bool _openedUnavailableNotice = false;
  @override
  void initState() {
    super.initState();
    _actor = _repo.auth.user?['id']?.toString();
    _privacy = _repo.auth.user?['isPrivate'] as bool?;
    if (widget.remote) {
      WidgetsBinding.instance.addObserver(this);
      _repo.auth.addListener(_authChanged);
      PostChanges.revision.addListener(_invalidate);
    }
  }

  void _authChanged() {
    if (_actor != _repo.auth.user?['id']?.toString() ||
        _privacy != _repo.auth.user?['isPrivate']) {
      _privacy = _repo.auth.user?['isPrivate'] as bool?;
      _invalidate();
    }
  }

  void _invalidate() {
    if (!mounted) return;
    if (_actor != _repo.auth.user?['id']?.toString()) {
      setState(() {
        _hidden.addAll(widget.posts.map((p) => p.id));
        _revision++;
      });
    } else {
      setState(() => _revision++);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _invalidate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repo.auth.removeListener(_authChanged);
    PostChanges.revision.removeListener(_invalidate);
    super.dispose();
  }

  void _unavailable() =>
      GoMateSnackBar.show(context, message: 'Chức năng này chưa khả dụng.');

  /// Selected post first. Remaining posts retain their original grid order.
  /// E.g. [1,2,3,4] -> tap #2 => [2,1,3,4], tap #4 => [4,1,2,3].
  List<GoMateProfilePostPreview> get _ordered {
    if (widget.posts.isEmpty) return const [];
    final index = widget.initialIndex.clamp(0, widget.posts.length - 1).toInt();
    return <GoMateProfilePostPreview>[
      widget.posts[index],
      for (int i = 0; i < widget.posts.length; i++)
        if (i != index) widget.posts[i],
    ].where((post) => !_hidden.contains(post.id)).toList(growable: false);
  }

  Future<void> _comments(GoMateProfilePostPreview post) async {
    if (widget.remote) {
      bool changed = false;
      await GoMateBottomSheet.show<void>(
        context: context,
        size: GoMateBottomSheetSize.expanded,
        contentPadding: EdgeInsets.zero,
        child: CommentSheetContent(
          postId: post.id,
          repository: ApiPostInteractionRepository(auth: _repo.auth),
          initialNotice: widget.commentUnavailable && !_openedUnavailableNotice
              ? 'Bình luận không còn khả dụng'
              : null,
          onChanged: () => changed = true,
        ),
      );
      _openedUnavailableNotice = true;
      if (mounted && changed) {
        PostChanges.changed(id: int.parse(post.id));
      }
      return;
    }
    await GoMateBottomSheet.show<void>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      contentPadding: EdgeInsets.zero,
      child: CommentSheetContent(postId: post.id, repository: _interactions),
    );
  }

  Future<void> _share(GoMateProfilePostPreview post) async {
    final sent = await GoMateBottomSheet.show<int>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      contentPadding: EdgeInsets.zero,
      child: SharePostContent(
        postId: post.id,
        repository: widget.remote
            ? PostShareRepository(auth: _repo.auth, postId: post.id)
            : _interactions,
      ),
    );
    if (!mounted || sent == null || sent <= 0) return;
    GoMateSnackBar.show(context, message: 'Đã gửi bài viết cho $sent người');
  }

  Future<void> _more(GoMateProfilePostPreview post) async {
    if (widget.remote) {
      await _postMenu.open(
        context,
        int.parse(post.id),
        onDeleted: () => setState(() => _hidden.add(post.id)),
        onUnavailable: _invalidate,
      );
      return;
    }
    final me = widget.remote ? _repo.auth.user : AuthService.instance.user;
    final myId = (me?['userId'] ?? me?['id'])?.toString() ?? '';
    final owned =
        post.authorId.isNotEmpty &&
        (post.authorId == myId ||
            (!widget.remote && post.authorId == ProfileUiPreview.selfId));
    if (owned) {
      await _ownPostActions(post);
      return;
    }
    final choice = await GoMateBottomSheet.show<PostActionResult>(
      context: context,
      child: const PostActionContent(),
    );
    if (!mounted || choice == null) return;
    if (widget.remote) {
      _unavailable();
      return;
    }
    if (choice == PostActionResult.notInterested) {
      setState(() => _hidden.add(post.id));
      GoMateSnackBar.showUndo(
        context,
        message: 'Đã ẩn bài viết đối với bạn',
        onUndo: () {
          if (mounted) setState(() => _hidden.remove(post.id));
        },
      );
    } else {
      final reason = await GoMateBottomSheet.show<ReportReason>(
        context: context,
        size: GoMateBottomSheetSize.expanded,
        child: const ReportReasonContent(),
      );
      if (mounted && reason != null) {
        // Same UI-only report flow as Home; no report API in master.
        GoMateSnackBar.show(context, message: 'Cảm ơn bạn đã đóng góp ý kiến');
      }
    }
  }

  void _openHashtag(String hashtag) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchScreen(
          repository: SearchRepository(auth: _repo.auth),
          initialQuery: hashtag,
          initialTab: SearchTab.posts,
          initialHashtags: <String>{hashtag},
          startSubmitted: true,
          cancelReturnsToPrevious: true,
        ),
      ),
    );
  }

  Future<void> _ownPostActions(GoMateProfilePostPreview post) async {
    final store = GoMatePostUiDemoStore.instance;
    final owned = store.find(post.id);
    final mockPreview = store.isPreviewPost(post.id);
    final user = AuthService.instance.user;
    final isPrivate = user?['isPrivate'] == true;
    final pinned = store.isPinned(post.id);
    final result = await _chooseOwnAction(pinned);
    if (!mounted || result == null) return;
    if (owned == null && !mockPreview) {
      // Real posts must not be edited through the UI sample store.
      GoMateSnackBar.show(
        context,
        message: 'Bài viết thật cần API quản lý trước khi chỉnh sửa.',
      );
      return;
    }
    if (result == 'pin') {
      final wasPinned = store.isPinned(post.id);
      final success = owned != null
          ? store.togglePin(post.id)
          : store.togglePreviewPin(post.id);
      if (!mounted) return;
      if (!success) {
        GoMateSnackBar.show(
          context,
          message: 'Chỉ được ghim tối đa 3 bài viết. Bỏ ghim bài cũ trước.',
        );
        return;
      }
      GoMateSnackBar.show(
        context,
        message: wasPinned
            ? 'Đã bỏ ghim bài viết (demo)'
            : 'Đã ghim bài viết (demo)',
      );
    } else if (result == 'audience') {
      final audience = await GoMateBottomSheet.show<GoMatePostAudience>(
        context: context,
        child: GoMatePostAudienceContent(
          initial: owned?.audience ?? store.previewAudience(post.id),
          isPrivate: isPrivate,
        ),
      );
      if (audience == null || !mounted) return;
      if (isPrivate && audience == GoMatePostAudience.everyone) return;
      if (owned != null) {
        store.changeAudience(post.id, audience);
      } else {
        store.changePreviewAudience(post.id, audience);
      }
      GoMateSnackBar.show(context, message: 'Đã đổi quyền riêng tư (demo)');
    } else if (result == 'delete') {
      final confirm = await _confirmDelete(false);
      if (!mounted || confirm != true) return;
      if (owned != null) {
        store.remove(post.id);
      } else {
        store.removePreview(post.id);
      }
      setState(() => _hidden.add(post.id));
      GoMateSnackBar.show(context, message: 'Đã xoá bài viết (demo)');
    }
  }

  Future<String?> _chooseOwnAction(bool pinned) =>
      PostMenuActions.chooseOwnAction(context, pinned);

  Future<bool?> _confirmDelete(bool real) =>
      PostMenuActions.confirmDelete(context, real);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          GoMateMainTabHeader(
            title: 'Bài viết',
            titleSizeOverride: 16,
            leadingIcon: LucideIcons.chevron_left,
            onLeadingTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: widget.postId != null ? 1 : _ordered.length,
              itemBuilder: (context, index) {
                if (widget.remote) {
                  final id = widget.postId?.toString() ?? _ordered[index].id;
                  if (_hidden.contains(id) ||
                      _actor != _repo.auth.user?['id']?.toString()) {
                    return const SizedBox.shrink();
                  }
                  return _RemotePostTile(
                    unavailableBackLabel: widget.unavailableBackLabel,
                    sharedReference: widget.sharedReference,
                    key: ValueKey('$id:$_revision'),
                    id: int.parse(id),
                    repository: _repo,
                    tile: (post) {
                      if (widget.showCommentsOnOpen && !_openedComments) {
                        _openedComments = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted &&
                              _actor == _repo.auth.user?['id']?.toString()) {
                            unawaited(_comments(post));
                          }
                        });
                      }
                      return _PostFeedTile(
                        post: post,
                        onComments: () => _comments(post),
                        onShare: () => _share(post),
                        onMore: () => _more(post),
                        onHashtag: _openHashtag,
                        auth: _repo.auth,
                      );
                    },
                  );
                }
                final post = _ordered[index];
                return _PostFeedTile(
                  key: ValueKey(post.id),
                  post: post,
                  onComments: () => _comments(post),
                  onShare: () => _share(post),
                  onMore: () => _more(post),
                  onHashtag: _openHashtag,
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _PostFeedTile extends StatefulWidget {
  final GoMateProfilePostPreview post;
  final VoidCallback onComments;
  final VoidCallback onShare;
  final VoidCallback onMore;
  final ValueChanged<String> onHashtag;
  final AuthService? auth;
  const _PostFeedTile({
    super.key,
    required this.post,
    required this.onComments,
    required this.onShare,
    required this.onMore,
    required this.onHashtag,
    this.auth,
  });

  @override
  State<_PostFeedTile> createState() => _PostFeedTileState();
}

class _PostFeedTileState extends State<_PostFeedTile> {
  int _page = 0;
  bool _liked = false;
  bool _saved = false;
  bool _likeBurst = false;
  bool _revoked = false;
  PostEngagementController? _engagement;

  @override
  void initState() {
    super.initState();
    if (widget.post.server != null) {
      _engagement = PostEngagementController(
        PostRepository(auth: widget.auth),
        int.parse(widget.post.id),
        widget.post.server!,
        onUnavailable: () {
          if (mounted) setState(() => _revoked = true);
        },
      );
      _engagement!.addListener(_syncEngagement);
      _syncEngagement();
    }
  }

  void _syncEngagement() {
    if (mounted && _engagement != null) {
      setState(() {
        _liked = _engagement!.liked;
        _saved = _engagement!.saved;
      });
    }
  }

  @override
  void didUpdateWidget(covariant _PostFeedTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.server != null &&
        !identical(oldWidget.post.server, widget.post.server)) {
      _engagement?.update(widget.post.server!);
      _syncEngagement();
    }
  }

  @override
  void dispose() {
    _engagement?.removeListener(_syncEngagement);
    _engagement?.dispose();
    super.dispose();
  }

  Future<void> _remoteLike(bool value) async {
    final ok = await _engagement!.like(value);
    if (!ok && mounted && _engagement!.error != null) {
      GoMateSnackBar.show(context, message: _engagement!.error!);
    }
  }

  Future<void> _remoteSave() async {
    if (_engagement!.saving) return;
    final value = !_saved;
    final ok = await _engagement!.save(value);
    if (!mounted) return;
    if (ok) {
      GoMateSnackBar.show(
        context,
        message: value ? 'Đã lưu vào bộ sưu tập' : 'Đã gỡ khỏi bộ sưu tập',
      );
    } else if (_engagement!.error != null)
      GoMateSnackBar.show(context, message: _engagement!.error!);
  }

  void _openProfile() {
    final id = widget.post.authorId;
    final current = AuthService.instance.user;
    final myId = (current?['userId'] ?? current?['id'])?.toString() ?? '';
    if (id.isEmpty || id == myId || id == ProfileUiPreview.selfId) return;
    final person = ProfileUiPreview.enabled
        ? ProfileUiPreview.findPerson(id)
        : null;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(userId: id, previewPerson: person),
      ),
    );
  }

  void _toggleLike() {
    if (_engagement != null) {
      unawaited(_remoteLike(!_liked));
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _liked = !_liked);
    // TODO(BACKEND-PROFILE-UI-PREVIEW): UI-only like until post API exists.
  }

  Future<void> _doubleLike() async {
    if (_engagement?.liking == true) return;
    if (_engagement != null && !_liked) unawaited(_remoteLike(true));
    HapticFeedback.selectionClick();
    setState(() {
      if (_engagement == null) _liked = true;
      _likeBurst = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) setState(() => _likeBurst = false);
  }

  void _toggleSave() {
    if (_engagement != null) {
      unawaited(_remoteSave());
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _saved = !_saved);
    GoMateSnackBar.show(
      context,
      message: _saved ? 'Đã lưu vào bộ sưu tập' : 'Đã gỡ khỏi bộ sưu tập',
    );
    // TODO(BACKEND-PROFILE-UI-PREVIEW): local only, not server saved posts.
  }

  @override
  Widget build(BuildContext context) {
    if (_revoked) return const SizedBox.shrink();
    final w = MediaQuery.sizeOf(context).width;
    final post = widget.post;
    final hp = (w * 0.053).clamp(16.0, 22.0).toDouble();
    final avatarSize = (w * 0.105).clamp(38.0, 44.0).toDouble();
    final iconSize = (w * 0.05).clamp(18.0, 21.0).toDouble();
    final textSize = (13.5 * w / 360).clamp(12.5, 15.0).toDouble();
    final img = post.media.take(12).toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(bottom: w * 0.045),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hp),
            child: Row(
              children: [
                GoMateProfileAvatar(
                  size: avatarSize,
                  imageUrl: post.authorAvatar,
                  onTap: _openProfile,
                ),
                SizedBox(width: w * 0.025),
                Expanded(
                  child: InkWell(
                    onTap: _openProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: TextStyle(
                            fontSize: textSize,
                            fontWeight: FontWeight.w700,
                            color: AppColors.black,
                          ),
                        ),
                        if (post.location?.isNotEmpty == true)
                          Text(
                            post.location!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.grayText,
                              fontSize: (w * 0.032)
                                  .clamp(11.0, 13.0)
                                  .toDouble(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.onMore,
                  icon: Icon(
                    LucideIcons.ellipsis_vertical,
                    size: iconSize,
                    color: AppColors.black,
                  ),
                ),
              ],
            ),
          ),
          if (post.caption.isNotEmpty) ...[
            SizedBox(height: w * 0.018),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: hp),
              child: Wrap(
                spacing: 4,
                runSpacing: 3,
                children: [
                  for (final word in post.caption.split(RegExp(r'\s+')))
                    if (word.isNotEmpty)
                      word.startsWith('#')
                          ? InkWell(
                              onTap: () => widget.onHashtag(word),
                              child: Text(
                                word,
                                style: TextStyle(
                                  fontSize: textSize,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryText,
                                ),
                              ),
                            )
                          : Text(
                              word,
                              style: TextStyle(
                                fontSize: textSize,
                                color: AppColors.black,
                              ),
                            ),
                ],
              ),
            ),
            SizedBox(height: w * 0.025),
          ],
          GestureDetector(
            onDoubleTap: _doubleLike,
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: img.length,
                    onPageChanged: (index) => setState(() => _page = index),
                    itemBuilder: (_, index) => post.server != null
                        ? ProtectedPostMedia(
                            path: img[index],
                            posterPath:
                                (post.server!['media']
                                        as List)[index]['kind'] ==
                                    'VIDEO'
                                ? (post.server!['media']
                                          as List)[index]['thumbnailUrl']
                                      as String?
                                : null,
                            auth: widget.auth,
                            active:
                                index == _page &&
                                ModalRoute.of(context)?.isCurrent == true,
                            video:
                                (post.server!['media']
                                    as List)[index]['kind'] ==
                                'VIDEO',
                          )
                        : GoMatePostMediaWidget(
                            source: img[index],
                            trimRange: GoMatePostUiDemoStore.instance
                                .find(post.id)
                                ?.videoSegments[img[index]],
                          ),
                  ),
                  IgnorePointer(
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 130),
                        opacity: _likeBurst ? 1 : 0,
                        child: Icon(
                          Icons.favorite_rounded,
                          color: AppColors.primaryIcon,
                          size: w * 0.22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (img.length > 1) ...[
            SizedBox(height: w * 0.02),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                img.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: index == _page ? 6 : 4,
                  height: index == _page ? 6 : 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _page
                        ? AppColors.primaryIcon
                        : AppColors.grayBorder,
                  ),
                ),
              ),
            ),
          ],
          SizedBox(height: w * 0.019),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hp),
            child: Row(
              children: [
                _PostAction(
                  icon: _liked ? Icons.favorite_rounded : LucideIcons.heart,
                  label:
                      '${_engagement?.likeCount ?? (post.likeCount + (_liked ? 1 : 0))}',
                  color: _liked ? AppColors.primaryIcon : AppColors.black,
                  size: iconSize,
                  onTap: _toggleLike,
                  onLongPress: post.server == null
                      ? null
                      : () => showPostLikers(
                          context,
                          postId: int.parse(post.id),
                          repository: PostRepository(auth: widget.auth),
                        ),
                ),
                SizedBox(width: w * 0.046),
                _PostAction(
                  icon: LucideIcons.message_circle,
                  label: '${post.commentCount}',
                  size: iconSize,
                  onTap: widget.onComments,
                ),
                SizedBox(width: w * 0.042),
                InkWell(
                  onTap: widget.onShare,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(LucideIcons.send, size: iconSize),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _toggleSave,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      _saved ? Icons.bookmark_rounded : LucideIcons.bookmark,
                      size: iconSize,
                      color: _saved ? AppColors.primaryIcon : AppColors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _PostAction({
    required this.icon,
    required this.label,
    required this.size,
    required this.onTap,
    this.onLongPress,
    this.color = AppColors.black,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    onLongPress: onLongPress,
    borderRadius: BorderRadius.circular(16),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: size, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: size * 0.63, color: color),
        ),
      ],
    ),
  );
}

class _RemotePostTile extends StatefulWidget {
  final bool sharedReference;
  final String unavailableBackLabel;
  final int id;
  final PostRepository repository;
  final Widget Function(GoMateProfilePostPreview) tile;
  const _RemotePostTile({
    this.sharedReference = false,
    this.unavailableBackLabel = 'Quay lại tin nhắn',
    super.key,
    required this.id,
    required this.repository,
    required this.tile,
  });
  @override
  State<_RemotePostTile> createState() => _RemotePostTileState();
}

class _RemotePostTileState extends State<_RemotePostTile> {
  late Future<Map<String, dynamic>> _data = widget.repository.detail(widget.id);
  bool _checking = false;
  int _accessRequest = 0;
  @override
  void initState() {
    super.initState();
    ContentAccessChanges.revision.addListener(_recheck);
  }

  @override
  void dispose() {
    _accessRequest++;
    ContentAccessChanges.revision.removeListener(_recheck);
    super.dispose();
  }

  Future<void> _recheck() async {
    final revision = ++_accessRequest;
    setState(() => _checking = true);
    try {
      final post = await widget.repository.detail(widget.id);
      if (!mounted || revision != _accessRequest) return;
      setState(() {
        _data = Future.value(post);
        _checking = false;
      });
    } catch (e) {
      if (!mounted || revision != _accessRequest) return;
      setState(() {
        _data = Future.error(e);
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Visibility(
    visible: !_checking,
    maintainState: true,
    child: FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (widget.sharedReference) {
            final error = snapshot.error;
            final denied =
                error is ApiException &&
                (error.status == 403 || error.status == 404);
            return SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.65,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GoMateProfileEmpty(
                    icon: denied
                        ? LucideIcons.lock_keyhole
                        : LucideIcons.wifi_off,
                    title: denied
                        ? 'Bài viết không khả dụng'
                        : 'Chưa tải được bài viết',
                    description: denied
                        ? 'Bài viết đã được gỡ hoặc bạn không có quyền xem.'
                        : 'Vui lòng kiểm tra kết nối và thử lại.',
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryText,
                    ),
                    icon: Icon(
                      denied ? LucideIcons.arrow_left : LucideIcons.refresh_cw,
                      size: 18,
                    ),
                    label: Text(
                      denied ? widget.unavailableBackLabel : 'Thử lại',
                    ),
                    onPressed: denied
                        ? () => Navigator.of(context).pop()
                        : () => setState(
                            () => _data = widget.repository.detail(widget.id),
                          ),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              const GoMateProfileEmpty(
                icon: LucideIcons.images,
                title: 'Không thể xem bài viết',
                description:
                    'Bài viết không còn khả dụng hoặc bạn không có quyền xem.',
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _data = widget.repository.detail(widget.id)),
                child: const Text('Thử lại'),
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return widget.tile(profilePost(snapshot.data!));
      },
    ),
  );
}
