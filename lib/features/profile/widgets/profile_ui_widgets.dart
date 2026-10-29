import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gomate_main_tab_header.dart';

/// Shared visual-only widgets for both my profile and public profile.
/// No API calls, session state or business decisions belong here.
/// Avatar dùng chung cho màn cá nhân, người khác và chỉnh sửa.
/// Badge dấu + dùng tỷ lệ của Home/MomentsStrip để giữ cùng phong cách.
class GoMateProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? previewFilePath;
  final double size;
  final bool showAdd;
  final bool showCamera;
  final VoidCallback? onTap;

  const GoMateProfileAvatar({
    super.key,
    this.imageUrl,
    this.previewFilePath,
    this.size = 62,
    this.showAdd = false,
    this.showCamera = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badged = showAdd || showCamera;
    final frameSize = badged ? size + 6 : size;
    // Home: avatar bình thường nhỏ hơn vòng ngoài. Giữ avatar ở chính giữa.
    final avatarSize = showAdd ? frameSize * 0.84 : size;
    final addBadge = frameSize * 0.31;
    final cameraBadge = (frameSize * 0.37).clamp(25.0, 30.0).toDouble();

    Widget placeholder() => const Center(
      child: Icon(LucideIcons.user_round, color: AppColors.grayText, size: 28),
    );

    Widget photo() {
      final local = previewFilePath?.trim() ?? '';
      if (local.isNotEmpty) {
        return Image.file(
          File(local),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder(),
        );
      }
      final url = imageUrl?.trim() ?? '';
      if (url.startsWith('https://') || url.startsWith('http://')) {
        return Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder(),
        );
      }
      // UI-only preview avatars can use bundled assets. No network/API call.
      if (url.isNotEmpty) {
        return Image.asset(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder(),
        );
      }
      return placeholder();
    }

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox.square(
        dimension: frameSize,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE7EBF3),
                border: Border.all(color: AppColors.grayBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: photo(),
            ),
            if (showAdd)
              Positioned(
                right: frameSize * 0.01,
                bottom: frameSize * 0.03,
                child: Container(
                  width: addBadge,
                  height: addBadge,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryIcon,
                    border: Border.all(
                      color: Colors.white,
                      width: frameSize * 0.034,
                    ),
                  ),
                  child: Icon(
                    LucideIcons.plus,
                    size: addBadge * 0.52,
                    color: Colors.white,
                  ),
                ),
              ),
            if (showCamera)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: cameraBadge,
                  height: cameraBadge,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    LucideIcons.camera,
                    size: cameraBadge * 0.67,
                    color: AppColors.primaryIcon,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dùng cùng gradient và bo góc với các nút xác nhận của Moments.
/// Đây là component giao diện; không chứa thao tác API.
class GoMateProfileGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const GoMateProfileGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              width: double.infinity,
              height: 43,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GoMateProfileStat extends StatelessWidget {
  final int value;
  final String label;
  final VoidCallback? onTap;

  const GoMateProfileStat({
    super.key,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shortValue = value >= 1000000
        ? '${(value / 1000000).toStringAsFixed(1)}M'
        : value >= 1000
        ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k'
        : '$value';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              shortValue,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(fontSize: 11, color: Color(0xFF828282)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GoMateProfileTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const GoMateProfileTabs({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tab(0, LucideIcons.images, 'Bài viết'),
        _tab(1, LucideIcons.heart, 'Địa điểm đã thích'),
      ],
    );
  }

  Widget _tab(int index, IconData icon, String tooltip) {
    final selected = selectedIndex == index;
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () => onSelected(index),
          child: SizedBox(
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 23,
                  color: selected
                      ? AppColors.primaryIcon
                      : const Color(0xFF828282),
                ),
                const SizedBox(height: 9),
                Container(
                  height: 2,
                  color: selected ? AppColors.primaryIcon : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GoMateProfileEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;

  const GoMateProfileEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 46, horizontal: 28),
      child: Column(
        children: [
          Icon(icon, size: 37, color: const Color(0xFFB0B7C4)),
          const SizedBox(height: 11),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Color(0xFF828282),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// UI projection of a real post. Supply values from an existing/future
/// repository; do not invent post ownership from a display name.
class GoMateProfilePostPreview {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String? location;
  final String caption;
  final List<String> media;
  final int likeCount;
  final int commentCount;
  final Map<String, dynamic>? server;

  const GoMateProfilePostPreview({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.caption,
    required this.media,
    this.authorAvatar,
    this.location,
    this.likeCount = 0,
    this.commentCount = 0,
    this.server,
  });
}

/// Simple wrapper around the actual app-wide GoMateMainTabHeader.
/// Do not duplicate header metrics or hard-code a second profile header.
class GoMateProfilePageHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const GoMateProfilePageHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => GoMateMainTabHeader(
    title: title,
    leadingIcon: LucideIcons.chevron_left,
    onLeadingTap: () => Navigator.of(context).maybePop(),
    trailingWidget: trailing,
  );
}
