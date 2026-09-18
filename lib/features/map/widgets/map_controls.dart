import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class GoMateMapControls extends StatelessWidget {
  final VoidCallback onCreateTrip;
  final VoidCallback onTrip;
  final VoidCallback onResetNorth;
  final VoidCallback onLocation;

  const GoMateMapControls({
    super.key,
    required this.onCreateTrip,
    required this.onTrip,
    required this.onResetNorth,
    required this.onLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // LỊCH TRÌNH
        _button(
          icon: Icons.calendar_month_outlined,
          onTap: onCreateTrip,
          showPlus: true,
        ),

        const SizedBox(height: 10),

        // ROUTE / TRIP
        _button(
          icon: Icons.route_rounded,
          onTap: onTrip,
        ),

        const SizedBox(height: 10),

        // HƯỚNG BẢN ĐỒ
        _button(
          icon: Icons.explore_outlined,
          onTap: onResetNorth,
        ),

        const SizedBox(height: 10),

        // VỊ TRÍ HIỆN TẠI
        _button(
          icon: Icons.my_location_rounded,
          onTap: onLocation,
        ),
      ],
    );
  }

  Widget _button({
    required IconData icon,
    required VoidCallback onTap,
    bool showPlus = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  icon,
                  size: 22,
                  color: AppColors.textPrimary,
                ),
              ),

              if (showPlus)
                Positioned(
                  right: 7,
                  bottom: 7,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.blue500,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}