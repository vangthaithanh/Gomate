import 'package:flutter/material.dart';

class GoMateMapUi {
  static const double screenPadding = 14;
  static const double cardRadius = 22;
  static const double controlSize = 46;

  static const Color route = Color(0xFF2563EB);
  static const Color ink = Color(0xFF18212D);
  static const Color muted = Color(0xFF687383);
  static const Color success = Color(0xFF22A06B);

  static BoxDecoration floatingPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: scheme.surface.withOpacity(.96),
      borderRadius: BorderRadius.circular(cardRadius),
      border: Border.all(color: scheme.outlineVariant.withOpacity(.55)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1C000000),
          blurRadius: 28,
          offset: Offset(0, 12),
        ),
      ],
    );
  }

  static TextStyle title(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -.25,
          );

  static TextStyle body(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(height: 1.25);

  static TextStyle caption(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall!.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );
}
