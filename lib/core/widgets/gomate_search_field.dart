import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/app_colors.dart';

class GoMateSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;
  final bool showCancel;
  final bool readOnly;
  final bool autofocus;

  const GoMateSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Tìm...',
    this.onChanged,
    this.onTap,
    this.onCancel,
    this.showCancel = false,
    this.readOnly = false,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    double c(double value, double min, double max) {
      return value.clamp(min, max).toDouble();
    }

    final height = c(width * (35 / 375), 35, 40);
    final radius = c(width * (15 / 375), 15, 18);
    final horizontal = c(width * 0.035, 12, 15);
    final iconSize = c(width * (24 / 375), 21, 24);
    final iconGap = c(width * 0.020, 7, 9);
    final fontSize = c(width * (14 / 375), 13, 14);

    return Container(
      height: height,
      padding: EdgeInsets.only(
        left: horizontal,
        right: showCancel ? 4 : horizontal,
      ),
      decoration: BoxDecoration(
        color: AppColors.grayBackground,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.search,
            size: iconSize,
            color: AppColors.grayText,
          ),
          SizedBox(width: iconGap),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: readOnly,
              autofocus: autofocus,
              onTap: onTap,
              onChanged: onChanged,
              cursorColor: AppColors.primaryIcon,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: AppColors.black,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grayText,
                ),
              ),
            ),
          ),
          if (showCancel)
            InkWell(
              onTap: onCancel,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 5,
                ),
                child: Text(
                  'Huỷ',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
