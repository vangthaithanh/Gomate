import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class AuthTextField extends StatefulWidget {
  final String hintText;
  final IconData prefixIcon;
  final bool isPassword;

  // Bổ sung để dùng validation cho Login/Register.
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

    final borderColor = hasError
        ? const Color(0xFFE57373)
        : _hasFocus
        ? AppColors.blue500
        : AppColors.fieldBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: _hasFocus
                ? Colors.white
                : AppColors.fieldBackground,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: borderColor,
              width: (_hasFocus || hasError) ? 1.5 : 1,
            ),
            boxShadow: _hasFocus
                ? [
              BoxShadow(
                color: AppColors.blue300.withOpacity(0.18),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ]
                : [],
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
            cursorColor: AppColors.blue500,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              prefixIcon: Icon(
                widget.prefixIcon,
                size: 19,
                color: hasError
                    ? const Color(0xFFE57373)
                    : _hasFocus
                    ? AppColors.blue500
                    : AppColors.textSecondary,
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
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 19,
                  color: _hasFocus
                      ? AppColors.blue500
                      : AppColors.textSecondary,
                ),
              )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
              ),
            ),
          ),
        ),

        if (hasError) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              widget.errorText!,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.25,
                color: Color(0xFFE05A5A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
