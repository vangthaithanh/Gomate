import 'package:flutter/material.dart';

/// Adds unread state without changing the icon's layout or hit area.
class GoMateUnreadIndicator extends StatelessWidget {
  final Widget child;
  final bool unread;
  const GoMateUnreadIndicator({
    super.key,
    required this.child,
    required this.unread,
  });

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      if (unread)
        Positioned(
          top: -2,
          right: -3,
          child: Semantics(
            label: 'Có mục chưa đọc',
            child: Container(
              key: const ValueKey('gomate-unread-dot'),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFE53935),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
    ],
  );
}
