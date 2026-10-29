import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/app_colors.dart';

class GoMateImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String title;

  const GoMateImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.title = 'Ảnh',
  });

  static Future<void> open(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
    String title = 'Ảnh',
  }) {
    if (images.isEmpty) return Future.value();

    final safeIndex = initialIndex.clamp(0, images.length - 1).toInt();
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoMateImageViewer(
          images: images,
          initialIndex: safeIndex,
          title: title,
        ),
      ),
    );
  }

  @override
  State<GoMateImageViewer> createState() => _GoMateImageViewerState();
}

class _GoMateImageViewerState extends State<GoMateImageViewer> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: (width * 0.20).clamp(70.0, 86.0).toDouble(),
              child: Row(
                children: [
                  SizedBox(width: width * 0.025),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(
                        (width * 0.030).clamp(10.0, 13.0).toDouble(),
                      ),
                      child: Icon(
                        LucideIcons.chevron_left,
                        size: (width * 0.070).clamp(24.0, 29.0).toDouble(),
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: (width * 0.10).clamp(34.0, 40.0).toDouble(),
                        height: (width * 0.10).clamp(34.0, 40.0).toDouble(),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0x1A0A43A8),
                          border: Border.all(color: AppColors.grayBorder),
                        ),
                        child: Icon(
                          LucideIcons.user_round,
                          size: (width * 0.055).clamp(19.0, 22.0).toDouble(),
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: width * 0.010),
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: (width * 0.040).clamp(14.0, 16.0).toDouble(),
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(width: width * 0.15),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.images.length,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (context, index) {
                      return Center(
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: _ViewerImage(path: widget.images[index]),
                        ),
                      );
                    },
                  ),
                  if (_index > 0)
                    Positioned(
                      left: width * 0.035,
                      child: _PageArrow(
                        icon: LucideIcons.chevron_left,
                        onTap: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                      ),
                    ),
                  if (_index < widget.images.length - 1)
                    Positioned(
                      right: width * 0.035,
                      child: _PageArrow(
                        icon: LucideIcons.chevron_right,
                        onTap: () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: width * 0.020,
                bottom: (width * 0.045).clamp(14.0, 20.0).toDouble(),
              ),
              child: Text(
                '${_index + 1}/${widget.images.length}',
                style: TextStyle(
                  fontSize: (width * 0.039).clamp(14.0, 16.0).toDouble(),
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _PageArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PageArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final size = (width * 0.11).clamp(38.0, 46.0).toDouble();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.72),
          ),
          child: Icon(
            icon,
            size: (width * 0.055).clamp(19.0, 23.0).toDouble(),
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _ViewerImage extends StatelessWidget {
  final String path;

  const _ViewerImage({required this.path});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: size.width,
        height: size.height * 0.72,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    if (path.startsWith('/') || path.startsWith('file://')) {
      final filePath = path.startsWith('file://')
          ? Uri.parse(path).toFilePath()
          : path;
      return Image.file(
        File(filePath),
        width: size.width,
        height: size.height * 0.72,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    return Image.asset(
      path,
      width: size.width,
      height: size.height * 0.72,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    return const Center(
      child: Icon(
        LucideIcons.image,
        size: 52,
        color: AppColors.grayText,
      ),
    );
  }
}
