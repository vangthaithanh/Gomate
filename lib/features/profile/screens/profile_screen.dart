import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/snackbar.dart';
import '../widgets/profile_account_sheets.dart';
import 'setting_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_refresh);
    AuthService.instance.loadProfile().catchError((_) {});
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Map<String, dynamic> get _user => AuthService.instance.user ?? const {};

  String get _nickname => _text(_user['nickname'], fallback: 'gomate');

  String get _displayName {
    final displayName = _text(_user['displayName']);
    if (displayName.isNotEmpty) return displayName;
    final fullName = _text(_user['fullName']);
    return fullName.isNotEmpty ? fullName : _nickname;
  }

  String get _bio {
    final bio = _text(_user['bio']);
    return bio.isEmpty ? 'Khám phá nhiều hơn, đi xa hơn cùng GoMate.' : bio;
  }

  String? get _avatarUrl {
    final value = _text(_user['avatarUrl']);
    return value.isEmpty ? null : value;
  }

  int get _followersCount => _stat('followersCount');

  int get _mutualFriendCount => _stat('mutualFriendCount');

  Future<void> _editProfile() async {
    final saved = await showProfileEditSheet(context, user: _user);
    if (!mounted || saved != true) return;
    GoMateSnackBar.show(context, message: 'Đã cập nhật hồ sơ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),

              const SizedBox(height: 18),

              _buildProfileHeader(),

              const SizedBox(height: 20),

              _buildContentTabs(),

              const SizedBox(height: 16),

              _buildTabContent(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // Tên đăng nhập ở giữa - giống bố cục profile social
  // ============================================================

  Widget _buildTopBar() {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          _topIconButton(
            icon: Icons.add_rounded,
            onTap: () {
              // UI only - sau này dùng cho tạo bài viết.
            },
          ),

          Expanded(
            child: Center(
              child: Text(
                _nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),

          _topIconButton(
            icon: Icons.menu_rounded,
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _topIconButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 25, color: AppColors.textPrimary),
      ),
    );
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  Widget _buildProfileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAvatar(),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Biệt danh / ID hiển thị
                  Text(
                    _displayName,
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
                          value: _followersCount.toString(),
                          label: 'Người theo dõi',
                        ),
                      ),

                      SizedBox(width: 18),

                      Expanded(
                        child: _SocialStat(
                          value: _mutualFriendCount.toString(),
                          label: 'Bạn bè',
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
          _bio,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 7),

        InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(10),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_rounded, size: 16, color: AppColors.blue500),
                SizedBox(width: 5),
                Text(
                  'Thêm liên kết',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blue500,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Đặt Edit Profile ngay dưới bio,
        // không chiếm quá nhiều sự chú ý.
        SizedBox(
          width: double.infinity,
          height: 42,
          child: OutlinedButton.icon(
            onPressed: () {
              _editProfile();
            },
            icon: const Icon(Icons.edit_outlined, size: 17),
            label: const Text(
              'Chỉnh sửa hồ sơ',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              backgroundColor: AppColors.blue50.withOpacity(0.30),
              side: BorderSide(color: AppColors.blue100.withOpacity(0.85)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.blue100,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: _avatarUrl == null
              ? const Icon(
                  Icons.person_rounded,
                  size: 42,
                  color: AppColors.blue500,
                )
              : ClipOval(
                  child: Image.network(
                    _avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.person_rounded,
                      size: 42,
                      color: AppColors.blue500,
                    ),
                  ),
                ),
        ),

        Positioned(
          right: 0,
          bottom: 1,
          child: InkWell(
            onTap: _editProfile,
            customBorder: const CircleBorder(),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.blue500,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 13,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CONTENT TABS
  // Chỉ dùng icon, hạn chế chữ làm UI rối
  // ============================================================

  Widget _buildContentTabs() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.blue100.withOpacity(0.55)),
          bottom: BorderSide(color: AppColors.blue100.withOpacity(0.55)),
        ),
      ),
      child: Row(
        children: [
          _iconTab(
            index: 0,
            icon: Icons.grid_view_rounded,
            tooltip: 'Bài viết',
          ),

          _iconTab(
            index: 1,
            icon: Icons.favorite_border_rounded,
            selectedIcon: Icons.favorite_rounded,
            tooltip: 'Yêu thích',
          ),
        ],
      ),
    );
  }

  Widget _iconTab({
    required int index,
    required IconData icon,
    IconData? selectedIcon,
    required String tooltip,
  }) {
    final selected = _selectedTab == index;

    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedTab = index;
            });
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                selected ? (selectedIcon ?? icon) : icon,
                size: 23,
                color: selected ? AppColors.blue500 : AppColors.textSecondary,
              ),

              if (selected)
                Positioned(
                  bottom: 0,
                  left: 28,
                  right: 28,
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: AppColors.blue500,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildPostsTab();

      case 1:
        return _buildFavoritesTab();

      default:
        return const SizedBox.shrink();
    }
  }

  // ============================================================
  // POSTS
  // ============================================================

  Widget _buildPostsTab() {
    return Column(
      children: [
        _buildCreatePostRow(),

        const SizedBox(height: 12),

        _buildSamplePost(),
      ],
    );
  }

  Widget _buildCreatePostRow() {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.blue100,
              ),
              child: _avatarUrl == null
                  ? const Icon(
                      Icons.person_rounded,
                      size: 22,
                      color: AppColors.blue500,
                    )
                  : ClipOval(
                      child: Image.network(
                        _avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person_rounded,
                          size: 22,
                          color: AppColors.blue500,
                        ),
                      ),
                    ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayName,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Chia sẻ điều mới?',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.add_photo_alternate_outlined,
              size: 22,
              color: AppColors.blue500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSamplePost() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 12, bottom: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.blue100.withOpacity(0.45)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.blue100,
                backgroundImage: _avatarUrl == null
                    ? null
                    : NetworkImage(_avatarUrl!),
                child: _avatarUrl == null
                    ? const Icon(Icons.person_rounded, color: AppColors.blue500)
                    : null,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '3 ngày trước',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.more_horiz_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),

          const SizedBox(height: 10),

          const Text(
            'Một chút Đà Lạt 🌿',
            style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
          ),

          const SizedBox(height: 10),

          SizedBox(
            height: 164,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                return Container(
                  width: 146,
                  decoration: BoxDecoration(
                    color: AppColors.blue50,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.image_outlined,
                    size: 34,
                    color: AppColors.blue300,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 11),

          const Row(
            children: [
              Icon(
                Icons.favorite_border_rounded,
                size: 21,
                color: AppColors.blue500,
              ),
              SizedBox(width: 5),
              Text(
                '4',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              SizedBox(width: 18),

              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),

              SizedBox(width: 18),

              Icon(
                Icons.send_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FAVORITES
  // ============================================================

  Widget _buildFavoritesTab() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
      child: const Column(
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 34,
            color: AppColors.blue300,
          ),

          SizedBox(height: 12),

          Text(
            'Chưa có địa điểm yêu thích',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          SizedBox(height: 5),

          Text(
            'Những địa điểm bạn lưu sẽ xuất hiện tại đây.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _text(Object? value, {String fallback = ''}) {
    if (value is! String) return fallback;
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  int _stat(String key) {
    final stats = _user['relationshipStats'];
    if (stats is! Map) return 0;
    final value = stats[key];
    if (value is num) return value.toInt();
    return 0;
  }
}

// ============================================================================
// SMALL COMPONENTS
// ============================================================================

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
