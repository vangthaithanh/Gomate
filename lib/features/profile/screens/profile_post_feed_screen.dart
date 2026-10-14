import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../../home/data/post_interaction_repository.dart';
import '../../home/widgets/comment_sheet_content.dart';
import '../../home/widgets/share_post_content.dart';
import '../../home/widgets/post_action_content.dart';
import '../../home/widgets/report_reason_content.dart';
import '../ui_preview/profile_ui_preview.dart';
import '../ui_preview/settings_ui_demo.dart';
import '../../search/screens/search_screen.dart';
import '../../search/models/search_models.dart';
import '../widgets/profile_ui_widgets.dart';
import 'public_profile_screen.dart';
import '../../../core/widgets/gomate_main_tab_header.dart';
import '../../posts/ui_preview/post_ui_demo_store.dart';
import '../../posts/widgets/post_audience_content.dart';
import '../../posts/widgets/post_media_widget.dart';
/// UI projection of posts supplied by Profile/Search/Place Detail.
/// TODO(BACKEND-PROFILE-UI-PREVIEW): inject the real post repository when available.
class GoMateProfilePostFeedScreen extends StatefulWidget {
  final List<GoMateProfilePostPreview> posts;
  final int initialIndex;
  const GoMateProfilePostFeedScreen({
    super.key,
    required this.posts,
    this.initialIndex = 0,
  });

  @override
  State<GoMateProfilePostFeedScreen> createState() =>
      _GoMateProfilePostFeedScreenState();
}

class _GoMateProfilePostFeedScreenState
    extends State<GoMateProfilePostFeedScreen> {
  final PostInteractionRepository _interactions = DemoPostInteractionRepository();
  final Set<String> _hidden = <String>{};

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
      child: SharePostContent(postId: post.id, repository: _interactions),
    );
    if (!mounted || sent == null || sent <= 0) return;
    GoMateSnackBar.show(context, message: 'Đã gửi bài viết cho $sent người');
  }

  Future<void> _more(GoMateProfilePostPreview post) async {
    final me = AuthService.instance.user;
    final myId = (me?['userId'] ?? me?['id'])?.toString() ?? '';
    final owned = post.authorId.isNotEmpty &&
        (post.authorId == myId || post.authorId == ProfileUiPreview.selfId);
    if (owned) {
      await _ownPostActions(post);
      return;
    }
    final choice = await GoMateBottomSheet.show<PostActionResult>(
      context: context, child: const PostActionContent());
    if (!mounted || choice == null) return;
    if (choice == PostActionResult.notInterested) {
      setState(() => _hidden.add(post.id));
      GoMateSnackBar.showUndo(context,
        message: 'Đã ẩn bài viết đối với bạn',
        onUndo: () { if (mounted) setState(() => _hidden.remove(post.id)); });
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
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SearchScreen(
        initialQuery: hashtag,
        initialTab: SearchTab.posts,
        initialHashtags: <String>{hashtag},
        startSubmitted: true,
        cancelReturnsToPrevious: true,
      ),
    ));
  }

  Future<void> _ownPostActions(GoMateProfilePostPreview post) async {
    final store = GoMatePostUiDemoStore.instance;
    final owned = store.find(post.id);
    final mockPreview = store.isPreviewPost(post.id);
    final user = AuthService.instance.user;
    final isPrivate = user?['isPrivate'] == true ||
        SettingsUiDemo.instance.privatePreview;
    final pinned = store.isPinned(post.id);
    final result = await GoMateBottomSheet.show<String>(
      context: context,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _ownAction(pinned ? LucideIcons.pin_off : LucideIcons.pin,
            pinned ? 'Bỏ ghim bài viết' : 'Ghim bài viết', 'pin'),
        const Divider(height: 1, color: AppColors.grayBorder),
        _ownAction(LucideIcons.earth, 'Chỉnh sửa quyền riêng tư', 'audience'),
        const Divider(height: 1, color: AppColors.grayBorder),
        _ownAction(LucideIcons.trash, 'Xoá', 'delete', danger: true),
      ]),
    );
    if (!mounted || result == null) return;
    if (owned == null && !mockPreview) {
      // Real posts must not be edited through the UI sample store.
      GoMateSnackBar.show(context,
        message: 'Bài viết thật cần API quản lý trước khi chỉnh sửa.');
      return;
    }
    if (result == 'pin') {
      final wasPinned = store.isPinned(post.id);
      final success = owned != null
          ? store.togglePin(post.id) : store.togglePreviewPin(post.id);
      if (!mounted) return;
      if (!success) {
        GoMateSnackBar.show(context,
          message: 'Chỉ được ghim tối đa 3 bài viết. Bỏ ghim bài cũ trước.');
        return;
      }
      GoMateSnackBar.show(context, message: wasPinned
          ? 'Đã bỏ ghim bài viết (demo)' : 'Đã ghim bài viết (demo)');
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
      final confirm = await GoMateBottomSheet.show<bool>(
        context: context,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Xoá bài viết?', style: TextStyle(
            color: AppColors.primaryText, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          const Text('Bài viết sẽ bị xoá khỏi bản xem thử.',
            style: TextStyle(fontSize: 13, color: AppColors.grayText)),
          const SizedBox(height: 15),
          TextButton(onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xác nhận xoá')),
          TextButton(onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huỷ')),
        ]),
      );
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

  Widget _ownAction(IconData icon, String title, String code,
      {bool danger = false}) => InkWell(
    onTap: () => Navigator.of(context).pop(code),
    child: SizedBox(height: 55, child: Row(children: [
      Icon(icon, size: 23, color: danger ? AppColors.primaryIcon : AppColors.black),
      const SizedBox(width: 15),
      Text(title, style: TextStyle(fontWeight: FontWeight.w600,
        color: danger ? AppColors.primaryIcon : AppColors.black, fontSize: 14)),
    ])),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(children: [
        GoMateMainTabHeader(
          title: 'Bài viết',
          titleSizeOverride: 16,
          leadingIcon: LucideIcons.chevron_left,
          onLeadingTap: () => Navigator.of(context).maybePop(),
        ),
        Expanded(child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: _ordered.length,
          itemBuilder: (context, index) {
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
        )),
      ]),
    ),
  );
}

