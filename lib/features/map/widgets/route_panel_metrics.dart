import 'package:flutter/material.dart';

/// Route editor và route summary dùng cùng một chiều cao outer panel.
/// Panel không tăng theo số điểm; danh sách bên trong tự scroll.
double goMateRoutePanelHeight(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return (width * 0.64).clamp(232.0, 252.0).toDouble();
}
