import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../models/map_place.dart';
import '../utils/cloudinary_image_url.dart';

class GoMatePlaceBottomSheet extends StatelessWidget {
  final GoMateMapPlace place;
  final VoidCallback onClose;
  final VoidCallback onToggleSaved;
  final VoidCallback onDirections;
  final VoidCallback onOpenDetail;

  const GoMatePlaceBottomSheet({
    super.key,
    required this.place,
    required this.onClose,
    required this.onToggleSaved,
    required this.onDirections,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final radius = (width * 0.038).clamp(14.0, 16.0).toDouble();
    final horizontal = (width * 0.044).clamp(15.0, 18.0).toDouble();
    final vertical = (width * 0.040).clamp(14.0, 17.0).toDouble();
    final imageSize = (width * 0.205).clamp(74.0, 84.0).toDouble();

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.fromLTRB(horizontal, vertical, horizontal, vertical),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.040),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onOpenDetail,
              borderRadius: BorderRadius.circular(radius),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: imageSize,
                      height: imageSize,
                      child: _thumbnail(),
                    ),
                  ),
                  SizedBox(width: width * 0.032),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: width * 0.004),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize:
                                  (width * 0.039).clamp(14.0, 16.0).toDouble(),
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryText,
                              height: 1.12,
                            ),
                          ),
                          SizedBox(height: width * 0.016),
                          Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size:
                                    (width * 0.038).clamp(14.0, 16.0).toDouble(),
                                color: AppColors.primaryIcon,
                              ),
                              SizedBox(width: width * 0.008),
                              Flexible(
                                child: Text(
                                  '${place.rating.toStringAsFixed(1)} (${place.reviewCount})   ${place.categoryLabel}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: (width * 0.026)
                                        .clamp(9.5, 11.0)
                                        .toDouble(),
                                    color: AppColors.grayText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: width * 0.014),
                          Text(
                            place.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize:
                                  (width * 0.025).clamp(9.3, 10.8).toDouble(),
                              color: AppColors.grayText,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: width * 0.010),
                  InkWell(
                    onTap: onClose,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(width * 0.006),
                      child: Icon(
                        LucideIcons.x,
                        size: (width * 0.052).clamp(19.0, 22.0).toDouble(),
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: width * 0.040),
            Row(
              children: [
                SizedBox(
                  width: (width * 0.31).clamp(108.0, 126.0).toDouble(),
                  child: Center(
                    child: InkWell(
                      onTap: onToggleSaved,
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: EdgeInsets.all(width * 0.012),
                        child: Icon(
                          place.isSaved
                              ? Icons.favorite_rounded
                              : LucideIcons.heart,
                          size: (width * 0.058).clamp(21.0, 24.0).toDouble(),
                          color: place.isSaved
                              ? AppColors.primaryIcon
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _GradientButton(
                    label: 'Chỉ đường',
                    onTap: onDirections,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnail() {
    final raw = place.thumbnailUrl ??
        (place.mediaUrls.isEmpty ? null : place.mediaUrls.first);

    if (raw == null) return _fallback();

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
          size: 30,
          color: AppColors.primaryIcon,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.088).clamp(34.0, 39.0).toDouble();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(height / 2),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: (width * 0.029).clamp(10.5, 12.0).toDouble(),
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