class _PostFeedTile extends StatefulWidget {
  final GoMateProfilePostPreview post;
  final VoidCallback onComments;
  final VoidCallback onShare;
  final VoidCallback onMore;
  final ValueChanged<String> onHashtag;
  const _PostFeedTile({
    super.key, required this.post,
    required this.onComments, required this.onShare, required this.onMore,
    required this.onHashtag,
  });

  @override
  State<_PostFeedTile> createState() => _PostFeedTileState();
}

class _PostFeedTileState extends State<_PostFeedTile> {
  int _page = 0;
  bool _liked = false;
  bool _saved = false;
  bool _likeBurst = false;

  void _openProfile() {
    final id = widget.post.authorId;
    final current = AuthService.instance.user;
    final myId = (current?['userId'] ?? current?['id'])?.toString() ?? '';
    if (id.isEmpty || id == myId || id == ProfileUiPreview.selfId) return;
    final person = ProfileUiPreview.enabled ? ProfileUiPreview.findPerson(id) : null;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PublicProfileScreen(userId: id, previewPerson: person),
    ));
  }

  void _toggleLike() {
    HapticFeedback.selectionClick();
    setState(() => _liked = !_liked);
    // TODO(BACKEND-PROFILE-UI-PREVIEW): UI-only like until post API exists.
  }

  Future<void> _doubleLike() async {
    HapticFeedback.selectionClick();
    setState(() { _liked = true; _likeBurst = true; });
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) setState(() => _likeBurst = false);
  }

  void _toggleSave() {
    HapticFeedback.selectionClick();
    setState(() => _saved = !_saved);
    GoMateSnackBar.show(context,
      message: _saved ? 'Đã lưu vào bộ sưu tập' : 'Đã gỡ khỏi bộ sưu tập');
    // TODO(BACKEND-PROFILE-UI-PREVIEW): local only, not server saved posts.
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final post = widget.post;
    final hp = (w * 0.053).clamp(16.0, 22.0).toDouble();
    final avatarSize = (w * 0.105).clamp(38.0, 44.0).toDouble();
    final iconSize = (w * 0.05).clamp(18.0, 21.0).toDouble();
    final textSize = (13.5 * w / 360).clamp(12.5, 15.0).toDouble();
    final img = post.media.take(12).toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(bottom: w * 0.045),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hp),
          child: Row(children: [
            GoMateProfileAvatar(size: avatarSize, imageUrl: post.authorAvatar,
              onTap: _openProfile),
            SizedBox(width: w * 0.025),
            Expanded(child: InkWell(onTap: _openProfile,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(post.authorName, style: TextStyle(
                  fontSize: textSize, fontWeight: FontWeight.w700,
                  color: AppColors.black)),
                if (post.location?.isNotEmpty == true)
                  Text(post.location!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.grayText,
                      fontSize: (w * 0.032).clamp(11.0, 13.0).toDouble())),
              ]))),
            IconButton(onPressed: widget.onMore,
              icon: Icon(LucideIcons.ellipsis_vertical, size: iconSize,
                color: AppColors.black)),
          ]),
        ),
        if (post.caption.isNotEmpty) ...[
          SizedBox(height: w * 0.018),
          Padding(padding: EdgeInsets.symmetric(horizontal: hp),
            child: Wrap(spacing: 4, runSpacing: 3,
              children: [
                for (final word in post.caption.split(RegExp(r'\s+')))
                  if (word.isNotEmpty)
                    word.startsWith('#')
                      ? InkWell(
                          onTap: () => widget.onHashtag(word),
                          child: Text(word, style: TextStyle(
                            fontSize: textSize,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText)))
                      : Text(word, style: TextStyle(
                          fontSize: textSize, color: AppColors.black)),
              ],
            ),
          ),
          SizedBox(height: w * 0.025),
        ],
        GestureDetector(
          onDoubleTap: _doubleLike,
          child: AspectRatio(aspectRatio: 1,
            child: Stack(fit: StackFit.expand, children: [
              PageView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: img.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (_, index) => GoMatePostMediaWidget(
                  source: img[index],
                  trimRange: GoMatePostUiDemoStore.instance
                      .find(post.id)?.videoSegments[img[index]],
                ),
              ),
              IgnorePointer(child: Center(child: AnimatedOpacity(
                duration: const Duration(milliseconds: 130),
                opacity: _likeBurst ? 1 : 0,
                child: Icon(Icons.favorite_rounded,
                  color: AppColors.primaryIcon, size: w * 0.22),
              ))),
            ])),
        ),
        if (img.length > 1) ...[
          SizedBox(height: w * 0.02),
          Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(img.length, (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: index == _page ? 6 : 4,
              height: index == _page ? 6 : 4,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: index == _page ? AppColors.primaryIcon : AppColors.grayBorder),
            ))),
        ],
        SizedBox(height: w * 0.019),
        Padding(padding: EdgeInsets.symmetric(horizontal: hp),
          child: Row(children: [
            _PostAction(icon: _liked ? Icons.favorite_rounded : LucideIcons.heart,
              label: '${post.likeCount + (_liked ? 1 : 0)}',
              color: _liked ? AppColors.primaryIcon : AppColors.black,
              size: iconSize, onTap: _toggleLike),
            SizedBox(width: w * 0.046),
            _PostAction(icon: LucideIcons.message_circle,
              label: '${post.commentCount}', size: iconSize,
              onTap: widget.onComments),
            SizedBox(width: w * 0.042),
            InkWell(onTap: widget.onShare,
              child: Padding(padding: const EdgeInsets.all(3),
                child: Icon(LucideIcons.send, size: iconSize))),
            const Spacer(),
            InkWell(onTap: _toggleSave,
              child: Padding(padding: const EdgeInsets.all(3),
                child: Icon(_saved ? Icons.bookmark_rounded : LucideIcons.bookmark,
                  size: iconSize,
                  color: _saved ? AppColors.primaryIcon : AppColors.black))),
          ])),
      ]),
    );
  }
}

class _PostAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onTap;
  const _PostAction({required this.icon, required this.label,
    required this.size, required this.onTap, this.color = AppColors.black});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(16),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: size, color: color), const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: size * 0.63, color: color)),
    ]),
  );
}
