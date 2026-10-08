import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';

class GoMateMapControls extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onLocation;

  /// Chỉ truyền callback khi thực sự đang có lịch trình ghim.
  /// Null => không render nút lịch trình.
  final VoidCallback? onPinnedTrip;

  const GoMateMapControls({
    super.key,
    required this.onSearch,
    required this.onLocation,
    this.onPinnedTrip,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gap = (width * 0.030).clamp(10.0, 13.0).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapControlButton(
          icon: LucideIcons.search,
          onTap: onSearch,
        ),
        SizedBox(height: gap),
        _MapControlButton(
          icon: LucideIcons.locate_fixed,
          onTap: onLocation,
        ),
        if (onPinnedTrip != null) ...[
          SizedBox(height: gap),
          _MapControlButton(
            icon: LucideIcons.calendar_days,
            onTap: onPinnedTrip!,
          ),
        ],
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapControlButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final size = (width * 0.108).clamp(40.0, 45.0).toDouble();
    final iconSize = (width * 0.050).clamp(18.5, 21.5).toDouble();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.055),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: iconSize,
            color: AppColors.primaryIcon,
          ),
        ),
      ),
    );
  }
}
