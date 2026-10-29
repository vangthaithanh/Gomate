import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';

/// Cụm nút nổi bên phải Map.
///
/// Layout V19:
/// - slot la bàn luôn được giữ chỗ ở phía trên;
/// - search / itinerary / current-location luôn ở đúng một vị trí;
/// - nút ghim nằm ngay sau current-location; chat nhóm nằm cuối;
/// - compass/chat ẩn hiện nhưng KHÔNG làm 3 nút chính bị đẩy lên/xuống.
class GoMateMapControls extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onTripPicker;
  final VoidCallback onLocation;

  final VoidCallback? onChat;
  final Widget? pinButton;

  final bool showCompass;
  final double bearing;
  final VoidCallback onCompass;

  const GoMateMapControls({
    super.key,
    required this.onSearch,
    required this.onTripPicker,
    required this.onLocation,
    required this.showCompass,
    required this.bearing,
    required this.onCompass,
    this.onChat,
    this.pinButton,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gap = (width * 0.028).clamp(9.0, 12.0).toDouble();
    final size = GoMateMapControlButton.sizeFor(width);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Slot la bàn luôn tồn tại để search / trip / location không bị dịch.
        SizedBox(
          width: size,
          height: size,
          child: IgnorePointer(
            ignoring: !showCompass,
            child: AnimatedOpacity(
              opacity: showCompass ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: GoMateMapControlButton(
                icon: LucideIcons.compass,
                onTap: onCompass,
                rotationRadians: -bearing * math.pi / 180,
              ),
            ),
          ),
        ),
        SizedBox(height: gap),
        GoMateMapControlButton(icon: LucideIcons.search, onTap: onSearch),
        SizedBox(height: gap),
        GoMateMapControlButton(
          icon: LucideIcons.calendar_days,
          onTap: onTripPicker,
        ),
        SizedBox(height: gap),
        GoMateMapControlButton(
          icon: LucideIcons.locate_fixed,
          onTap: onLocation,
        ),
        if (pinButton != null) ...[SizedBox(height: gap), pinButton!],
        if (onChat != null) ...[
          SizedBox(height: gap),
          GoMateMapControlButton(
            icon: LucideIcons.message_circle,
            onTap: onChat,
          ),
        ],
      ],
    );
  }
}

class GoMateMapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double rotationRadians;
  final String? tooltip;
  final bool selected;
  final bool loading;

  const GoMateMapControlButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.rotationRadians = 0,
    this.tooltip,
    this.selected = false,
    this.loading = false,
  });

  static double sizeFor(double width) {
    return (width * 0.093).clamp(34.0, 39.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final size = sizeFor(width);
    final iconSize = (width * 0.050).clamp(18.0, 21.0).toDouble();

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryText : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: AppColors.primaryIcon.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: loading
              ? SizedBox.square(
                  dimension: iconSize,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Transform.rotate(
                  angle: rotationRadians,
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: selected ? Colors.white : AppColors.primaryText,
                  ),
                ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
