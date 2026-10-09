import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GoMateNameEditorContent extends StatefulWidget {
  final String title;
  final String initialValue;
  final String hintText;

  const GoMateNameEditorContent({
    super.key,
    required this.title,
    required this.initialValue,
    required this.hintText,
  });

  @override
  State<GoMateNameEditorContent> createState() =>
      _GoMateNameEditorContentState();
}

class _GoMateNameEditorContentState
    extends State<GoMateNameEditorContent> {
  late final TextEditingController _controller;

  bool get _canSave => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue,
    );
    _controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _clamp(width * 0.042, 15, 17),
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          SizedBox(height: width * 0.030),
          Container(
            height: _clamp(width * 0.105, 40, 44),
            padding: EdgeInsets.only(
              left: _clamp(width * 0.040, 13, 16),
              right: _clamp(width * 0.030, 10, 13),
            ),
            decoration: BoxDecoration(
              color: AppColors.grayBackground,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    cursorColor: AppColors.primaryIcon,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        fontSize: _clamp(
                          width * 0.032,
                          11.5,
                          13,
                        ),
                        color: AppColors.grayText,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: _clamp(
                        width * 0.032,
                        11.5,
                        13,
                      ),
                      color: Colors.black,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _canSave ? _save : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: width * 0.012,
                      vertical: width * 0.010,
                    ),
                    child: Text(
                      'Lưu',
                      style: TextStyle(
                        fontSize: _clamp(
                          width * 0.030,
                          11,
                          12,
                        ),
                        fontWeight: FontWeight.w700,
                        color: _canSave
                            ? AppColors.primaryText
                            : AppColors.grayText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static double _clamp(
    double value,
    double min,
    double max,
  ) {
    return value.clamp(min, max).toDouble();
  }
}
