import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/app_colors.dart';

/// An interactive, non-modal notification preview anchored to the top.
/// It does not dim/block the rest of the application.  One visible item at a
/// time; route handling stays in the caller, not in this reusable shell.
/// TODO(BACKEND-NOTIFICATIONS): call show() from the global notification event
/// listener when realtime delivery is available. Do not create a second toast.
class GoMateNotificationPopup {
  GoMateNotificationPopup._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  static void show(
    BuildContext context, {
    required String message,
    String? avatar,
    required VoidCallback onTap,
    Duration duration = const Duration(seconds: 7),
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    dismiss();
    final top = MediaQuery.paddingOf(context).top + 10;
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = (width * .045).clamp(14.0, 20.0).toDouble();
    _entry = OverlayEntry(
      builder: (context) => Positioned(
        top: top,
        left: horizontal,
        right: horizontal,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () {
              dismiss();
              onTap();
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: (width * .030).clamp(11.0, 14.0).toDouble(),
                vertical: (width * .027).clamp(9.0, 12.0).toDouble(),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFDADADA),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.elevatedShadow,
              ),
              child: Row(children: [
                _PopupAvatar(source: avatar),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: (width * .0335).clamp(12.0, 14.0).toDouble(),
                      color: AppColors.black,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
    _timer = Timer(duration, dismiss);
  }
}

class _PopupAvatar extends StatelessWidget {
  final String? source;
  const _PopupAvatar({this.source});
  @override
  Widget build(BuildContext context) => Container(
    width: 36, height: 36,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xFFE7EBF3),
      border: Border.all(color: Colors.white),
    ),
    child: source == null || source!.isEmpty
      ? const Icon(LucideIcons.user_round, color: Colors.white, size: 25)
      : Image.asset(source!, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
            const Icon(LucideIcons.user_round, color: Colors.white, size: 25)),
  );
}
