import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../auth/screens/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _notificationsEnabled = true;
  bool _isLoggingOut = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearch(),

                    const SizedBox(height: 18),

                    _buildAccountCard(),

                    const SizedBox(height: 18),

                    ..._buildFilteredSections(),

                    const SizedBox(height: 18),

                    _buildLogoutCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          const SizedBox(width: 6),

          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 19,
              color: AppColors.textPrimary,
            ),
          ),

          const Expanded(
            child: Center(
              child: Text(
                'Cài đặt',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),

          const SizedBox(
            width: 54,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,

      onChanged: (value) {
        setState(() {
          _query = value.trim().toLowerCase();
        });
      },

      decoration: InputDecoration(
        hintText: 'Tìm trong cài đặt',
        hintStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),

        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
        ),

        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
          onPressed: () {
            _searchController.clear();

            setState(() {
              _query = '';
            });
          },
          icon: const Icon(
            Icons.close_rounded,
            size: 19,
            color: AppColors.textSecondary,
          ),
        ),

        filled: true,
        fillColor: AppColors.blue50.withOpacity(0.38),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ============================================================
  // ACCOUNT CARD
  // ============================================================

  Widget _buildAccountCard() {
    if (!_matchesAny([
      'xuân thu',
      'xuthu',
      'tài khoản',
      'hồ sơ',
      'email',
    ])) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: AppColors.blue50.withOpacity(0.34),
        borderRadius: BorderRadius.circular(24),
      ),

      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,

            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.blue100,
            ),

            child: const Icon(
              Icons.person_rounded,
              size: 30,
              color: AppColors.blue500,
            ),
          ),

          const SizedBox(width: 13),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xuân Thu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),

                SizedBox(height: 3),

                Text(
                  '@xuthu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          InkWell(
            onTap: () {
              // UI only - bước sau có thể nối màn chỉnh sửa hồ sơ.
            },
            borderRadius: BorderRadius.circular(14),

            child: Container(
              width: 38,
              height: 38,

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
              ),

              child: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppColors.blue500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTIONS
  // ============================================================

  List<Widget> _buildFilteredSections() {
    final widgets = <Widget>[];

    if (_sectionVisible([
      'chỉnh sửa hồ sơ',
      'tài khoản',
      'hoạt động',
      'đã lưu',
    ])) {
      widgets.add(
        _SettingsSection(
          title: 'Tài khoản',
          children: [
            _SettingsTile(
              icon: Icons.person_outline_rounded,
              iconBackground: const Color(0xFFEAF2FF),
              iconColor: AppColors.blue500,
              title: 'Chỉnh sửa hồ sơ',
              subtitle: 'Tên, ảnh đại diện, tiểu sử',
              onTap: () {},
            ),

            _SettingsTile(
              icon: Icons.history_rounded,
              iconBackground: const Color(0xFFF2ECFF),
              iconColor: const Color(0xFF8A63D2),
              title: 'Hoạt động của bạn',
              subtitle: 'Bài viết, đánh giá và lịch sử',
              onTap: () {},
            ),

            _SettingsTile(
              icon: Icons.bookmark_border_rounded,
              iconBackground: const Color(0xFFEAF8F1),
              iconColor: const Color(0xFF46A678),
              title: 'Đã lưu',
              subtitle: 'Địa điểm và thư mục yêu thích',
              onTap: () {},
            ),
          ],
        ),
      );

      widgets.add(
        const SizedBox(height: 16),
      );
    }

    if (_sectionVisible([
      'thông báo',
      'ngôn ngữ',
      'giao diện',
      'vị trí',
      'quyền vị trí',
    ])) {
      widgets.add(
        _SettingsSection(
          title: 'Tùy chọn',
          children: [
            _SettingsTile(
              icon: Icons.notifications_none_rounded,
              iconBackground: const Color(0xFFFFF2E7),
              iconColor: const Color(0xFFF3A150),
              title: 'Thông báo',
              subtitle: 'Tin nhắn, chuyến đi và cập nhật',
              trailing: Switch.adaptive(
                value: _notificationsEnabled,
                activeColor: AppColors.blue500,

                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                },
              ),
            ),

            _SettingsTile(
              icon: Icons.language_rounded,
              iconBackground: const Color(0xFFEAF2FF),
              iconColor: AppColors.blue500,
              title: 'Ngôn ngữ giao diện',
              subtitle: 'Tiếng Việt',
              onTap: () {},
            ),

            _SettingsTile(
              icon: Icons.palette_outlined,
              iconBackground: const Color(0xFFF3ECFF),
              iconColor: const Color(0xFF9B6DDB),
              title: 'Giao diện',
              subtitle: 'Sáng',
              onTap: () {},
            ),

            _SettingsTile(
              icon: Icons.location_on_outlined,
              iconBackground: const Color(0xFFE9F8F2),
              iconColor: const Color(0xFF4FA77C),
              title: 'Quyền vị trí',
              subtitle: 'Dùng vị trí cho bản đồ và hành trình',
              onTap: () {},
            ),
          ],
        ),
      );

      widgets.add(
        const SizedBox(height: 16),
      );
    }

    if (_sectionVisible([
      'bảo mật',
      'quyền riêng tư',
      'mật khẩu',
      'đăng nhập',
    ])) {
      widgets.add(
        _SettingsSection(
          title: 'Bảo mật',
          children: [
            _SettingsTile(
              icon: Icons.shield_outlined,
              iconBackground: const Color(0xFFF6EDFF),
              iconColor: const Color(0xFFA268D5),
              title: 'Bảo mật & Quyền riêng tư',
              subtitle: 'Mật khẩu, phiên đăng nhập và quyền truy cập',
              onTap: () {},
            ),

            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              iconBackground: const Color(0xFFEAF2FF),
              iconColor: AppColors.blue500,
              title: 'Đổi mật khẩu',
              subtitle: 'Cập nhật mật khẩu tài khoản',
              onTap: () {},
            ),
          ],
        ),
      );

      widgets.add(
        const SizedBox(height: 16),
      );
    }

    if (_sectionVisible([
      'trợ giúp',
      'hỗ trợ',
      'điều khoản',
      'chính sách',
      'giới thiệu',
    ])) {
      widgets.add(
        _SettingsSection(
          title: 'Hỗ trợ',
          children: [
            _SettingsTile(
              icon: Icons.help_outline_rounded,
              iconBackground: const Color(0xFFE9F8F2),
              iconColor: const Color(0xFF4FA77C),
              title: 'Trợ giúp & Hỗ trợ',
              subtitle: 'Câu hỏi thường gặp và liên hệ',
              onTap: () {},
            ),

            _SettingsTile(
              icon: Icons.description_outlined,
              iconBackground: const Color(0xFFFFF4E8),
              iconColor: const Color(0xFFE39A48),
              title: 'Điều khoản & Chính sách',
              subtitle: 'Điều khoản sử dụng và quyền riêng tư',
              onTap: () {},
            ),

            _SettingsTile(
              icon: Icons.info_outline_rounded,
              iconBackground: const Color(0xFFEAF2FF),
              iconColor: AppColors.blue500,
              title: 'Giới thiệu GoMate',
              subtitle: 'Phiên bản ứng dụng và thông tin',
              onTap: () {},
            ),
          ],
        ),
      );
    }

    if (widgets.isEmpty) {
      widgets.add(
        const _NoSettingFound(),
      );
    }

    return widgets;
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Widget _buildLogoutCard() {
    if (!_matchesAny([
      'đăng xuất',
      'logout',
      'tài khoản',
    ])) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: _isLoggingOut
          ? null
          : () {
        _showLogoutDialog();
      },
      borderRadius: BorderRadius.circular(22),

      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F1),
          borderRadius: BorderRadius.circular(22),
        ),

        child: Row(
          children: [
            const SizedBox(
              width: 42,
              height: 42,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFFFFE2E2),
                  borderRadius: BorderRadius.all(
                    Radius.circular(13),
                  ),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: Color(0xFFE45858),
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                _isLoggingOut
                    ? 'Đang đăng xuất...'
                    : 'Đăng xuất',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE45858),
                ),
              ),
            ),

            if (_isLoggingOut)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Color(0xFFE45858),
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFE45858),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    await showDialog<void>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),

          title: const Text(
            'Đăng xuất?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),

          content: const Text(
            'Bạn có chắc muốn đăng xuất khỏi GoMate không?',
            style: TextStyle(
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Huỷ',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _logout();
              },
              child: const Text(
                'Đăng xuất',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE45858),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      // Dùng lại AuthService hiện có của dự án:
      // backend revoke refresh session + Flutter xoá token phía thiết bị.
      await AuthService.instance.logout();

      if (!mounted) return;

      // Xoá toàn bộ stack của MainShell/Profile/Settings
      // để người dùng không thể back về màn đã đăng nhập.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
            (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Không thể đăng xuất lúc này. Hãy kiểm tra kết nối và thử lại.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // SEARCH HELPERS
  // ============================================================

  bool _matchesAny(List<String> keywords) {
    if (_query.isEmpty) {
      return true;
    }

    return keywords.any(
          (keyword) => keyword
          .toLowerCase()
          .contains(_query),
    );
  }

  bool _sectionVisible(List<String> keywords) {
    return _matchesAny(keywords);
  }
}

// ============================================================================
// SETTINGS SECTION
// ============================================================================

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 4,
            bottom: 9,
          ),

          child: Text(
            title,

            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),

        Container(
          width: double.infinity,

          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),

            border: Border.all(
              color: AppColors.blue100.withOpacity(0.45),
            ),
          ),

          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],

                if (i != children.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 68,
                    ),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.blue100.withOpacity(0.35),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SETTINGS TILE
// ============================================================================

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),

      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),

        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,

              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(13),
              ),

              child: Icon(
                icon,
                size: 21,
                color: iconColor,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    title,

                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  if (subtitle != null) ...[
                    const SizedBox(height: 3),

                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(
                        fontSize: 11.8,
                        height: 1.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: AppColors.textSecondary,
                ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY SEARCH
// ============================================================================

class _NoSettingFound extends StatelessWidget {
  const _NoSettingFound();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 36,
      ),

      decoration: BoxDecoration(
        color: AppColors.blue50.withOpacity(0.30),
        borderRadius: BorderRadius.circular(22),
      ),

      child: const Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 32,
            color: AppColors.blue300,
          ),

          SizedBox(height: 10),

          Text(
            'Không tìm thấy cài đặt',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

          SizedBox(height: 5),

          Text(
            'Thử tìm kiếm bằng từ khóa khác.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
