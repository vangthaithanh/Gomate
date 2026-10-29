import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';

/// Shared visual components for Settings and Your Activity.
/// TODO(BACKEND-SETTINGS-UI): retain these widgets after demo removal.
class SettingsPageShell extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? trailing;
  final String? description;
  const SettingsPageShell({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
    this.description,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          SettingsCompactHeader(title: title, trailing: trailing),
          if (description != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 0, 30, 12),
              child: Text(
                description!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.grayText,
                  fontSize: 12.5,
                ),
              ),
            ),
          Expanded(child: body),
        ],
      ),
    ),
  );
}

/// Header for Settings SUBPAGES: smaller than MainTab header. The left/right
/// 44dp control slots have the same width, so the title stays centered.
/// Do not change the shared main-tab header or other screens.
class SettingsCompactHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SettingsCompactHeader({super.key, required this.title, this.trailing});
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final margin = SettingsLayout.side(width);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: margin, vertical: 5),
      child: SizedBox(
        height: 45,
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  LucideIcons.chevron_left,
                  color: AppColors.black,
                  size: 23,
                ),
              ),
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: (width * 0.041).clamp(14.5, 16.5).toDouble(),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(
              width: 44,
              height: 44,
              child: trailing == null ? null : Center(child: trailing),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared left/right content inset for all Settings screens and rows.
class SettingsLayout {
  const SettingsLayout._();
  static double side(double width) =>
      (width * 0.058).clamp(20.0, 24.0).toDouble();
}

class SettingsSectionLabel extends StatelessWidget {
  final String text;
  const SettingsSectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      SettingsLayout.side(MediaQuery.sizeOf(context).width),
      17,
      SettingsLayout.side(MediaQuery.sizeOf(context).width),
      7,
    ),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.grayText,
          fontSize: 14,
        ),
      ),
    ),
  );
}

/// Right-aligned values and chevrons never depend on the title length.
/// Trailing content uses the same right edge in every Settings section.
class SettingsMenuRow extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showArrow;
  const SettingsMenuRow({
    super.key,
    required this.title,
    this.icon,
    this.value,
    this.trailing,
    this.onTap,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final glyph = (width * 0.057).clamp(21.0, 24.0).toDouble();
    final side = SettingsLayout.side(width);
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (width * .15).clamp(54.0, 64.0).toDouble(),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: side),
            child: Row(
              children: [
                if (icon != null) ...[
                  SizedBox(
                    width: 29,
                    child: Icon(icon, size: glyph, color: AppColors.black),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: (width * .037).clamp(13.0, 15.5).toDouble(),
                      fontWeight: FontWeight.w600,
                      color: AppColors.black,
                    ),
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: width * .26),
                    child: Text(
                      value!,
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
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                if (showArrow) ...[
                  const SizedBox(width: 7),
                  const SizedBox(
                    width: 22,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Icon(
                        LucideIcons.chevron_right,
                        size: 22,
                        color: AppColors.grayText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsGradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool enabled;
  const SettingsGradientButton({
    super.key,
    required this.text,
    required this.onTap,
    this.enabled = true,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.primaryGradient : null,
          color: enabled ? null : AppColors.grayBorder,
          borderRadius: BorderRadius.circular(999),
          boxShadow: AppColors.elevatedShadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class SettingsVisualAvatar extends StatelessWidget {
  final String? url;
  final double size;
  const SettingsVisualAvatar({super.key, this.url, this.size = 37});
  @override
  Widget build(BuildContext context) {
    final v = url?.trim() ?? '';
    Widget fallback() =>
        Icon(LucideIcons.user_round, size: size * .57, color: Colors.white);
    Widget image;
    if (v.startsWith('http://') || v.startsWith('https://')) {
      image = Image.network(
        v,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      );
    } else if (v.isNotEmpty) {
      image = Image.asset(
        v,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      );
    } else {
      image = fallback();
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE7EBF3),
        border: Border.all(color: AppColors.grayBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(child: image),
    );
  }
}

class SettingsMediaImage extends StatelessWidget {
  final String image;
  final BoxFit fit;
  const SettingsMediaImage(this.image, {super.key, this.fit = BoxFit.cover});
  @override
  Widget build(BuildContext context) {
    Widget fallback() => const ColoredBox(
      color: AppColors.blue50,
      child: Center(
        child: Icon(LucideIcons.image, color: AppColors.primaryIcon),
      ),
    );
    if (image.startsWith('http'))
      return Image.network(
        image,
        fit: fit,
        errorBuilder: (_, __, ___) => fallback(),
      );
    return Image.asset(
      image,
      fit: fit,
      errorBuilder: (_, __, ___) => fallback(),
    );
  }
}

class SettingsEmpty extends StatelessWidget {
  final String text;
  const SettingsEmpty(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.grayText, fontSize: 14),
      ),
    ),
  );
}
