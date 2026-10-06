import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';

class AuthTextField extends StatefulWidget {
  final String hintText;
  final IconData prefixIcon;
  final bool isPassword;

  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final bool enabled;

  const AuthTextField({
    super.key,
    required this.hintText,
    required this.prefixIcon,
    this.isPassword = false,
    this.controller,
    this.keyboardType,
    this.errorText,
    this.onChanged,
    this.textInputAction,
    this.enabled = true,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late final FocusNode _focusNode;

  bool _hasFocus = false;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode();

    _focusNode.addListener(() {
      if (!mounted) return;

      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError =
        widget.errorText != null && widget.errorText!.isNotEmpty;

    final activeColor = hasError
        ? const Color(0xFFE57373)
        : AppColors.primaryIcon;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale from the ACTUAL field width, not the whole phone width.
        // This keeps the input proportion correct when the form has a max width.
        final width = constraints.maxWidth;

        double c(double value, double min, double max) =>
            value.clamp(min, max).toDouble();

        final radius = c(width * 0.045, 12, 15);
        final fieldHeight = c(width * 0.165, 46, 50);
        final iconSize = c(width * 0.064, 18, 20);
        final fontSize = c(width * 0.046, 13, 14);
        final hintSize = c(width * 0.042, 12, 13);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: fieldHeight,
              decoration: BoxDecoration(
                color: _hasFocus
                    ? Colors.white
                    : AppColors.grayBackground,
                borderRadius: BorderRadius.circular(radius),

                // Trạng thái ban đầu KHÔNG có viền.
                // Chỉ focus hoặc error mới hiện viền.
                border: (_hasFocus || hasError)
                    ? Border.all(
                  color: activeColor,
                  width: 1.4,
                )
                    : null,

                boxShadow: _hasFocus && !hasError
                    ? [
                  BoxShadow(
                    color: AppColors.primaryIcon.withOpacity(0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
                    : const [],
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                onChanged: widget.onChanged,
                obscureText:
                widget.isPassword ? _obscureText : false,
                cursorColor: AppColors.primaryIcon,
                style: TextStyle(
                  fontSize: fontSize,
                  color: AppColors.black,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(
                    fontSize: hintSize,
                    color: AppColors.grayText,
                  ),
                  prefixIcon: Icon(
                    widget.prefixIcon,
                    size: iconSize,
                    color: hasError
                        ? const Color(0xFFE57373)
                        : _hasFocus
                        ? AppColors.primaryIcon
                        : AppColors.grayText,
                  ),
                  suffixIcon: widget.isPassword
                      ? IconButton(
                    onPressed: widget.enabled
                        ? () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    }
                        : null,
                    icon: Icon(
                      _obscureText
                          ? LucideIcons.eye_off
                          : LucideIcons.eye,
                      size: iconSize,
                      color: hasError
                          ? const Color(0xFFE57373)
                          : _hasFocus
                          ? AppColors.primaryIcon
                          : AppColors.grayText,
                    ),
                  )
                      : null,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: fieldHeight * 0.31,
                  ),
                ),
              ),
            ),

            if (hasError) ...[
              SizedBox(
                height: c(width * 0.012, 4, 5),
              ),
              Padding(
                padding: EdgeInsets.only(
                  left: c(width * 0.012, 4, 5),
                ),
                child: Text(
                  widget.errorText!,
                  style: TextStyle(
                    fontSize: c(width * 0.029, 10.5, 12),
                    height: 1.25,
                    color: const Color(0xFFE05A5A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
