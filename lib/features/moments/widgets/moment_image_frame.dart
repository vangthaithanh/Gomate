import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';

/// Khung ảnh Moment dùng chung.
///
/// Widget chỉ nhận [size] từ layout cha. Chính layout cha quyết định kích thước
/// dựa trên constraints thật của màn hình; widget này không biết và không ép
/// bất kỳ artboard/frame thiết kế cố định nào.
///
/// Shape dùng superellipse (squircle) để có góc cong dài/mềm như mockup, thay
/// vì rounded rectangle 4 góc thông thường.
class MomentImageFrame extends StatelessWidget {
  final double size;
  final String? imageAsset;
  final Widget? child;
  final BoxFit fit;
  final Color backgroundColor;
  final bool showShadow;
  final double opacity;

  const MomentImageFrame({
    super.key,
    required this.size,
    this.imageAsset,
    this.child,
    this.fit = BoxFit.cover,
    this.backgroundColor = const Color(0x4DDADADA),
    this.showShadow = true,
    this.opacity = 1,
  }) : assert(imageAsset != null || child != null);

  const MomentImageFrame.placeholder({
    super.key,
    required this.size,
    this.backgroundColor = const Color(0x4DDADADA),
    this.showShadow = true,
  })  : imageAsset = null,
        child = null,
        fit = BoxFit.cover,
        opacity = 1;

  @override
  Widget build(BuildContext context) {
    final fallbackIconSize = (size * 0.10).clamp(22.0, 34.0).toDouble();
    final elevation = showShadow
        ? (size * 0.026).clamp(6.0, 10.0).toDouble()
        : 0.0;

    final content = child ??
        (imageAsset == null
            ? ColoredBox(color: backgroundColor)
            : Image.asset(
                imageAsset!,
                fit: fit,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: backgroundColor,
                  child: Center(
                    child: Icon(
                      LucideIcons.image,
                      size: fallbackIconSize,
                      color: AppColors.grayText,
                    ),
                  ),
                ),
              ));

    return Opacity(
      opacity: opacity,
      child: SizedBox.square(
        dimension: size,
        child: PhysicalShape(
          clipper: const MomentSquircleClipper(),
          clipBehavior: Clip.antiAlias,
          color: backgroundColor,
          elevation: elevation,
          shadowColor: const Color(0x300A43A8),
          child: content,
        ),
      ),
    );
  }
}

/// n ≈ 4 tạo dáng squircle: cạnh tương đối đầy nhưng góc cong sâu/mềm.
class MomentSquircleClipper extends CustomClipper<Path> {
  final double exponent;

  const MomentSquircleClipper({this.exponent = 4.0});

  @override
  Path getClip(Size size) {
    final path = Path();
    final a = size.width / 2;
    final b = size.height / 2;
    final cx = a;
    final cy = b;
    final power = 2 / exponent;

    const samples = 120;
    for (var i = 0; i <= samples; i++) {
      final t = (i / samples) * math.pi * 2;
      final cosT = math.cos(t);
      final sinT = math.sin(t);
      final x = cx +
          a *
              (cosT < 0 ? -1 : 1) *
              math.pow(cosT.abs(), power).toDouble();
      final y = cy +
          b *
              (sinT < 0 ? -1 : 1) *
              math.pow(sinT.abs(), power).toDouble();

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant MomentSquircleClipper oldClipper) {
    return oldClipper.exponent != exponent;
  }
}
