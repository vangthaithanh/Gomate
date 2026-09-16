import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<_StoryItem> _stories = const [
    _StoryItem(
      name: 'Bạn',
      image: 'assets/images/story_me.jpg',
      isSelf: true,
    ),
    _StoryItem(
      name: 'An',
      image: 'assets/images/story_1.jpg',
    ),
    _StoryItem(
      name: 'Linh',
      image: 'assets/images/story_2.jpg',
    ),
    _StoryItem(
      name: 'Nam',
      image: 'assets/images/story_3.jpg',
    ),
    _StoryItem(
      name: 'Vy',
      image: 'assets/images/story_4.jpg',
    ),
  ];

  final List<_MiniTripItem> _miniTrips = const [
    _MiniTripItem(
      title: 'Morning Mood',
      subtitle: 'Đi nhẹ, ảnh đẹp',
      image: 'assets/images/home_trip_1.jpg',
    ),
    _MiniTripItem(
      title: 'Day Mood',
      subtitle: 'Cuối tuần thư giãn',
      image: 'assets/images/home_trip_2.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),

          // MainShell đã có bottom navigation nên chỉ cần
          // chừa một khoảng nhỏ ở cuối nội dung.
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            28,
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),

              const SizedBox(height: 18),

              _buildDalatCard(),

              const SizedBox(height: 24),

              _buildSectionTitle('Story'),

              const SizedBox(height: 12),

              _buildStoryRow(),

              const SizedBox(height: 24),

              _buildSectionTitle('Gợi ý cho bạn'),

              const SizedBox(height: 12),

              _buildMainFeatureCard(),

              const SizedBox(height: 24),

              _buildSectionTitle('Khám phá nhanh'),

              const SizedBox(height: 12),

              _buildMiniTripRow(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return SizedBox(
      height: 44,

      child: Row(
        children: [
          _buildHeaderIconButton(
            icon: Icons.search_rounded,
            onTap: () {},
          ),

          const Spacer(),

          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              children: [
                TextSpan(
                  text: 'Go',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: 'Mate',
                  style: TextStyle(
                    color: AppColors.blue500,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          _buildHeaderIconButton(
            icon: Icons.notifications_none_rounded,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),

      child: SizedBox(
        width: 44,
        height: 44,

        child: Center(
          child: Icon(
            icon,
            size: 24,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DALAT / WEATHER
  // ============================================================

  Widget _buildDalatCard() {
    return SizedBox(
      width: double.infinity,
      height: 196,

      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),

        child: Stack(
          fit: StackFit.expand,
          children: [
            const _SafeAssetImage(
              path: 'assets/images/home_dalat.jpg',
              fit: BoxFit.cover,
              fallbackIcon: Icons.landscape_outlined,
            ),

            // Overlay nhẹ để chữ dễ đọc.
            Container(
              color: Colors.black.withOpacity(0.18),
            ),

            // Location ở trên - tách riêng để tránh overflow.
            Positioned(
              top: 14,
              left: 14,

              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(16),
                ),

                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Colors.white,
                    ),

                    SizedBox(width: 4),

                    Text(
                      'Đà Lạt',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Nội dung dưới - dùng Positioned để tránh sọc overflow.
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,

              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    'Thời tiết Đà Lạt',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'Lên kế hoạch cho chuyến đi đầu tiên.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(
                      fontSize: 18,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 9),

                  Align(
                    alignment: Alignment.centerLeft,

                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(17),

                      child: InkWell(
                        onTap: () {},
                        borderRadius: BorderRadius.circular(17),

                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 7,
                          ),

                          child: Text(
                            'Khám phá ngay',

                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(String title) {
    return Text(
      title,

      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }

  // ============================================================
  // STORY
  // ============================================================

  Widget _buildStoryRow() {
    return SizedBox(
      height: 96,

      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),

        itemCount: _stories.length,

        separatorBuilder: (_, __) {
          return const SizedBox(width: 14);
        },

        itemBuilder: (
            context,
            index,
            ) {
          final item = _stories[index];

          return SizedBox(
            width: 66,

            child: Column(
              children: [
                SizedBox(
                  width: 64,
                  height: 64,

                  child: Stack(
                    clipBehavior: Clip.none,

                    children: [
                      Container(
                        width: 64,
                        height: 64,

                        padding: const EdgeInsets.all(2.5),

                        decoration: BoxDecoration(
                          shape: BoxShape.circle,

                          border: Border.all(
                            color: item.isSelf
                                ? AppColors.blue200
                                : AppColors.blue300,

                            width: item.isSelf ? 1.5 : 2,
                          ),
                        ),

                        child: ClipOval(
                          child: _SafeAssetImage(
                            path: item.image,
                            fit: BoxFit.cover,

                            fallbackIcon: item.isSelf
                                ? Icons.person_outline_rounded
                                : Icons.person_rounded,
                          ),
                        ),
                      ),

                      if (item.isSelf)
                        Positioned(
                          right: -1,
                          bottom: -1,

                          child: Container(
                            width: 23,
                            height: 23,

                            decoration: BoxDecoration(
                              color: AppColors.blue500,
                              shape: BoxShape.circle,

                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),

                            child: const Icon(
                              Icons.add_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // FEATURE CARD
  // ============================================================

  Widget _buildMainFeatureCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: AppColors.blue50.withOpacity(0.45),
        borderRadius: BorderRadius.circular(24),
      ),

      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),

            child: SizedBox(
              width: double.infinity,
              height: 188,

              child: const _SafeAssetImage(
                path: 'assets/images/home_feature.jpg',
                fit: BoxFit.cover,
                fallbackIcon: Icons.travel_explore_rounded,
              ),
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Night Mood',
            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 18,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 7),

          const Text(
            'Một chuyến đi nhẹ nhàng, nhiều khoảnh khắc đẹp và lịch trình vừa đủ.',
            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              _buildInfoChip(
                icon: Icons.place_outlined,
                text: 'Đà Lạt',
              ),

              const SizedBox(width: 8),

              _buildInfoChip(
                icon: Icons.schedule_rounded,
                text: '2N1Đ',
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 48,

            child: ElevatedButton(
              onPressed: () {},

              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.blue500,
                foregroundColor: Colors.white,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),

              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Text(
                    'Xem gợi ý',

                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  SizedBox(width: 7),

                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: AppColors.blue500,
          ),

          const SizedBox(width: 5),

          Text(
            text,

            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MINI CARD
  // ============================================================

  Widget _buildMiniTripRow() {
    return Row(
      children: List.generate(
        _miniTrips.length,
            (index) {
          final item = _miniTrips[index];

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == _miniTrips.length - 1
                    ? 0
                    : 10,
              ),

              child: Container(
                padding: const EdgeInsets.all(10),

                decoration: BoxDecoration(
                  color: AppColors.blue50.withOpacity(0.40),
                  borderRadius: BorderRadius.circular(20),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),

                      child: SizedBox(
                        width: double.infinity,
                        height: 100,

                        child: _SafeAssetImage(
                          path: item.image,
                          fit: BoxFit.cover,
                          fallbackIcon: Icons.image_outlined,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// SAFE ASSET IMAGE
// ============================================================================

class _SafeAssetImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final IconData fallbackIcon;

  const _SafeAssetImage({
    required this.path,
    required this.fit,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      fit: fit,

      errorBuilder: (
          context,
          error,
          stackTrace,
          ) {
        return Container(
          color: AppColors.blue50,
          alignment: Alignment.center,

          child: Icon(
            fallbackIcon,
            size: 24,
            color: AppColors.blue300,
          ),
        );
      },

      frameBuilder: (
          context,
          child,
          frame,
          wasSynchronouslyLoaded,
          ) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }

        return Container(
          color: AppColors.blue50,
        );
      },
    );
  }
}

// ============================================================================
// MODELS
// ============================================================================

class _StoryItem {
  final String name;
  final String image;
  final bool isSelf;

  const _StoryItem({
    required this.name,
    required this.image,
    this.isSelf = false,
  });
}

class _MiniTripItem {
  final String title;
  final String subtitle;
  final String image;

  const _MiniTripItem({
    required this.title,
    required this.subtitle,
    required this.image,
  });
}
