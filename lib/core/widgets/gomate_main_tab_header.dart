import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GoMateMainTabHeader extends StatelessWidget {
  final String title;

  final IconData? leadingIcon;
  final VoidCallback? onLeadingTap;

  final IconData? trailingIcon;
  final Widget? trailingWidget;
  final VoidCallback? onTrailingTap;

  final Color leadingColor;
  final Color trailingColor;

  const GoMateMainTabHeader({
    super.key,
    required this.title,
    this.leadingIcon,
    this.onLeadingTap,
    this.trailingIcon,
    this.trailingWidget,
    this.onTrailingTap,
    this.leadingColor = AppColors.black,
    this.trailingColor = AppColors.black,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final ui = GoMateMainTabHeaderMetrics.fromWidth(width);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ui.horizontalPadding,
        vertical: ui.verticalPadding,
      ),
      child: SizedBox(
        height: ui.headerHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ui.titleSafeSpace,
              ),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ui.titleSize,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.25,
                  color: AppColors.primaryText,
                ),
              ),
            ),
            if (leadingIcon != null)
              Align(
                alignment: Alignment.centerLeft,
                child: _HeaderIconButton(
                  icon: leadingIcon!,
                  iconSize: ui.iconSize,
                  buttonSize: ui.buttonSize,
                  color: leadingColor,
                  onTap: onLeadingTap,
                ),
              ),
            if (trailingWidget != null || trailingIcon != null)
              Align(
                alignment: Alignment.centerRight,
                child: trailingWidget != null
                    ? _HeaderCustomButton(
                        buttonSize: ui.buttonSize,
                        onTap: onTrailingTap,
                        child: trailingWidget!,
                      )
                    : _HeaderIconButton(
                        icon: trailingIcon!,
                        iconSize: ui.iconSize,
                        buttonSize: ui.buttonSize,
                        color: trailingColor,
                        onTap: onTrailingTap,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCustomButton extends StatelessWidget {
  final double buttonSize;
  final VoidCallback? onTap;
  final Widget child;

  const _HeaderCustomButton({
    required this.buttonSize,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox.square(
        dimension: buttonSize,
        child: Center(child: child),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final double buttonSize;
  final Color color;
  final VoidCallback? onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.iconSize,
    required this.buttonSize,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox.square(
        dimension: buttonSize,
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: color,
          ),
        ),
      ),
    );
  }
}

class GoMateMainTabHeaderMetrics {
  final double horizontalPadding;
  final double verticalPadding;
  final double headerHeight;
  final double titleSize;
  final double iconSize;
  final double buttonSize;
  final double titleSafeSpace;
  final double contentGap;

  const GoMateMainTabHeaderMetrics({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.headerHeight,
    required this.titleSize,
    required this.iconSize,
    required this.buttonSize,
    required this.titleSafeSpace,
    required this.contentGap,
  });

  double get totalHeight =>
      headerHeight + (verticalPadding * 2);

  factory GoMateMainTabHeaderMetrics.fromWidth(double width) {
    double c(double value, double min, double max) {
      return value.clamp(min, max).toDouble();
    }

    return GoMateMainTabHeaderMetrics(
      horizontalPadding: c(width * 0.058, 20, 24),
      verticalPadding: c(width * 0.014, 5, 6),
      headerHeight: c(width * 0.108, 40, 44),
      titleSize: c(width * 0.054, 20, 22),
      iconSize: c(width * 0.054, 20, 22),
      buttonSize: c(width * 0.104, 38, 42),
      titleSafeSpace: c(width * 0.15, 52, 60),
      contentGap: c(width * 0.025, 9, 10),
    );
  }
}
