import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/snackbar.dart';
import '../../messages/data/message_repository.dart';
import '../../messages/screens/chat_screen.dart';
import '../../search/data/search_repository.dart';
import '../../search/models/search_models.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final SearchRepository? repository;

  const PublicProfileScreen({super.key, required this.userId, this.repository});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late final SearchRepository _repository;
  SearchUserProfile? _profile;
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SearchRepository();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _repository.getUserProfile(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được hồ sơ người dùng.';
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null || _actionLoading) return;

    setState(() => _actionLoading = true);
    try {
      final shouldFollow =
          profile.relation == SearchUserRelation.none ||
          profile.relation == SearchUserRelation.followsYou;
      final next = shouldFollow
          ? await _repository.followUser(profile.userId)
          : await _repository.unfollowUser(profile.userId);
      if (!mounted) return;

      SearchUserProfile? refreshedProfile;
      try {
        refreshedProfile = await _repository.getUserProfile(profile.userId);
      } catch (_) {
        refreshedProfile = profile.copyWith(relation: next);
      }
      await AuthService.instance.loadProfile().catchError((_) {});

      if (!mounted) return;
      setState(() {
        _profile = refreshedProfile;
      });
      GoMateSnackBar.show(
        context,
        message: shouldFollow
            ? 'Đã theo dõi ${profile.displayName}'
            : 'Đã bỏ theo dõi',
      );
    } catch (_) {
      if (!mounted) return;
      GoMateSnackBar.show(
        context,
        message: 'Không thể cập nhật quan hệ lúc này.',
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _openMessage() {
    final profile = _profile;
    if (profile == null) return;

    final repository = RealDirectMessageRepository.instance;
    final conversationId = repository.openOrCreateDirectConversationWithPeer(
      contactId: profile.userId,
      name: profile.displayName,
      subtitle: profile.city ?? profile.bio,
      avatarUrl: profile.avatarUrl,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessageChatScreen(
          conversationId: conversationId,
          repository: repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.2))
            : _error != null
            ? _ProfileError(message: _error!, onRetry: _loadProfile)
            : _buildProfile(_profile!),
      ),
    );
  }

  Widget _buildProfile(SearchUserProfile profile) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      physics: const BouncingScrollPhysics(),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
            ),
            Expanded(
              child: Text(
                profile.nickname.isEmpty
                    ? profile.displayName
                    : '@${profile.nickname}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Avatar(url: profile.avatarUrl, size: 86),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _SocialStat(
                          value: profile.followersCount.toString(),
                          label: 'Theo dõi',
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _SocialStat(
                          value: profile.mutualFriendCount.toString(),
                          label: 'Bạn chung',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          profile.bio?.isNotEmpty == true ? profile.bio! : 'Người dùng GoMate',
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: AppColors.textPrimary,
          ),
        ),
        if (profile.city?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  profile.city!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: _actionLoading ? null : _toggleFollow,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    foregroundColor: Colors.white,
                    backgroundColor: _isFollowing(profile.relation)
                        ? AppColors.textSecondary
                        : AppColors.blue500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _actionLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _followLabel(profile.relation),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: _openMessage,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 17),
                  label: const Text(
                    'Nhắn tin',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                      color: AppColors.blue100.withOpacity(0.85),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Divider(height: 1, color: Color(0xFFE5EEF9)),
        const SizedBox(height: 32),
        const _EmptyProfileContent(),
      ],
    );
  }

  bool _isFollowing(SearchUserRelation relation) {
    return relation == SearchUserRelation.following ||
        relation == SearchUserRelation.friend;
  }

  String _followLabel(SearchUserRelation relation) {
    switch (relation) {
      case SearchUserRelation.friend:
        return 'Bạn bè';
      case SearchUserRelation.following:
        return 'Đang theo dõi';
      case SearchUserRelation.followsYou:
        return 'Theo dõi lại';
      case SearchUserRelation.none:
        return 'Theo dõi';
      case SearchUserRelation.pending:
        return 'Chấp nhận';
    }
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final double size;

  const _Avatar({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.blue100,
        border: Border.all(color: Colors.white, width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? const Icon(Icons.person_rounded, size: 42, color: AppColors.blue500)
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.person_rounded,
                size: 42,
                color: AppColors.blue500,
              ),
            ),
    );
  }
}

class _SocialStat extends StatelessWidget {
  final String value;
  final String label;

  const _SocialStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ProfileError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ProfileError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

class _EmptyProfileContent extends StatelessWidget {
  const _EmptyProfileContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.grid_view_rounded, size: 32, color: AppColors.blue300),
        SizedBox(height: 10),
        Text(
          'Chưa có nội dung công khai',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Bài viết và hoạt động công khai sẽ hiển thị tại đây.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
