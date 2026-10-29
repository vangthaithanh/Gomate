import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/gomate_name_editor_content.dart';
import '../../../core/widgets/snackbar.dart';
import '../widgets/profile_ui_widgets.dart';

/// Profile editor - changes supported fields through the EXISTING AuthService.
/// Avatar binary upload, website link and gender are not in master ProfileUpdate;
/// those controls preview locally and explicitly do NOT persist to backend.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _auth = AuthService.instance;
  final _imagePicker = ImagePicker();
  XFile? _pendingAvatar;
  String? _genderPreview;
  String? _linkPreview;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_refresh);
  }

  @override
  void dispose() {
    _auth.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Map<String, dynamic> get _user => _auth.user ?? const {};
  String _text(String field) =>
      _user[field] is String ? (_user[field] as String).trim() : '';

  Future<void> _editShortText({
    required String title,
    required String field,
    required int limit,
  }) async {
    final current = _text(field);
    final next = await GoMateBottomSheet.show<String>(
      context: context,
      child: GoMateNameEditorContent(
        title: title,
        initialValue: current,
        hintText: 'Nhập $title',
        maxLength: limit,
      ),
    );
    if (!mounted || next == null || next.trim() == current) return;
    // Existing backend contract: nickname max 40, fullName max 120.
    if (next.runes.length > limit) {
      GoMateSnackBar.show(context, message: '$title tối đa $limit ký tự.');
      return;
    }
    await _saveProfile(
      nickname: field == 'nickname' ? next : null,
      fullName: field == 'fullName' ? next : null,
    );
  }

  Future<void> _editBio() async {
    final next = await GoMateBottomSheet.show<String>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      child: _BioEditorContent(initial: _text('bio')),
    );
    if (!mounted || next == null || next == _text('bio')) return;
    await _saveProfile(bio: next);
  }

  Future<void> _saveProfile({
    String? nickname,
    String? fullName,
    String? bio,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _auth.updateProfile(
        nickname: nickname,
        fullName: fullName,
        bio: bio,
      );
      if (!mounted) return;
      GoMateSnackBar.show(context, message: 'Đã cập nhật hồ sơ');
    } catch (error) {
      if (!mounted) return;
      GoMateSnackBar.show(context, message: 'Không thể cập nhật hồ sơ: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseAvatar() async {
    final source = await GoMateBottomSheet.show<ImageSource>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Thay ảnh đại diện',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(LucideIcons.image),
            title: const Text('Chọn ảnh từ thư viện'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(LucideIcons.camera),
            title: const Text('Chụp ảnh'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
        ],
      ),
    );
    if (!mounted || source == null) return;
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1440,
      );
      if (!mounted || file == null) return;
      setState(() => _pendingAvatar = file);
      GoMateSnackBar.show(
        context,
        message:
            'Đã chọn ảnh. Chức năng tải ảnh đại diện lên máy chủ chưa có trong API hiện tại.',
      );
    } catch (_) {
      if (!mounted) return;
      GoMateSnackBar.show(context, message: 'Không thể mở ảnh hoặc máy ảnh.');
    }
  }

  Future<void> _chooseGender() async {
    final selected = await GoMateBottomSheet.show<String>(
      context: context,
      child: _GenderContent(initialValue: _genderPreview),
    );
    if (!mounted || selected == null) return;
    setState(() => _genderPreview = selected);
    GoMateSnackBar.show(
      context,
      message:
          'Giới tính mới chỉ được xem trước. Backend hiện chưa hỗ trợ lưu trường này.',
    );
  }

  Future<void> _editLink() async {
    final next = await GoMateBottomSheet.show<String>(
      context: context,
      child: _BioEditorContent(
        initial: _linkPreview ?? '',
        title: 'Liên kết',
        hint: 'https://...',
        maxLength: 1000,
        minLines: 1,
      ),
    );
    if (!mounted || next == null) return;
    setState(() => _linkPreview = next);
    GoMateSnackBar.show(
      context,
      message:
          'Liên kết mới chỉ được xem trước. Backend hiện chưa hỗ trợ lưu trường này.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = (width * 0.075).clamp(20.0, 30.0).toDouble();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          physics: const BouncingScrollPhysics(),
          children: [
            SizedBox(
              height: 54,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      LucideIcons.chevron_left,
                      color: Colors.black,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Chỉnh sửa trang cá nhân',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 17),
            Center(
              child: GoMateProfileAvatar(
                imageUrl: _text('avatarUrl'),
                previewFilePath: _pendingAvatar?.path,
                size: 70,
                showCamera: true,
                onTap: _chooseAvatar,
              ),
            ),
            const SizedBox(height: 25),
            _entry(
              'Tên',
              _text('fullName'),
              () => _editShortText(title: 'Tên', field: 'fullName', limit: 50),
            ),
            _entry(
              'Biệt danh',
              _text('nickname'),
              () => _editShortText(
                title: 'Biệt danh',
                field: 'nickname',
                limit: 40,
              ),
            ),
            _entry('Tiểu sử', _text('bio'), _editBio),
            const SizedBox(height: 7),
            _secondaryEntry(
              icon: LucideIcons.link_2,
              label: 'Thêm liên kết',
              value: _linkPreview ?? '',
              onTap: _editLink,
            ),
            _secondaryEntry(
              icon: LucideIcons.users_round,
              label: 'Giới tính',
              value: _genderPreview ?? '',
              onTap: _chooseGender,
            ),
            if (_saving) ...[
              const SizedBox(height: 20),
              const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryIcon,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _entry(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: _saving ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? ' ' : value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: label == 'Tiểu sử'
                      ? const Color(0xFF828282)
                      : Colors.black,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secondaryEntry({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    return InkWell(
      onTap: _saving ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 0, top: 14, bottom: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (value.trim().isNotEmpty) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width * 0.32),
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grayText,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            // Không đặt trong Flexible/Expanded: icon luôn sát mép phải.
            const Icon(
              LucideIcons.chevron_right,
              size: 20,
              color: AppColors.grayText,
            ),
          ],
        ),
      ),
    );
  }
}

class _BioEditorContent extends StatefulWidget {
  final String initial;
  final String title;
  final String hint;
  final int maxLength;
  final int minLines;

  const _BioEditorContent({
    required this.initial,
    this.title = 'Tiểu sử',
    this.hint = 'Viết gì đó về bạn...',
    this.maxLength = 1000,
    this.minLines = 4,
  });

  @override
  State<_BioEditorContent> createState() => _BioEditorContentState();
}

class _BioEditorContentState extends State<_BioEditorContent> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 15),
        TextSelectionTheme(
          data: const TextSelectionThemeData(
            cursorColor: AppColors.primaryIcon,
            selectionColor: Color(0x330A43A8),
            selectionHandleColor: AppColors.primaryIcon,
          ),
          child: TextField(
            controller: _controller,
            cursorColor: AppColors.primaryIcon,
            maxLength: widget.maxLength,
            minLines: widget.minLines,
            maxLines: widget.minLines == 1 ? 1 : 6,
            keyboardType: widget.minLines == 1
                ? TextInputType.url
                : TextInputType.multiline,
            style: const TextStyle(fontSize: 13, color: AppColors.black),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.grayText,
              ),
              counterStyle: const TextStyle(
                fontSize: 11,
                color: AppColors.grayText,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: (width * 0.038).clamp(12.0, 16.0).toDouble(),
                vertical: 12,
              ),
              filled: true,
              fillColor: AppColors.grayBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: AppColors.primaryIcon,
                  width: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GoMateProfileGradientButton(
          label: 'Lưu',
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        ),
      ],
    );
  }
}

class _GenderContent extends StatefulWidget {
  final String? initialValue;
  const _GenderContent({this.initialValue});
  @override
  State<_GenderContent> createState() => _GenderContentState();
}

class _GenderContentState extends State<_GenderContent> {
  String? _selected;
  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Giới tính',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 13),
        for (final value in const <String>['Nam', 'Nữ'])
          InkWell(
            onTap: () => setState(() => _selected = value),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selected == value
                            ? AppColors.primaryIcon
                            : AppColors.grayBorder,
                        width: 2,
                      ),
                    ),
                    child: _selected == value
                        ? const Center(
                            child: CircleAvatar(
                              radius: 5,
                              backgroundColor: AppColors.primaryIcon,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        GoMateProfileGradientButton(
          label: 'Xác nhận',
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(_selected),
        ),
      ],
    );
  }
}
