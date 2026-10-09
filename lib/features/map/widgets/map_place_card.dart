import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../models/map_place.dart';
import '../utils/cloudinary_image_url.dart';

/// Card địa điểm nổi trực tiếp trên marker đã chọn.
///
/// V19 không tự vẽ thêm map-pin bên dưới. Phần mũi nhọn trắng của card
/// trỏ thẳng vào marker Mapbox thật, còn vị trí card được MapScreen cập nhật
/// theo `pixelForCoordinate()` mỗi khi camera di chuyển.
class GoMateMapPlaceCard extends StatelessWidget {
  final GoMateMapPlace place;
  final bool canAddToTrip;

  /// Tọa độ X của mũi trỏ tính từ mép trái card.
  /// Dùng khi card phải clamp vào mép màn hình nhưng vẫn cần trỏ đúng marker.
  final double pointerCenterX;

  final VoidCallback onClose;
  final VoidCallback onToggleSaved;
  final VoidCallback onOpenDetail;
  final VoidCallback? onAddToTrip;

  const GoMateMapPlaceCard({
    super.key,
    required this.place,
    required this.canAddToTrip,
    required this.pointerCenterX,
    required this.onClose,
    required this.onToggleSaved,
    required this.onOpenDetail,
    this.onAddToTrip,
  });

  static double cardWidthFor(double screenWidth) {
    return (screenWidth * 0.455).clamp(164.0, 188.0).toDouble();
  }

  static double cardHeightFor(double screenWidth) {
    // V21: compact hơn V20, không còn khoảng trắng lớn phía dưới.
    return (screenWidth * 0.345)
        .clamp(124.0, 138.0)
        .toDouble();
  }

  static double pointerWidthFor(double screenWidth) {
    return (screenWidth * 0.040).clamp(14.0, 17.0).toDouble();
  }

  static double pointerHeightFor(double screenWidth) {
    return (screenWidth * 0.024).clamp(8.0, 10.0).toDouble();
  }

  static double totalHeightFor(double screenWidth) {
    return cardHeightFor(screenWidth) + pointerHeightFor(screenWidth);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = cardWidthFor(width);
    final cardHeight = cardHeightFor(width);
    final pointerWidth = pointerWidthFor(width);
    final pointerHeight = pointerHeightFor(width);
    final imageSize = (width * 0.140).clamp(50.0, 58.0).toDouble();
    final actionIconSize =
        (width * 0.058).clamp(20.0, 23.0).toDouble();

    final safePointerCenter = pointerCenterX
        .clamp(pointerWidth, cardWidth - pointerWidth)
        .toDouble();

    return SizedBox(
      width: cardWidth,
      height: cardHeight + pointerHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            width: cardWidth,
            height: cardHeight,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpenDetail,
                borderRadius: BorderRadius.circular(10),
                child: Ink(
                  padding: EdgeInsets.fromLTRB(
                    (width * 0.026).clamp(9.0, 11.0).toDouble(),
                    (width * 0.020).clamp(7.0, 9.0).toDouble(),
                    (width * 0.020).clamp(7.0, 9.0).toDouble(),
                    (width * 0.016).clamp(5.0, 7.0).toDouble(),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.grayBorder.withOpacity(0.55),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.13),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: AppColors.primaryIcon.withOpacity(0.06),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: SizedBox.square(
                                dimension: imageSize,
                                child: _thumbnail(),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: (width * 0.012)
                                .clamp(4.0, 5.0)
                                .toDouble(),
                          ),
                          Text(
                            place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: (width * 0.032)
                                  .clamp(11.5, 13.5)
                                  .toDouble(),
                              height: 1.0,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(
                            height: (width * 0.014)
                                .clamp(5.0, 6.0)
                                .toDouble(),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: onToggleSaved,
                                customBorder: const CircleBorder(),
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: Icon(
                                    place.isSaved
                                        ? Icons.favorite_rounded
                                        : LucideIcons.heart,
                                    size: actionIconSize,
                                    color: place.isSaved
                                        ? AppColors.primaryIcon
                                        : AppColors.grayText,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: (width * 0.030)
                                    .clamp(10.0, 13.0)
                                    .toDouble(),
                              ),
                              if (canAddToTrip)
                                InkWell(
                                  onTap: onAddToTrip,
                                  customBorder: const CircleBorder(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: Icon(
                                      LucideIcons.circle_plus,
                                      size: actionIconSize,
                                      color: AppColors.grayText,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: InkWell(
                          onTap: onClose,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              LucideIcons.x,
                              size: (width * 0.038)
                                  .clamp(14.0, 15.5)
                                  .toDouble(),
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Mũi trắng gắn card vào marker thật trên Mapbox.
          Positioned(
            top: cardHeight - 1,
            left: safePointerCenter - pointerWidth / 2,
            child: PhysicalShape(
              clipper: const _DownTriangleClipper(),
              color: Colors.white,
              elevation: 2.5,
              shadowColor: Colors.black.withOpacity(0.18),
              child: SizedBox(
                width: pointerWidth,
                height: pointerHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnail() {
    final raw = place.thumbnailUrl ??
        (place.mediaUrls.isEmpty ? null : place.mediaUrls.first);

    if (raw == null || raw.trim().isEmpty) {
      return _fallback();
    }

    return Image.network(
      cloudinaryMapThumbnailUrl(raw),
      fit: BoxFit.cover,
      cacheWidth: 220,
      cacheHeight: 220,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    return const ColoredBox(
      color: AppColors.blue50,
      child: Center(
        child: Icon(
          LucideIcons.map_pin,
          size: 26,
          color: AppColors.primaryIcon,
        ),
      ),
    );
  }
}

class _DownTriangleClipper extends CustomClipper<Path> {
  const _DownTriangleClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _DownTriangleClipper oldClipper) => false;
}
