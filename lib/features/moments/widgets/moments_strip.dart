import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../data/moments_repository.dart';
import '../models/moment_models.dart';
import '../screens/moment_camera_screen.dart';
import '../screens/moment_viewer_screen.dart';

/// Thanh Khoảnh khắc trên Home.
///
/// Visual metrics được giữ đúng theo Home đã chốt trên master:
/// - active outer: width * 0.160, clamp 56..64
/// - normal avatar: width * 0.133, clamp 47..54
/// - item width: width * 0.224, clamp 76..88
/// - separator: width * 0.016
///
/// Chỉ thay data/interaction sang MomentsRepository; không redesign Home.
class MomentsStrip extends StatelessWidget {
  final MomentsRepository repository;

  const MomentsStrip({
    super.key,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        double c(double value, double min, double max) {
          return value.clamp(min, max).toDouble();
        }

        // Giữ nguyên tỷ lệ từ Home đã chốt.
        final activeSize = c(width * 0.160, 56, 64);
        final normalSize = c(width * 0.133, 47, 54);
        final itemWidth = c(width * 0.224, 76, 88);
        final stripHeight = activeSize + c(width * 0.085, 30, 36);
        final horizontalPadding = c(width * 0.053, 16, 22);
        final labelGap = width * 0.015;
        final labelFontSize = _font(width, 12);

        return AnimatedBuilder(
          animation: repository,
          builder: (context, _) {
            final items = repository.stripItems;

            return SizedBox(
              height: stripHeight,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => SizedBox(width: width * 0.016),
                itemBuilder: (context, index) {
                  final item = items[index];

                  return SizedBox(
                    width: itemWidth,
                    child: Column(
                      children: [
                        InkWell(
                          onTap: item.isSelf || item.hasAvailableMoment
                              ? () => _openItem(context, item)
                              : null,
                          customBorder: const CircleBorder(),
                          child: _HomeMomentAvatar(
                            imagePath: item.avatarAsset,
                            activeSize: activeSize,
                            normalSize: normalSize,
                            highlighted:
                                item.hasAvailableMoment && !item.isSelf,
                            showAddBadge: item.isSelf,
                          ),
                        ),
                        SizedBox(height: labelGap),
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: labelFontSize,
                            height: 1.1,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openItem(BuildContext context, MomentFriendPreview item) async {
    if (item.isSelf) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MomentCameraScreen(repository: repository),
        ),
      );
      return;
    }

    // Chỉ bạn bè còn khoảnh khắc chưa xem mới mở được.
    if (!item.hasAvailableMoment) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MomentViewerScreen(
          repository: repository,
          startUserId: item.userId,
        ),
      ),
    );
  }
}

/// Bản dynamic của _GradientAvatar trong Home master.
/// Kích thước/spacing cố ý giữ giống bản Home cũ để feature Moments không
/// làm thay đổi UI đã chốt.
class _HomeMomentAvatar extends StatelessWidget {
  final String imagePath;
  final double activeSize;
  final double normalSize;
  final bool highlighted;
  final bool showAddBadge;

  const _HomeMomentAvatar({
    required this.imagePath,
    required this.activeSize,
    required this.normalSize,
    this.highlighted = false,
    this.showAddBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final ring = activeSize * 0.052;
    final whiteGap = activeSize * 0.052;
    final badgeSize = activeSize * 0.31;

    // activeSize luôn là frame ngoài, nên bật/tắt ring không đổi layout.
    return SizedBox(
      width: activeSize,
      height: activeSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (highlighted)
            Container(
              width: activeSize,
              height: activeSize,
              padding: EdgeInsets.all(ring),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
              ),
              child: Container(
                padding: EdgeInsets.all(whiteGap),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: _AvatarCore(imagePath: imagePath),
              ),
            )
          else
            SizedBox(
              width: normalSize,
              height: normalSize,
              child: _AvatarCore(imagePath: imagePath),
            ),

          if (showAddBadge)
            Positioned(
              right: activeSize * 0.01,
              bottom: activeSize * 0.03,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryIcon,
                  border: Border.all(
                    color: Colors.white,
                    width: activeSize * 0.034,
                  ),
                ),
                child: Icon(
                  LucideIcons.plus,
                  size: badgeSize * 0.52,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarCore extends StatelessWidget {
  final String imagePath;

  const _AvatarCore({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE7EBF3),
        border: Border.all(color: AppColors.grayBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFFE7EBF3),
          alignment: Alignment.center,
          child: Icon(
            LucideIcons.user,
            size: 24,
            color: AppColors.grayText,
          ),
        ),
      ),
    );
  }
}

double _font(double width, double baseAt360) {
  final value = baseAt360 * (width / 360);
  return value.clamp(baseAt360 * 0.93, baseAt360 * 1.12).toDouble();
}
