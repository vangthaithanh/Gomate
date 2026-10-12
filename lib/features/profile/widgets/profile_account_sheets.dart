import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';

Future<bool?> showProfileEditSheet(
  BuildContext context, {
  required Map<String, dynamic> user,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ProfileEditSheet(user: user),
  );
}

Future<bool?> showChangePasswordSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ChangePasswordSheet(),
  );
}

class _ProfileEditSheet extends StatefulWidget {
  final Map<String, dynamic> user;

  const _ProfileEditSheet({required this.user});

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  late final TextEditingController _nickname;
  late final TextEditingController _fullName;
  late final TextEditingController _city;
  late final TextEditingController _bio;
  late final TextEditingController _avatarUrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(text: _text(widget.user['nickname']));
    _fullName = TextEditingController(text: _text(widget.user['fullName']));
    _city = TextEditingController(text: _text(widget.user['city']));
    _bio = TextEditingController(text: _text(widget.user['bio']));
    _avatarUrl = TextEditingController(text: _text(widget.user['avatarUrl']));
  }

  @override
  void dispose() {
    _nickname.dispose();
    _fullName.dispose();
    _city.dispose();
    _bio.dispose();
    _avatarUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthService.instance.updateProfile(
        nickname: _nickname.text,
        fullName: _fullName.text,
        city: _city.text,
        bio: _bio.text,
        avatarUrl: _avatarUrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Không thể cập nhật hồ sơ lúc này.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Chỉnh sửa hồ sơ',
      error: _error,
      saving: _saving,
      buttonLabel: 'Lưu thay đổi',
      onSave: _save,
      children: [
        _SheetField(controller: _nickname, label: 'Biệt danh'),
        _SheetField(controller: _fullName, label: 'Họ tên'),
        _SheetField(controller: _city, label: 'Thành phố'),
        _SheetField(
          controller: _bio,
          label: 'Tiểu sử',
          minLines: 3,
          maxLines: 4,
        ),
        _SheetField(
          controller: _avatarUrl,
          label: 'URL ảnh đại diện',
          hint: 'https://...',
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  String _text(Object? value) {
    if (value is! String) return '';
    return value.trim();
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final next = _next.text;
    if (next != _confirm.text) {
      setState(() => _error = 'Mật khẩu xác nhận không khớp.');
      return;
    }
    if (next.length < 8) {
      setState(() => _error = 'Mật khẩu mới cần ít nhất 8 ký tự.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthService.instance.changePassword(
        currentPassword: _current.text,
        newPassword: next,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Không thể đổi mật khẩu lúc này.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Đổi mật khẩu',
      error: _error,
      saving: _saving,
      buttonLabel: 'Cập nhật mật khẩu',
      onSave: _save,
      children: [
        _SheetField(
          controller: _current,
          label: 'Mật khẩu hiện tại',
          obscureText: true,
        ),
        _SheetField(
          controller: _next,
          label: 'Mật khẩu mới',
          obscureText: true,
        ),
        _SheetField(
          controller: _confirm,
          label: 'Nhập lại mật khẩu mới',
          obscureText: true,
        ),
      ],
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final String? error;
  final bool saving;
  final String buttonLabel;
  final VoidCallback onSave;

  const _SheetScaffold({
    required this.title,
    required this.children,
    required this.error,
    required this.saving,
    required this.buttonLabel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.blue100,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(
                error!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFFE45858),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: saving ? null : onSave,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: AppColors.blue500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        buttonLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int minLines;
  final int maxLines;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _SheetField({
    required this.controller,
    required this.label,
    this.hint,
    this.minLines = 1,
    this.maxLines = 1,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: AppColors.blue50.withOpacity(0.34),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
      ),
    );
  }
}
