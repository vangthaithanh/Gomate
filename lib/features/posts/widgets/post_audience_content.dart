import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../models/post_compose_models.dart';

/// Shared by Create Post and My Post 3-dot menu.
class GoMatePostAudienceContent extends StatefulWidget {
  final GoMatePostAudience initial;
  final bool isPrivate;
  const GoMatePostAudienceContent({
    super.key,
    required this.initial,
    this.isPrivate = false,
  });

  @override
  State<GoMatePostAudienceContent> createState() =>
      _GoMatePostAudienceContentState();
}

class _GoMatePostAudienceContentState extends State<GoMatePostAudienceContent> {
  late GoMatePostAudience _selected;

  @override
  void initState() {
    super.initState();
    _selected =
        (widget.isPrivate && widget.initial == GoMatePostAudience.everyone) ||
            (!widget.isPrivate &&
                widget.initial == GoMatePostAudience.followers)
        ? (widget.isPrivate
              ? GoMatePostAudience.followers
              : GoMatePostAudience.everyone)
        : widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = (width * .055).clamp(18.0, 24.0).toDouble();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ai có thể nhìn thấy bài viết này',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.primaryText,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isPrivate
                ? 'Tài khoản riêng tư chia sẻ cho người theo dõi, bạn bè hoặc chính bạn.'
                : 'Chọn đối tượng có thể xem bài viết của bạn.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.grayText),
          ),
          const SizedBox(height: 14),
          for (final item in GoMatePostAudience.values)
            if (item == GoMatePostAudience.friends ||
                item == GoMatePostAudience.onlyMe ||
                item ==
                    (widget.isPrivate
                        ? GoMatePostAudience.followers
                        : GoMatePostAudience.everyone))
              InkWell(
                onTap: () => setState(() => _selected = item),
                child: SizedBox(
                  height: 54,
                  child: Row(
                    children: [
                      Icon(
                        switch (item) {
                          GoMatePostAudience.everyone => LucideIcons.globe,
                          GoMatePostAudience.friends => LucideIcons.users,
                          GoMatePostAudience.followers =>
                            LucideIcons.user_round,
                          GoMatePostAudience.onlyMe => LucideIcons.eye,
                        },
                        size: 22,
                        color: AppColors.black,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.black,
                          ),
                        ),
                      ),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: item == _selected
                              ? AppColors.primaryIcon
                              : const Color(0xFFE7E7E7),
                          border: Border.all(
                            color: item == _selected
                                ? AppColors.primaryIcon
                                : AppColors.grayText,
                          ),
                        ),
                        child: item == _selected
                            ? const Icon(
                                LucideIcons.check,
                                size: 13,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(_selected),
              child: Container(
                constraints: const BoxConstraints(minWidth: 150, minHeight: 42),
                padding: EdgeInsets.symmetric(horizontal: pad),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppColors.elevatedShadow,
                ),
                child: const Text(
                  'Lưu',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
