import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';

enum PostActionResult {
  notInterested,
  report,
}

class PostActionContent extends StatelessWidget {
  const PostActionContent({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        double c(double value, double min, double max) {
          return value.clamp(min, max).toDouble();
        }

        final rowHeight = c(width * 0.155, 52, 58);
        final iconSize = c(width * 0.066, 22, 25);
        final fontSize = c(width * 0.044, 15, 16.5);
        final innerPadding = c(width * 0.032, 10, 13);
        final iconTextGap = c(width * 0.042, 14, 17);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PostActionRow(
              height: rowHeight,
              horizontalPadding: innerPadding,
              icon: LucideIcons.circle_x,
              iconSize: iconSize,
              iconColor: AppColors.black,
              label: 'Không quan tâm',
              fontSize: fontSize,
              textColor: AppColors.black,
              iconTextGap: iconTextGap,
              onTap: () {
                Navigator.of(context).pop(
                  PostActionResult.notInterested,
                );
              },
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: innerPadding),
              child: const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.grayBorder,
              ),
            ),
            _PostActionRow(
              height: rowHeight,
              horizontalPadding: innerPadding,
              icon: LucideIcons.message_square_warning,
              iconSize: iconSize,
              iconColor: AppColors.primaryText,
              label: 'Báo cáo',
              fontSize: fontSize,
              textColor: AppColors.primaryText,
              iconTextGap: iconTextGap,
              onTap: () {
                Navigator.of(context).pop(
                  PostActionResult.report,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _PostActionRow extends StatelessWidget {
  final double height;
  final double horizontalPadding;
  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final String label;
  final double fontSize;
  final Color textColor;
  final double iconTextGap;
  final VoidCallback onTap;

  const _PostActionRow({
    required this.height,
    required this.horizontalPadding,
    required this.icon,
    required this.iconSize,
    required this.iconColor,
    required this.label,
    required this.fontSize,
    required this.textColor,
    required this.iconTextGap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: iconSize,
                  color: iconColor,
                ),
                SizedBox(width: iconTextGap),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
