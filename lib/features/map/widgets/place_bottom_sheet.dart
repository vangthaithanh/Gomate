import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/map_place.dart';
import '../theme/map_ui_tokens.dart';

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
    return Container(
      decoration: GoMateMapUi.floatingPanel(context),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _icon(place.category),
                  size: 36,
                  color: AppColors.blue500,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: GoMateMapUi.title(context),
                    ),

                    const SizedBox(height: 4),

                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 17,
                          color: Color(0xFFFFB547),
                        ),

                        const SizedBox(width: 3),

                        Text(
                          '${place.rating.toStringAsFixed(1)} (${place.reviewCount})',
                          style: GoMateMapUi.caption(context),
                        ),

                        const SizedBox(width: 8),

                        Flexible(
                          child: Text(
                            place.categoryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoMateMapUi.caption(context),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      place.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoMateMapUi.caption(context),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: onClose,
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              IconButton(
                onPressed: onToggleSaved,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.blue50,
                  foregroundColor: AppColors.blue500,
                ),
                icon: Icon(
                  place.isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: OutlinedButton(
                  onPressed: onOpenDetail,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.blue500,
                    side: const BorderSide(
                      color: AppColors.blue500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: const Text(
                    'Chi tiết',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: onDirections,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  icon: const Icon(
                    Icons.directions_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Chỉ đường',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _icon(GoMatePlaceCategory c) {
    switch (c) {
      case GoMatePlaceCategory.attraction:
        return Icons.photo_camera_rounded;
      case GoMatePlaceCategory.cafe:
        return Icons.local_cafe_rounded;
      case GoMatePlaceCategory.food:
        return Icons.restaurant_rounded;
      case GoMatePlaceCategory.nature:
        return Icons.park_rounded;
      case GoMatePlaceCategory.shopping:
        return Icons.shopping_bag_rounded;
    }
  }
}