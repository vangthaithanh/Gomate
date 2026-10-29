import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/theme/app_colors.dart';

/// Swiping is limited to this bar, leaving gallery and camera gestures intact.
class ContentModeSelector extends StatefulWidget {
  final bool moment;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const ContentModeSelector({
    super.key,
    required this.moment,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<ContentModeSelector> createState() => _ContentModeSelectorState();
}

class _ContentModeSelectorState extends State<ContentModeSelector> {
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: GestureDetector(
        key: const ValueKey('content-mode-selector'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: widget.enabled ? (_) => _dragDistance = 0 : null,
        onHorizontalDragUpdate: widget.enabled
            ? (details) => _dragDistance += details.primaryDelta ?? 0
            : null,
        onHorizontalDragEnd: widget.enabled
            ? (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (_dragDistance.abs() >= 32) {
                  widget.onChanged(_dragDistance < 0);
                } else if (velocity.abs() > 80) {
                  widget.onChanged(velocity < 0);
                }
              }
            : null,
        child: Container(
          height: 58,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.grayBorder)),
          ),
          child: Row(
            children: [
              _mode(false, 'Bài viết', LucideIcons.images),
              _mode(true, 'Khoảnh khắc', LucideIcons.camera),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _mode(bool value, String label, IconData icon) {
    final selected = widget.moment == value;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: widget.enabled ? () => widget.onChanged(value) : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: selected
                        ? AppColors.primaryIcon
                        : AppColors.grayText,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.primaryText
                              : AppColors.grayText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: 24,
                height: 2,
                color: selected ? AppColors.primaryIcon : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
