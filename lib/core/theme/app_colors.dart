import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // =========================
  // PRIMARY
  // =========================
  static const Color primaryText = Color(0xFF08327C);
  static const Color primaryIcon = Color(0xFF0A43A8);

  static const Color primaryStart = Color(0xFF0A43A8);
  static const Color primaryMiddle = Color(0xFF0C6ECF);
  static const Color primaryEnd = Color(0xFF0D8AE8);

  // =========================
  // NEUTRAL
  // =========================
  static const Color grayText = Color(0xFF828282);
  static const Color grayBorder = Color(0xFFDADADA);
  static const Color grayBackground = Color(0xFFF7F7F7);

  static const Color white = Colors.white;
  static const Color black = Color(0xFF111111);

  // =========================
  // SEMANTIC
  // =========================
  static const Color background = white;
  static const Color surface = white;

  static const Color textPrimary = primaryText;
  static const Color textSecondary = grayText;

  static const Color iconPrimary = primaryIcon;
  static const Color iconSecondary = grayText;

  static const Color fieldBackground = grayBackground;
  static const Color fieldBorder = grayBorder;

  // =========================
  // COMPATIBILITY
  // để các màn hình cũ không vỡ compile
  // =========================
  static const Color blue50 = Color(0xFFEFF5FF);
  static const Color blue100 = Color(0xFFD8E8FF);
  static const Color blue200 = Color(0xFFBDD7FF);
  static const Color blue300 = Color(0xFF8CB9F5);
  static const Color blue500 = primaryStart;

  // =========================
  // GRADIENT
  // =========================
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      primaryStart,
      primaryMiddle,
      primaryEnd,
    ],
  );

  // =========================
  // SHADOW
  // =========================
  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x1F000000), // 12%
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x1F0B3E8A), // 12%
      offset: Offset(0, 8),
      blurRadius: 28,
      spreadRadius: 0,
    ),
  ];
}