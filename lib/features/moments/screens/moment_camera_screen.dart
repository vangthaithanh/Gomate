import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../data/moments_repository.dart';
import '../models/moment_models.dart';
import '../widgets/moment_image_frame.dart';
import 'moment_viewer_screen.dart';
import 'my_moments_screen.dart';

/// Màn "Ảnh khoảnh khắc".
///
/// Lưu ý UI:
/// - Không dùng artboard/frame 375x715 cố định.
/// - Không scale cả màn theo một hệ số chung.
/// - Mọi kích thước chính lấy từ constraints thực tế của màn hình.
/// - Nút chụp/flash/đổi camera hiện chỉ là UI, chưa nối camera backend.
/// - Thumbnail có badge ở góc phải là KHOẢNH KHẮC CHƯA XEM CỦA BẠN BÈ.
class MomentCameraScreen extends StatelessWidget {
  final MomentsRepository repository;

  const MomentCameraScreen({
    super.key,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            double c(double value, double min, double max) {
              return value.clamp(min, max).toDouble();
            }

            final horizontalPadding = c(width * 0.053, 16, 22);
            final headerHeight = c(width * 0.155, 54, 66);
            final iconSize = c(width * 0.064, 22, 25);
            final titleSize = c(width * 0.043, 15, 17);

            // Ảnh chính ưu tiên gần 80% chiều rộng như mockup, nhưng nếu màn
            // thấp thì tự thu theo chiều cao để không overflow.
            final availableBodyHeight = math.max(0.0, height - headerHeight);
            final previewSize = math.min(
              width * 0.80,
              availableBodyHeight * 0.60,
            );

            final shutterOuter = c(width * 0.213, 72, 84);
            final shutterInner = shutterOuter * 0.72;
            final controlIcon = c(width * 0.064, 22, 26);

            return AnimatedBuilder(
              animation: repository,
              builder: (context, _) {
                final unseen = repository.availableFriendMoments;

                return Column(
                  children: [
                    SizedBox(
                      height: headerHeight,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(left: horizontalPadding),
                              child: _CircleIconButton(
                                icon: LucideIcons.x,
                                iconSize: iconSize,
                                onTap: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ),
                          Text(
                            'Ảnh khoảnh khắc',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontSize: titleSize,
                              height: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: EdgeInsets.only(right: horizontalPadding),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _CircleIconButton(
                                    icon: LucideIcons.layout_grid,
                                    iconSize: iconSize,
                                    onTap: () => _openLibrary(context),
                                  ),
                                  SizedBox(width: c(width * 0.012, 4, 6)),
                                  if (unseen.isNotEmpty)
                                    _UnseenFriendsPreview(
                                      items: unseen,
                                      size: c(width * 0.115, 40, 48),
                                      onTap: () => _openUnseenFriends(
                                        context,
                                        unseen.first,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: Column(
                          children: [
                            // Giữ preview gần header như mockup; không để chiều cao
                            // màn hình quyết định khoảng trống phía trên.
                            SizedBox(height: c(width * 0.20, 68, 80)),

                            Center(
                              child: MomentImageFrame.placeholder(
                                size: previewSize,
                              ),
                            ),

                            SizedBox(
                              height: c(
                                width * 0.16,
                                52,
                                64,
                              ),
                            ),

                            SizedBox(
                              width: math.min(width * 0.74, 360),
                              height: shutterOuter,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _CircleIconButton(
                                    icon: LucideIcons.zap_off,
                                    iconSize: controlIcon,
                                    onTap: () {},
                                  ),
                                  InkWell(
                                    onTap: () {},
                                    customBorder: const CircleBorder(),
                                    child: Container(
                                      width: shutterOuter,
                                      height: shutterOuter,
                                      padding: EdgeInsets.all(
                                        c(width * 0.011, 4, 5),
                                      ),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: AppColors.primaryGradient,
                                      ),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                        alignment: Alignment.center,
                                        child: Container(
                                          width: shutterInner,
                                          height: shutterInner,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0x4DDADADA),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  _CircleIconButton(
                                    icon: LucideIcons.refresh_cw,
                                    iconSize: controlIcon,
                                    onTap: () {},
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),

                            SizedBox(height: c(height * 0.018, 10, 16)),

                            SizedBox(height: c(height * 0.045, 18, 34)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openLibrary(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyMomentsScreen(repository: repository),
      ),
    );
  }

  Future<void> _openUnseenFriends(
    BuildContext context,
    MomentItem first,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MomentViewerScreen(
          repository: repository,
          startUserId: first.ownerId,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback onTap;
  final Color color;

  const _CircleIconButton({
    required this.icon,
    required this.iconSize,
    required this.onTap,
    this.color = AppColors.black,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: iconSize + 18,
        height: iconSize + 18,
        child: Center(
          child: Icon(icon, size: iconSize, color: color),
        ),
      ),
    );
  }
}

class _UnseenFriendsPreview extends StatelessWidget {
  final List<MomentItem> items;
  final double size;
  final VoidCallback onTap;

  const _UnseenFriendsPreview({
    required this.items,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = items.length;
    final thumbSize = size * 0.64;
    final radius = size * 0.20;

    Widget thumb(String asset) {
      return Container(
        width: thumbSize,
        height: thumbSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.blue50,
            alignment: Alignment.center,
            child: Icon(
              LucideIcons.image,
              size: thumbSize * 0.45,
              color: AppColors.grayText,
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (count > 1)
              Positioned(
                right: 0,
                top: size * 0.11,
                child: Transform.rotate(
                  angle: -0.07,
                  child: thumb(items[1].imageAsset),
                ),
              ),
            Positioned(
              left: 0,
              top: 0,
              child: Transform.rotate(
                angle: -0.035,
                child: thumb(items.first.imageAsset),
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                width: size * 0.42,
                height: size * 0.42,
                decoration: BoxDecoration(
                  color: AppColors.primaryIcon,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.18,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
