import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../../messages/data/message_repository.dart';
import '../../messages/screens/chat_screen.dart';
import '../../messages/models/message_models.dart';
import '../../home/widgets/report_reason_content.dart';
import '../../moments/data/moments_repository.dart';
import '../../moments/screens/moment_viewer_screen.dart';
import '../../moments/widgets/moment_components.dart';
import '../../search/data/search_repository.dart';
import '../../search/models/search_models.dart';
import '../widgets/profile_ui_widgets.dart';
import '../ui_preview/profile_ui_preview.dart';
import 'profile_people_screen.dart';
import 'profile_post_feed_screen.dart';

/// Public user profile. Uses SearchRepository and the real direct message flow.
/// Master API does not expose `isPrivate`, `followRequestPending` or owned posts;
/// therefore those states must not be guessed from Follow relation.
class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final SearchRepository? repository;
  final List<GoMateProfilePostPreview> posts;
  /// Optional trusted privacy state; master API does not yet supply this.
  final bool? isPrivate;
  /// UI-only sample object. When non-null, NEVER read/mutate server data.
  final ProfilePreviewPerson? previewPerson;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.repository,
    this.posts = const [],
    this.isPrivate,
    this.previewPerson,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late final SearchRepository _repository;
  final ApiMomentsRepository _moments = ApiMomentsRepository.instance;
  SearchUserProfile? _profile;
  bool _loading = true;
  bool _acting = false;
  String? _error;
  // TODO(BACKEND-PROFILE-UI-PREVIEW): local-only states for demo people.
  bool _previewMuted = false;
  bool _previewBlocked = false;

  // UI-only: muteUser() updates the Moments list optimistically; the server
  // may subsequently remove the hidden friend from stripItems entirely.
  // Keep the menu showing 'Bỏ ẩn' during this screen session.
  // TODO(BACKEND-PROFILE-UI-PREVIEW): read mute state from a persistent source.
  bool _locallyMutedRealUser = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SearchRepository();
    _load();
  }

  @override
  void didUpdateWidget(covariant PublicProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId ||
        widget.previewPerson != oldWidget.previewPerson) {
      _previewMuted = false;
      _previewBlocked = false;
      _locallyMutedRealUser = false;
      _load();
    }
  }

  Future<void> _load() async {
    // TODO(BACKEND-PROFILE-UI-PREVIEW): isolate mock lookup from API.
    final preview = widget.previewPerson;
    if (ProfileUiPreview.enabled && preview != null &&
        widget.userId == preview.id) {
      setState(() {
        _profile = preview.asProfile();
        _loading = false;
        _error = null;
      });
      return;
    }
    // Never send known mock IDs to the real repository.
    if (ProfileUiPreview.isPreviewId(widget.userId)) {
      setState(() {
        _loading = false;
        _error = 'Hồ sơ mẫu chỉ mở được trong chế độ xem thử.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await _repository.getUserProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = value;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Không tải được hồ sơ người dùng.';
      });
    }
  }

  bool _following(SearchUserRelation relation) =>
      relation == SearchUserRelation.friend ||
      relation == SearchUserRelation.following;

  String _label(SearchUserRelation relation) {
    switch (relation) {
      case SearchUserRelation.friend:
      case SearchUserRelation.following:
        return 'Đang theo dõi';
      case SearchUserRelation.pending:
        return 'Chờ xác nhận';
      case SearchUserRelation.followsYou:
        return 'Theo dõi lại';
      case SearchUserRelation.none:
        return 'Theo dõi';
    }
  }

  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null || _acting) return;
    final shouldFollow = !_following(profile.relation) &&
        profile.relation != SearchUserRelation.pending;
    // Confirm ONLY when unfollowing an accepted PRIVATE account.
    if (!shouldFollow && _isPrivate && _following(profile.relation)) {
      final confirmed = await GoMateBottomSheet.show<bool>(
        context: context,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bỏ theo dõi?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 9),
            const Text(
              'Nếu bỏ theo dõi tài khoản riêng tư này, bạn sẽ cần chờ họ xác nhận khi theo dõi lại.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF828282), fontSize: 12),
            ),
            const SizedBox(height: 15),
            GoMateProfileGradientButton(
              label: 'Xác nhận bỏ theo dõi',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    if (!mounted) return;
    // Demo relation transitions: public -> following, private -> pending.
    // Pending -> none; accepted private -> confirmed unfollow -> none.
    // No fake user ID is ever sent to a repository.
    if (widget.previewPerson != null) {
      final next = shouldFollow
          ? (_isPrivate ? SearchUserRelation.pending
              : SearchUserRelation.following)
          : SearchUserRelation.none;
      setState(() => _profile = profile.copyWith(relation: next));
      GoMateSnackBar.show(context,
          message: next == SearchUserRelation.pending
              ? 'Đã gửi yêu cầu theo dõi (demo)'
              : shouldFollow ? 'Đã theo dõi (demo)' : 'Đã huỷ theo dõi (demo)');
      return;
    }
    setState(() => _acting = true);
    try {
      final result = shouldFollow
          ? await _repository.followUser(profile.userId)
          : await _repository.unfollowUser(profile.userId);
      SearchUserProfile updated;
      try {
        updated = await _repository.getUserProfile(profile.userId);
      } catch (_) {
        updated = profile.copyWith(relation: result);
      }
      await AuthService.instance.loadProfile().catchError((_) {});
      if (!mounted) return;
      setState(() => _profile = updated);
      GoMateSnackBar.show(context,
          message: shouldFollow ? 'Đã cập nhật theo dõi' : 'Đã bỏ theo dõi');
    } catch (_) {
      if (!mounted) return;
      GoMateSnackBar.show(context,
          message: 'Không thể cập nhật quan hệ lúc này.');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  bool get _muted {
    if (widget.previewPerson != null) return _previewMuted;
    if (_locallyMutedRealUser) return true;
    for (final item in _moments.stripItems) {
      if (item.userId == widget.userId && item.isMuted) return true;
    }
    return false;
  }

  // A mutual friendship is about THIS user's relationship with the profile
  // owner, NOT the total mutualFriendCount shown on the profile.
  bool get _isFriend => _profile?.relation == SearchUserRelation.friend;

  Future<void> _toggleMomentMute(SearchUserProfile profile) async {
    if (!_isFriend) return;

    // Use the same confirmation sheet as MomentViewerScreen when hiding.
    if (!_muted) {
      final confirmed = await GoMateBottomSheet.show<bool>(
        context: context,
        size: GoMateBottomSheetSize.compact,
        child: MomentConfirmContent(
          title: 'Tắt ảnh khoảnh khắc của ${profile.displayName}?',
          description: 'Bạn sẽ không thể xem ảnh khoảnh khắc do người này chia sẻ.',
          secondaryDescription:
              'Bạn có thể bật lại khoảnh khắc từ trang cá nhân của họ.',
        ),
      );
      if (!mounted || confirmed != true) return;

      if (widget.previewPerson != null) {
        setState(() => _previewMuted = true);
        GoMateSnackBar.show(context, message: 'Đã ẩn khoảnh khắc (demo)');
        return;
      }

      // Reuse the existing MomentsRepository method. Do not call AuthService
      // directly or change the real API contract in a UI-only update.
      _moments.muteUser(profile.userId);
      setState(() => _locallyMutedRealUser = true);
      GoMateSnackBar.show(
        context,
        message: 'Đã ẩn khoảnh khắc của ${profile.displayName}',
      );
      return;
    }

    if (widget.previewPerson != null) {
      setState(() => _previewMuted = false);
      GoMateSnackBar.show(context, message: 'Đã bỏ ẩn khoảnh khắc (demo)');
      return;
    }

    // Backend already supports DELETE /moment-mutes/{userId}, but the Flutter
    // MomentsRepository interface does not expose unmuteUser yet. Keep the
    // menu option visible and do NOT fake a successful unmute.
    // TODO(BACKEND-PROFILE-MOMENTS): connect this action via MomentsRepository.
    GoMateSnackBar.show(
      context,
      message: 'Bỏ ẩn khoảnh khắc cần được kết nối qua MomentsRepository.',
    );
  }

  MessageConversation? _existingDirectConversation() {
    if (widget.previewPerson != null) return null;
    final repository = RealDirectMessageRepository.instance;
    for (final conversation in <MessageConversation>[
      ...repository.mainConversations, ...repository.pendingConversations,
    ]) {
      if (conversation.isGroup) continue;
      if (conversation.participants.any((person) => person.id == widget.userId)) {
        return conversation;
      }
    }
    return null;
  }

  Future<void> _openMore() async {
    final profile = _profile;
    if (profile == null) return;
    final friend = _isFriend;
    final conversation = _existingDirectConversation();
    final blocked = widget.previewPerson != null
        ? _previewBlocked : conversation?.isBlocked == true;
    final choice = await GoMateBottomSheet.show<String>(
      context: context,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _menuItem(LucideIcons.message_square_warning, 'Báo cáo', 'report'),
        const Divider(height: 1, color: AppColors.grayBorder),
        _menuItem(LucideIcons.ban, blocked ? 'Bỏ chặn' : 'Chặn', 'block'),
        if (friend) ...[
          const Divider(height: 1, color: AppColors.grayBorder),
          _menuItem(
            _muted ? LucideIcons.eye : LucideIcons.eye_off,
            _muted ? 'Bỏ ẩn khoảnh khắc' : 'Ẩn khoảnh khắc',
            'moment',
          ),
        ],
      ]),
    );
    if (!mounted || choice == null) return;
    if (choice == 'report') {
      final reason = await GoMateBottomSheet.show<ReportReason>(
        context: context,
        size: GoMateBottomSheetSize.expanded,
        child: const ReportReasonContent(),
      );
      if (!mounted || reason == null) return;
      // Same UI-only report flow as Home/Message Detail. No report API in master.
      GoMateSnackBar.show(context, message: 'Cảm ơn bạn đã đóng góp ý kiến');
    } else if (choice == 'block') {
      if (blocked) {
        if (widget.previewPerson != null) {
          setState(() => _previewBlocked = false);
          GoMateSnackBar.show(context, message: 'Đã bỏ chặn (demo)');
        } else if (conversation != null) {
          RealDirectMessageRepository.instance.unblockConversation(conversation.id);
          GoMateSnackBar.show(context, message: 'Đang cập nhật trạng thái bỏ chặn');
        }
        return;
      }
      final confirmed = await GoMateBottomSheet.show<bool>(
        context: context,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Chặn ${profile.displayName}?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text('Bạn sẽ chặn tương tác với người dùng này. '
              'Bạn có thể bỏ chặn bất cứ lúc nào.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.grayText)),
          const SizedBox(height: 18),
          GoMateProfileGradientButton(label: 'Xác nhận',
              onPressed: () => Navigator.of(context).pop(true)),
        ]),
      );
      if (!mounted || confirmed != true) return;
      if (widget.previewPerson != null) {
        setState(() => _previewBlocked = true);
        GoMateSnackBar.show(context, message: 'Đã chặn (demo)');
      } else if (conversation != null) {
        RealDirectMessageRepository.instance.blockConversation(conversation.id);
        GoMateSnackBar.show(context, message: 'Đang cập nhật trạng thái chặn');
      } else {
        // TODO(BACKEND-PROFILE-UI-PREVIEW): block-by-user-id endpoint is missing.
        // Do NOT silently create a direct chat just to block a profile.
        GoMateSnackBar.show(context,
            message: 'Chưa thể chặn tài khoản chưa có đoạn chat.');
      }
    } else if (choice == 'moment' && friend) {
      await _toggleMomentMute(profile);
    }
  }

  Widget _menuItem(IconData icon, String title, String value) => InkWell(
    onTap: () => Navigator.of(context).pop(value),
    child: SizedBox(height: 56, child: Row(children: [
      Icon(icon, size: 23, color: AppColors.primaryText),
      const SizedBox(width: 15),
      Text(title, style: const TextStyle(fontSize: 15,
          fontWeight: FontWeight.w600, color: AppColors.primaryText)),
    ])),
  );

  Future<void> _showPrivatePeopleNotice() async {
    await GoMateBottomSheet.show<void>(context: context, child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.lock_keyhole, size: 36, color: AppColors.primaryIcon),
        const SizedBox(height: 12),
        const Text('Bạn cần theo dõi người này',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Tài khoản riêng tư. Bạn chỉ xem được người theo dõi và bạn bè '
            'sau khi yêu cầu theo dõi được chấp nhận.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grayText, fontSize: 13)),
        const SizedBox(height: 16),
        GoMateProfileGradientButton(label: 'Đã hiểu',
            onPressed: () => Navigator.of(context).pop()),
      ],
    ));
  }

  bool get _isPrivate =>
      widget.previewPerson?.isPrivate ?? widget.isPrivate == true;

  void _openMessage() {
    final profile = _profile;
    if (profile == null) return;
    if (widget.previewPerson != null) {
      GoMateSnackBar.show(context,
          message: 'Tin nhắn demo chưa gửi được. Hãy thử với tài khoản thật.');
      return;
    }
    final repository = RealDirectMessageRepository.instance;
    final conversationId = repository.openOrCreateDirectConversationWithPeer(
      contactId: profile.userId,
      name: profile.displayName,
      subtitle: profile.city ?? profile.bio,
      avatarUrl: profile.avatarUrl,
    );
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MessageChatScreen(
        conversationId: conversationId,
        repository: repository,
      ),
    ));
  }

  void _openMoment() {
    if (widget.previewPerson != null) return;
    final item = _moments.stripItems.where((m) => m.userId == widget.userId).toList();
    if (item.isEmpty || !item.first.hasAvailableMoment) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MomentViewerScreen(
        repository: _moments,
        startUserId: widget.userId,
      ),
    ));
  }

  void _openPeople(int tab) {
    final profile = _profile;
    if (profile == null) return;
    if (_isPrivate && !_following(profile.relation)) {
      _showPrivatePeopleNotice();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ProfilePeopleScreen(
        nickname: profile.nickname,
        initialTab: tab,
        followersCount: profile.followersCount,
        friendsCount: profile.mutualFriendCount,
        usePreviewPeople: widget.previewPerson != null,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primaryIcon))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: const TextStyle(color: Color(0xFF828282))),
                        TextButton(onPressed: _load, style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryText), child: const Text('Thử lại')),
                      ],
                    ),
                  )
                : _body(_profile!),
      ),
    );
  }

  Widget _body(SearchUserProfile profile) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = (width * 0.075).clamp(20.0, 30.0).toDouble();
    final actualPosts = widget.posts
        .where((post) => post.authorId == profile.userId)
        .toList(growable: false);
    final posts = actualPosts.isNotEmpty || widget.previewPerson == null
        ? actualPosts
        : ProfileUiPreview.posts(
            authorId: profile.userId, authorName: profile.displayName,
            authorAvatar: profile.avatarUrl);
    final moment = _moments.stripItems.any(
        (m) => m.userId == profile.userId && m.hasAvailableMoment);
    final locked = _isPrivate && !_following(profile.relation);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: GoMateProfilePageHeader(
            title: profile.nickname.isNotEmpty
                ? profile.nickname : profile.displayName,
            trailing: IconButton(
              tooltip: 'Tùy chọn trang cá nhân',
              onPressed: _openMore,
              icon: const Icon(LucideIcons.ellipsis_vertical,
                size: 23, color: AppColors.black),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            child: Column(
              children: [
                if (widget.previewPerson != null) ...[
                  const SizedBox(height: 3),
                  const Text('XEM THỬ GIAO DIỆN · DỮ LIỆU MẪU',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10,
                          color: AppColors.grayText)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    GoMateProfileAvatar(
                      size: 62,
                      imageUrl: profile.avatarUrl,
                      onTap: moment ? _openMoment : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.primaryText,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              )),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(child: GoMateProfileStat(
                                value: profile.followersCount,
                                label: 'Người theo dõi',
                                onTap: () => _openPeople(0),
                              )),
                              const SizedBox(width: 8),
                              Expanded(child: GoMateProfileStat(
                                value: profile.mutualFriendCount,
                                label: 'Bạn bè',
                                onTap: () => _openPeople(1),
                              )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!locked && profile.bio?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(profile.bio!,
                        style: const TextStyle(fontSize: 12, height: 1.4)),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _action(_label(profile.relation), _toggleFollow)),
                    if (!locked) ...[
                      const SizedBox(width: 12),
                      Expanded(child: _action('Nhắn tin', _openMessage)),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        if (locked)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 36),
              child: Column(
                children: [
                  Icon(LucideIcons.lock_keyhole, size: 65, color: Color(0xFF828282)),
                  SizedBox(height: 12),
                  Text('Đây là trang cá nhân riêng tư',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  SizedBox(height: 8),
                  Text('Theo dõi người dùng này để xem nội dung của họ',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF828282), fontSize: 12)),
                ],
              ),
            ),
          )
        else const SliverToBoxAdapter(
          child: SizedBox(
            height: 42,
            child: Center(child: Icon(LucideIcons.images, color: AppColors.primaryIcon, size: 23)),
          ),
        ),
        if (locked)
          const SliverToBoxAdapter(child: SizedBox.shrink())
        else if (posts.isEmpty)
          const SliverToBoxAdapter(
            child: GoMateProfileEmpty(
              icon: LucideIcons.images,
              title: 'Chưa có bài viết để hiển thị',
              description: 'Người dùng này chưa chia sẻ bài viết nào.',
            ),
          )
        else
          SliverGrid.builder(
            itemCount: posts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemBuilder: (context, index) {
              final post = posts[index];
              final source = post.media.isEmpty ? '' : post.media.first;
              return InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => GoMateProfilePostFeedScreen(
                    posts: posts,
                    initialIndex: index,
                  ),
                )),
                child: source.startsWith('http')
                    ? Image.network(source, fit: BoxFit.cover)
                    : source.isNotEmpty
                        ? Image.asset(source, fit: BoxFit.cover)
                        : const ColoredBox(color: Color(0xFFE8EDF6)),
              );
            },
          ),
      ],
    );
  }

  Widget _action(String title, VoidCallback onTap) {
    return InkWell(
      onTap: _acting ? null : onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        alignment: Alignment.center,
        constraints: const BoxConstraints(minHeight: 37),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
            BoxShadow(color: Color(0x16000000), blurRadius: 5, offset: Offset(0, 2)),
          ],
        ),
        child: _acting
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primaryIcon))
            : Text(title, style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText,
                fontSize: 12,
              )),
      ),
    );
  }
}
