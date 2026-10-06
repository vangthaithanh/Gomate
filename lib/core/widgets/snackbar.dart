import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/app_colors.dart';

class GoMateSnackBar {
  const GoMateSnackBar._();

  static const Duration defaultDuration = Duration(seconds: 10);

  /// Thông báo nhanh, không khóa thao tác nền và tự biến mất.
  ///
  /// [bottomOffset]:
  /// - Trong MainShell hiện tại: nên dùng khoảng 90 để tránh navbar overlay.
  /// - Màn không có navbar: có thể dùng 12-16.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> show(
    BuildContext context, {
    required String message,
    Duration duration = defaultDuration,
    double bottomOffset = 16,
    String? actionLabel,
    VoidCallback? onAction,
    IconData icon = LucideIcons.circle_check,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final width = MediaQuery.sizeOf(context).width;

    double c(double value, double min, double max) {
      return value.clamp(min, max).toDouble();
    }

    final horizontalMargin = c(width * 0.053, 16, 22);
    final radius = c(width * 0.040, 13, 16);
    final iconSize = c(width * 0.053, 19, 22);
    final fontSize = c(width * 0.0345, 12.5, 14);
    final actionFontSize = c(width * 0.0345, 12.5, 14);
    final minHeight = c(width * 0.107, 40, 44);

    messenger.hideCurrentSnackBar();

    return messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        dismissDirection: DismissDirection.down,
        padding: EdgeInsets.zero,
        margin: EdgeInsets.fromLTRB(
          horizontalMargin,
          0,
          horizontalMargin,
          bottomOffset,
        ),
        content: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          decoration: BoxDecoration(
            color: const Color(0xE6828282),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: c(width * 0.033, 11, 14),
            vertical: c(width * 0.018, 6, 8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: iconSize,
                color: Colors.white,
              ),
              SizedBox(width: c(width * 0.020, 7, 9)),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                SizedBox(width: c(width * 0.020, 7, 10)),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      messenger.hideCurrentSnackBar();
                      onAction();
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: c(width * 0.018, 6, 8),
                        vertical: c(width * 0.014, 5, 7),
                      ),
                      child: Text(
                        actionLabel,
                        style: TextStyle(
                          fontSize: actionFontSize,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showUndo(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    Duration duration = defaultDuration,
    double bottomOffset = 16,
  }) {
    return show(
      context,
      message: message,
      duration: duration,
      bottomOffset: bottomOffset,
      actionLabel: 'Hoàn tác',
      onAction: onUndo,
    );
  }
}
