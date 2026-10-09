import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';

/// Cụm nút nổi bên phải Map.
///
/// Layout V19:
/// - slot la bàn luôn được giữ chỗ ở phía trên;
/// - search / itinerary / current-location luôn ở đúng một vị trí;
/// - chat chỉ hiện với Map nhóm và nằm ở slot cuối;
/// - compass/chat ẩn hiện nhưng KHÔNG làm 3 nút chính bị đẩy lên/xuống.
class GoMateMapControls extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onTripPicker;
  final VoidCallback onLocation;

  final VoidCallback? onChat;

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
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gap = (width * 0.028).clamp(9.0, 12.0).toDouble();
    final size = _MapControlButton.sizeFor(width);

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
              child: _MapControlButton(
                icon: LucideIcons.compass,
                onTap: onCompass,
                rotationRadians: -bearing * math.pi / 180,
              ),
            ),
          ),
        ),
        SizedBox(height: gap),
        _MapControlButton(
          icon: LucideIcons.search,
          onTap: onSearch,
        ),
        SizedBox(height: gap),
        _MapControlButton(
          icon: LucideIcons.calendar_days,
          onTap: onTripPicker,
        ),
        SizedBox(height: gap),
        _MapControlButton(
          icon: LucideIcons.locate_fixed,
          onTap: onLocation,
        ),
        SizedBox(height: gap),

        // Chat có slot riêng ở cuối. Việc ẩn/hiện chat không ảnh hưởng
        // vị trí 3 nút chính phía trên.
        SizedBox(
          width: size,
          height: size,
          child: IgnorePointer(
            ignoring: onChat == null,
            child: AnimatedOpacity(
              opacity: onChat == null ? 0 : 1,
              duration: const Duration(milliseconds: 160),
              child: _MapControlButton(
                icon: LucideIcons.message_circle,
                onTap: onChat ?? () {},
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double rotationRadians;

  const _MapControlButton({
    required this.icon,
    required this.onTap,
    this.rotationRadians = 0,
  });

  static double sizeFor(double width) {
    return (width * 0.093).clamp(34.0, 39.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final size = sizeFor(width);
    final iconSize = (width * 0.050).clamp(18.0, 21.0).toDouble();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 1,
            ),
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
          child: Transform.rotate(
            angle: rotationRadians,
            child: Icon(
              icon,
              size: iconSize,
              color: AppColors.primaryText,
            ),
          ),
        ),
      ),
    );
  }
}
