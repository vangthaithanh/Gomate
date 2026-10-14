import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';

/// Understands asset images, URL images and temporary user-selected XFile paths.
/// TODO(BACKEND-CREATE-POST): use uploaded CDN thumbnail/video-player URLs after
/// server media upload succeeds. video-file:* intentionally shows a placeholder;
/// no video player dependency is introduced in this UI-only patch.
class GoMatePostMediaWidget extends StatelessWidget {
  final String source;
  final BoxFit fit;
  const GoMatePostMediaWidget({super.key, required this.source,
    this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final isVideo = source.startsWith('video-file:') ||
        source.startsWith('video-demo:');
    final raw = source.startsWith('video-demo:')
        ? source.substring('video-demo:'.length)
        : source;
    Widget image;
    if (raw.startsWith('video-file:')) {
      image = _fallback();
    } else if (raw.startsWith('file://')) {
      image = Image.file(File.fromUri(Uri.parse(raw)), fit: fit,
        errorBuilder: (_, __, ___) => _fallback());
    } else if (raw.startsWith('https://') || raw.startsWith('http://')) {
      image = Image.network(raw, fit: fit,
        errorBuilder: (_, __, ___) => _fallback());
    } else if (raw.isNotEmpty) {
      image = Image.asset(raw, fit: fit,
        errorBuilder: (_, __, ___) => _fallback());
    } else {
      image = _fallback();
    }
    return Stack(fit: StackFit.expand, children: [
      image,
      if (isVideo) ...[
        Container(color: Colors.black26),
        const Center(child: Icon(LucideIcons.play,
          size: 40, color: Colors.white)),
      ],
    ]);
  }

  Widget _fallback() => const ColoredBox(
    color: Color(0xFFE8EDF6),
    child: Center(child: Icon(LucideIcons.image, color: AppColors.grayText)),
  );
}
