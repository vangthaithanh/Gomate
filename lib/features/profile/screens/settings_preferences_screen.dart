import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../ui_preview/settings_ui_demo.dart';
import '../widgets/settings_shared_widgets.dart';

enum SettingsOptionsKind {
  privacy,
  permissions,
  language,
  darkMode,
  support,
  terms,
  about,
}

class SettingsOptionsScreen extends StatefulWidget {
  final SettingsOptionsKind kind;
  final AuthService? auth;
  const SettingsOptionsScreen({super.key, required this.kind, this.auth});
  @override
  State<SettingsOptionsScreen> createState() => _SettingsOptionsScreenState();
}

class _SettingsOptionsScreenState extends State<SettingsOptionsScreen> {
  final demo = SettingsUiDemo.instance;
  late final AuthService _auth;
  bool _privacyBusy = false;
  bool _privacyLoading = true;
  bool _privacyError = false;
  @override
  void initState() {
    super.initState();
    demo.addListener(_refresh);
    _auth = widget.auth ?? AuthService.instance;
    _auth.addListener(_refresh);
    if (widget.kind == SettingsOptionsKind.privacy) _loadPrivacy();
  }

  @override
  void dispose() {
    demo.removeListener(_refresh);
    _auth.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPrivacy() async {
    setState(() {
      _privacyLoading = true;
      _privacyError = false;
    });
    try {
      await _auth.loadProfile();
    } catch (_) {
      if (mounted) setState(() => _privacyError = true);
    } finally {
      if (mounted) setState(() => _privacyLoading = false);
    }
  }

  Future<void> _savePrivacy(bool value) async {
    if (_privacyBusy) return;
    setState(() => _privacyBusy = true);
    try {
      await _auth.updatePrivacy(value);
    } catch (_) {
      if (mounted) {
        GoMateSnackBar.show(
          context,
          message: 'Không lưu được quyền riêng tư. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _privacyBusy = false);
    }
  }

  String get title => switch (widget.kind) {
    SettingsOptionsKind.privacy => 'Quyền riêng tư',
    SettingsOptionsKind.permissions => 'Quyền truy cập thiết bị',
    SettingsOptionsKind.language => 'Ngôn ngữ giao diện',
    SettingsOptionsKind.darkMode => 'Chế độ tối',
    SettingsOptionsKind.support => 'Trợ giúp & Hỗ trợ',
    SettingsOptionsKind.terms => 'Điều khoản & chính sách',
    SettingsOptionsKind.about => 'Giới thiệu GoMate',
  };
  @override
  Widget build(BuildContext context) => SettingsPageShell(
    title: title,
    body: switch (widget.kind) {
      SettingsOptionsKind.privacy => _privacy(),
      SettingsOptionsKind.permissions => _permissions(),
      SettingsOptionsKind.darkMode => _darkMode(),
      SettingsOptionsKind.language => _language(),
      _ => _future(),
    },
  );
  Widget _privacy() => ListView(
    children: [
      SettingsMenuRow(
        title: 'Tài khoản riêng tư',
        showArrow: false,
        trailing: Switch.adaptive(
          value: _auth.user?['isPrivate'] == true,
          activeColor: AppColors.primaryIcon,
          inactiveTrackColor: const Color(0xFFF0F0F0),
          inactiveThumbColor: Colors.white,
          trackOutlineColor: const WidgetStatePropertyAll<Color?>(
            Colors.transparent,
          ),
          onChanged:
              _privacyLoading ||
                  _privacyError ||
                  _privacyBusy ||
                  !_auth.signedIn
              ? null
              : _savePrivacy,
        ),
      ),
      if (_privacyLoading || _privacyBusy)
        const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      if (_privacyError)
        TextButton(
          onPressed: _loadPrivacy,
          child: const Text('Không tải được quyền riêng tư. Thử lại'),
        ),
      const Padding(
        padding: EdgeInsets.fromLTRB(24, 10, 24, 0),
        child: Text(
          'Khi bật tài khoản riêng tư, người mới cần được bạn phê duyệt để theo dõi. Người đã theo dõi bạn trước đó vẫn được giữ nguyên.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.45,
            color: AppColors.grayText,
          ),
        ),
      ),
    ],
  );
  Widget _darkMode() => ListView(
    children: [
      SettingsMenuRow(
        title: 'Chế độ tối',
        icon: LucideIcons.moon,
        showArrow: false,
        trailing: Switch.adaptive(
          value: demo.darkModePreview,
          activeColor: AppColors.primaryIcon,
          inactiveTrackColor: const Color(0xFFF0F0F0),
          inactiveThumbColor: Colors.white,
          trackOutlineColor: const WidgetStatePropertyAll<Color?>(
            Colors.transparent,
          ),
          onChanged: (value) {
            demo.darkModePreview = value;
            demo.changed();
            GoMateSnackBar.show(
              context,
              message:
                  'Đã cập nhật công tắc xem thử (chưa đổi Theme toàn ứng dụng)',
            );
          },
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 23),
        child: Text(
          'Giao diện GoMate hiện dùng chủ đề sáng. Hỗ trợ ThemeMode.system, sáng/tối và lưu lựa chọn sẽ được tích hợp sau.',
          style: TextStyle(color: AppColors.grayText, fontSize: 12),
        ),
      ),
    ],
  );
  Widget _permissions() {
    // TODO(BACKEND-SETTINGS-UI): read real OS permission statuses with platform
    // adapter/permission_handler. Do not present the demo labels as real grants.
    const data = <String, String>{
      'Camera': 'Đã cho phép',
      'Danh bạ': 'Chưa cho phép',
      'Vị trí': 'Đã cho phép',
      'Micro': 'Đã cho phép',
      'Thông báo': 'Đã cho phép',
      'Ảnh': 'Đã cho phép',
    };
    return ListView(
      children: [
        const SettingsSectionLabel('Tuỳ chọn của bạn'),
        for (final item in data.entries)
          SettingsMenuRow(
            title: item.key,
            value: SettingsUiDemo.enabled ? item.value : 'Chưa xác định',
            onTap: () => GoMateSnackBar.show(
              context,
              message:
                  'Trạng thái quyền ${item.key} cần được đọc từ hệ thống thiết bị.',
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(23, 24, 23, 0),
          child: Text(
            'Danh sách hiện chưa truy vấn quyền hệ điều hành. Sau khi tích hợp, chạm một dòng sẽ mở phần cài đặt quyền tương ứng trên thiết bị.',
            style: TextStyle(fontSize: 12, color: AppColors.grayText),
          ),
        ),
      ],
    );
  }

  Widget _language() => ListView(
    children: [
      const SettingsSectionLabel('Ngôn ngữ ứng dụng'),
      SettingsMenuRow(
        title: 'Tiếng Việt',
        icon: LucideIcons.languages,
        value: 'Đang hiển thị',
        onTap: () => GoMateSnackBar.show(
          context,
          message: 'Chuyển ngôn ngữ sẽ được kết nối hệ thống đa ngôn ngữ sau.',
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 23, vertical: 18),
        child: Text(
          'Hiện chưa thay đổi ngôn ngữ của toàn bộ ứng dụng.',
          style: TextStyle(color: AppColors.grayText, fontSize: 12),
        ),
      ),
    ],
  );
  Widget _future() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.info, size: 42, color: AppColors.primaryIcon),
        const SizedBox(height: 16),
        Text(
          '$title sẽ được phát triển sau',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ],
    ),
  );
}

/// Reusable confirmation UI for settings actions; same GoMateBottomSheet shell.
Future<bool> showSettingsConfirm(
  BuildContext context, {
  required String title,
  required String explanation,
  required String confirmText,
}) async {
  final result = await GoMateBottomSheet.show<bool>(
    context: context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          explanation,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.grayText,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        SettingsGradientButton(
          text: confirmText,
          onTap: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: 9),
      ],
    ),
  );
  return result == true;
}
