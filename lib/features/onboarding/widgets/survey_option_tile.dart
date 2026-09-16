import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class SurveyOptionTile extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const SurveyOptionTile({
    super.key,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 2,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? AppColors.blue500
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? AppColors.blue500
                      : const Color(0xFF9AA5AC),
                  width: 1.3,
                ),
              ),
              child: selected
                  ? const Icon(
                Icons.check_rounded,
                size: 14,
                color: Colors.white,
              )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: selected
                      ? AppColors.blue500
                      : AppColors.textPrimary,
                ),
                child: Text(text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}