import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<_MomentItem> _moments = const [
    _MomentItem(
      name: 'Bạn',
      image: 'assets/images/home/moment_me.jpg',
      isSelf: true,
    ),
    _MomentItem(
      name: 'ChiThanh',
      image: 'assets/images/home/moment_chithanh.jpg',
      highlighted: true,
    ),
    _MomentItem(
      name: 'Thune',
      image: 'assets/images/home/moment_thune.jpg',
    ),
    _MomentItem(
      name: 'Buji',
      image: 'assets/images/home/moment_buji.jpg',
    ),
    _MomentItem(
      name: 'Bum',
      image: 'assets/images/home/moment_4.jpg',
    ),
  ];

  final List<_HomePost> _posts = const [
    _HomePost(
      authorName: 'Thune',
      location: 'Thành phố Hồ Chí Minh',
      avatar: 'assets/images/home/moment_thune.jpg',
      caption:
      '#Hashtag Caption CaptionCaption Caption Caption CaptionCaption',
      media: [
        'assets/images/home/post_1_1.jpg',
        'assets/images/home/post_1_2.jpg',
        'assets/images/home/post_1_3.jpg',
      ],
      likeCount: 4,
      commentCount: 4,
    ),
    _HomePost(
      authorName: 'ChiThanh',
      location: 'Thành phố Hồ Chí Minh',
      avatar: 'assets/images/home/moment_chithanh.jpg',
      caption:
      '#Hashtag Caption CaptionCaption Caption Caption CaptionCaption',
      media: [
        'assets/images/home/post_2_1.jpg',
        'assets/images/home/post_2_2.jpg',
      ],
      likeCount: 4,
      commentCount: 4,
    ),
    _HomePost(
      authorName: 'Buji',
      location: 'Đà Nẵng',
      avatar: 'assets/images/home/moment_buji.jpg',
      caption:
      '#Hashtag Một chuyến đi đẹp với rất nhiều khoảnh khắc đáng nhớ.',
      media: [
        'assets/images/home/post_3_1.jpg',
        'assets/images/home/post_3_2.jpg',
      ],
      likeCount: 8,
      commentCount: 2,
    ),
    _HomePost(
      authorName: 'Thune',
      location: 'Thành phố Hồ Chí Minh',
      avatar: 'assets/images/home/moment_thune.jpg',
      caption:
      '#Hashtag Caption CaptionCaption Caption Caption CaptionCaption',
      media: [
        'assets/images/home/post_4_1.jpg',
      ],
      likeCount: 3,
      commentCount: 1,
    ),
  ];

  final List<_PlaceSuggestion> _placeSuggestions = const [
    _PlaceSuggestion(
      title: 'Cầu Vàng, Bà Nà Hills',
      subtitle: 'Đà Nẵng',
      rating: 4.8,
      image: 'assets/images/home/place_1.jpg',
    ),
    _PlaceSuggestion(
      title: 'Động Phong Nha, Kẻ Bàng',
      subtitle: 'Quảng Bình',
      rating: 4.8,
      image: 'assets/images/home/place_2.jpg',
    ),
    _PlaceSuggestion(
      title: 'Hồ Tuyền Lâm',
      subtitle: 'Đà Lạt',
      rating: 4.8,
      image: 'assets/images/home/place_3.jpg',
    ),
  ];

  final List<_UserSuggestion> _userSuggestions = const [
    _UserSuggestion(
      name: 'Thune',
      mutualText: '2 Bạn chung',
      avatar: 'assets/images/home/user_1.jpg',
    ),
    _UserSuggestion(
      name: 'Thune',
      mutualText: '2 Bạn chung',
      avatar: 'assets/images/home/user_2.jpg',
    ),
    _UserSuggestion(
      name: 'Thune',
      mutualText: '2 Bạn chung',
      avatar: 'assets/images/home/user_3.jpg',
    ),
  ];

  bool _hasHighlightedMoment(String name) {
    return _moments.any(
          (moment) => moment.name == name && moment.highlighted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final ui = _HomeMetrics.fromWidth(
              constraints.maxWidth,
            );

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                top: ui.topPadding,
                bottom: ui.bottomPadding,
              ),
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui.contentPadding,
                  ),
                  child: _HomeHeader(ui: ui),
                ),

                SizedBox(height: ui.gapSmall),

                _MomentStrip(
                  items: _moments,
                  ui: ui,
                ),

                SizedBox(height: ui.gapMedium),

                _FeedPostCard(
                  post: _posts[0],
                  highlighted:
                  _hasHighlightedMoment(_posts[0].authorName),
                  ui: ui,
                ),

                SizedBox(height: ui.gapSection),

                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui.contentPadding,
                  ),
                  child: _PlaceSuggestionSection(
                    items: _placeSuggestions,
                    ui: ui,
                  ),
                ),

                SizedBox(height: ui.gapSection),

                _FeedPostCard(
                  post: _posts[1],
                  highlighted:
                  _hasHighlightedMoment(_posts[1].authorName),
                  ui: ui,
                ),

                SizedBox(height: ui.gapSection),

                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui.contentPadding,
                  ),
                  child: _UserSuggestionSection(
                    items: _userSuggestions,
                    ui: ui,
                  ),
                ),

                SizedBox(height: ui.gapSection),

                _FeedPostCard(
                  post: _posts[2],
                  highlighted:
                  _hasHighlightedMoment(_posts[2].authorName),
                  ui: ui,
                ),

                SizedBox(height: ui.gapSection),

                _FeedPostCard(
                  post: _posts[3],
                  highlighted:
                  _hasHighlightedMoment(_posts[3].authorName),
                  ui: ui,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// RESPONSIVE METRICS
// ============================================================================

class _HomeMetrics {
  final double width;

  final double contentPadding;
  final double topPadding;
  final double bottomPadding;

  final double headerHeight;
  final double headerIconSize;
  final double logoFontSize;

  final double momentActiveSize;
  final double momentNormalSize;
  final double momentItemWidth;
  final double momentStripHeight;

  final double postAvatarSize;
  final double postIconSize;

  final double placeCardWidth;
  final double placeCardHeight;
  final double placeCardRadius;
  final double placeRailHeight;

  final double userCardWidth;
  final double userCardHeight;
  final double userAvatarSize;
  final double userRailHeight;

  final double gapSmall;
  final double gapMedium;
  final double gapSection;

  const _HomeMetrics({
    required this.width,
    required this.contentPadding,
    required this.topPadding,
    required this.bottomPadding,
    required this.headerHeight,
    required this.headerIconSize,
    required this.logoFontSize,
    required this.momentActiveSize,
    required this.momentNormalSize,
    required this.momentItemWidth,
    required this.momentStripHeight,
    required this.postAvatarSize,
    required this.postIconSize,
    required this.placeCardWidth,
    required this.placeCardHeight,
    required this.placeCardRadius,
    required this.placeRailHeight,
    required this.userCardWidth,
    required this.userCardHeight,
    required this.userAvatarSize,
    required this.userRailHeight,
    required this.gapSmall,
    required this.gapMedium,
    required this.gapSection,
  });

  factory _HomeMetrics.fromWidth(double width) {
    double c(double value, double min, double max) {
      return value.clamp(min, max).toDouble();
    }

    // Các tỉ lệ bên dưới lấy màn khoảng 360-390dp làm chuẩn,
    // nhưng đều có min/max để tablet không phóng quá lớn.
    final contentPadding = c(width * 0.048, 15, 22);

    final momentActive = c(width * 0.145, 52, 62);
    final momentNormal = momentActive * 0.84;
    final momentItemWidth = c(width * 0.185, 64, 78);

    final placeCardWidth = c(width * 0.335, 118, 148);
    final placeCardHeight = placeCardWidth * 1.62;

    // Friend suggestion cards are intentionally larger than before.
    // ~31% of screen width matches the visual proportion in the mockup
    // while still allowing the next card to peek in and signal horizontal scroll.
    final userCardWidth = c(width * 0.31, 108, 142);
    final userCardHeight = userCardWidth * 1.43;

    return _HomeMetrics(
      width: width,

      contentPadding: contentPadding,
      topPadding: c(width * 0.025, 8, 12),
      // Navbar overlay nên cần khoảng scroll cuối.
      bottomPadding: c(width * 0.30, 108, 132),

      headerHeight: c(width * 0.12, 44, 52),
      headerIconSize: c(width * 0.057, 20, 24),
      logoFontSize: c(width * 0.063, 23, 27),

      momentActiveSize: momentActive,
      momentNormalSize: momentNormal,
      momentItemWidth: momentItemWidth,
      momentStripHeight:
      momentActive + c(width * 0.085, 30, 36),

      postAvatarSize: c(width * 0.105, 38, 44),
      postIconSize: c(width * 0.05, 18, 21),

      placeCardWidth: placeCardWidth,
      placeCardHeight: placeCardHeight,
      placeCardRadius: c(placeCardWidth * 0.14, 16, 21),
      placeRailHeight:
      placeCardHeight + c(width * 0.045, 16, 20),

      userCardWidth: userCardWidth,
      userCardHeight: userCardHeight,
      userAvatarSize: userCardWidth * 0.57,
      userRailHeight:
      userCardHeight + c(width * 0.055, 18, 24),

      gapSmall: c(width * 0.027, 9, 12),
      gapMedium: c(width * 0.045, 15, 19),
      gapSection: c(width * 0.06, 21, 27),
    );
  }
}

// ============================================================================
// HEADER
// ============================================================================

class _HomeHeader extends StatelessWidget {
  final _HomeMetrics ui;

  const _HomeHeader({
    required this.ui,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ui.headerHeight,
      child: Row(
        children: [
          _HeaderButton(
            icon: LucideIcons.search,
            iconSize: ui.headerIconSize,
            onTap: () {},
          ),

          const Spacer(),

          Text(
            'GoMate',
            style: TextStyle(
              fontSize: ui.logoFontSize,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: AppColors.primaryText,
            ),
          ),

          const Spacer(),

          _HeaderButton(
            icon: LucideIcons.bell,
            iconSize: ui.headerIconSize,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: iconSize + 22,
        height: iconSize + 22,
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: AppColors.black,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MOMENTS
// ============================================================================

class _MomentStrip extends StatelessWidget {
  final List<_MomentItem> items;
  final _HomeMetrics ui;

  const _MomentStrip({
    required this.items,
    required this.ui,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ui.momentStripHeight,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(
          horizontal: ui.contentPadding,
        ),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(
          width: ui.width * 0.016,
        ),
        itemBuilder: (context, index) {
          final item = items[index];

          return SizedBox(
            width: ui.momentItemWidth,
            child: Column(
              children: [
                _GradientAvatar(
                  imagePath: item.image,
                  activeSize: ui.momentActiveSize,
                  normalSize: ui.momentNormalSize,
                  highlighted: item.highlighted,
                  showAddBadge: item.isSelf,
                ),
                SizedBox(height: ui.width * 0.015),
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _font(ui.width, 12),
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
  }
}

// ============================================================================
// POST
// ============================================================================

class _FeedPostCard extends StatefulWidget {
  final _HomePost post;
  final bool highlighted;
  final _HomeMetrics ui;

  const _FeedPostCard({
    required this.post,
    required this.highlighted,
    required this.ui,
  });

  @override
  State<_FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<_FeedPostCard> {
  late final PageController _pageController;
  int _currentPage = 0;

  List<String> get _media =>
      widget.post.media.take(12).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final ui = widget.ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ------------------------------------------------------------
        // Metadata có padding
        // ------------------------------------------------------------
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ui.contentPadding,
          ),
          child: Row(
            children: [
              _GradientAvatar(
                imagePath: post.avatar,
                activeSize: ui.postAvatarSize,
                normalSize: ui.postAvatarSize * 0.88,
                highlighted: widget.highlighted,
              ),

              SizedBox(width: ui.width * 0.025),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: TextStyle(
                        fontSize: _font(ui.width, 13.5),
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                    SizedBox(height: ui.width * 0.009),
                    Text(
                      post.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _font(ui.width, 11.5),
                        height: 1.1,
                        color: AppColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),

              InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: ui.postAvatarSize * 0.85,
                  height: ui.postAvatarSize * 0.85,
                  child: Center(
                    child: Icon(
                      LucideIcons.ellipsis_vertical,
                      size: ui.postIconSize,
                      color: AppColors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: ui.width * 0.018),

        // ------------------------------------------------------------
        // Caption có padding
        // ------------------------------------------------------------
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ui.contentPadding,
          ),
          child: _PostCaption(
            text: post.caption,
            width: ui.width,
          ),
        ),

        SizedBox(height: ui.width * 0.025),

        // ------------------------------------------------------------
        // ẢNH FULL-BLEED
        //
        // Không Padding, không ClipRRect, không margin hai bên.
        // AspectRatio 1:1 nên tự co theo mọi màn hình.
        // ------------------------------------------------------------
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: _media.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return _SafeAssetImage(
                path: _media[index],
                fit: BoxFit.cover,
              );
            },
          ),
        ),

        if (_media.length > 1) ...[
          SizedBox(height: ui.width * 0.02),
          _MediaIndicator(
            count: _media.length,
            currentIndex: _currentPage,
            width: ui.width,
          ),
        ],

        SizedBox(height: ui.width * 0.019),

        // ------------------------------------------------------------
        // Action có padding
        // ------------------------------------------------------------
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ui.contentPadding,
          ),
          child: Row(
            children: [
              _ActionIcon(
                icon: LucideIcons.heart,
                text: '${post.likeCount}',
                iconSize: ui.postIconSize,
                width: ui.width,
              ),

              SizedBox(width: ui.width * 0.046),

              _ActionIcon(
                icon: LucideIcons.message_circle,
                text: '${post.commentCount}',
                iconSize: ui.postIconSize,
                width: ui.width,
              ),

              const Spacer(),

              Icon(
                LucideIcons.bookmark,
                size: ui.postIconSize,
                color: AppColors.black,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PostCaption extends StatelessWidget {
  final String text;
  final double width;

  const _PostCaption({
    required this.text,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    const tag = '#Hashtag';

    if (!text.startsWith(tag)) {
      return Text(
        text,
        style: TextStyle(
          fontSize: _font(width, 12.5),
          height: 1.22,
          color: AppColors.black,
        ),
      );
    }

    final rest = text.substring(tag.length).trimLeft();

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: _font(width, 12.5),
          height: 1.22,
        ),
        children: [
          const TextSpan(
            text: '#Hashtag ',
            style: TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: rest,
            style: const TextStyle(
              color: AppColors.black,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final double width;

  const _MediaIndicator({
    required this.count,
    required this.currentIndex,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final visibleCount = count > 12 ? 12 : count;

    final normalSize =
    (width * 0.014).clamp(4.5, 6.0).toDouble();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        visibleCount,
            (index) {
          final active = index == currentIndex;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: EdgeInsets.symmetric(
              horizontal: width * 0.005,
            ),
            width: active ? normalSize * 1.35 : normalSize,
            height: active ? normalSize * 1.35 : normalSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? AppColors.primaryIcon
                  : AppColors.grayBorder,
            ),
          );
        },
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String text;
  final double iconSize;
  final double width;

  const _ActionIcon({
    required this.icon,
    required this.text,
    required this.iconSize,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: iconSize,
          color: AppColors.primaryIcon,
        ),
        SizedBox(width: width * 0.013),
        Text(
          text,
          style: TextStyle(
            fontSize: _font(width, 12.5),
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// PLACE SUGGESTIONS
// ============================================================================

class _PlaceSuggestionSection extends StatelessWidget {
  final List<_PlaceSuggestion> items;
  final _HomeMetrics ui;

  const _PlaceSuggestionSection({
    required this.items,
    required this.ui,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Gợi ý cho bạn',
          ui: ui,
        ),

        SizedBox(height: ui.width * 0.03),

        SizedBox(
          height: ui.placeRailHeight,
          child: ListView.separated(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                SizedBox(width: ui.width * 0.034),
            itemBuilder: (context, index) {
              final item = items[index];

              return Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: ui.placeCardWidth,
                  height: ui.placeCardHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      ui.placeCardRadius,
                    ),
                    boxShadow: AppColors.elevatedShadow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      ui.placeCardRadius,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _SafeAssetImage(
                          path: item.image,
                          fit: BoxFit.cover,
                        ),

                        // Chỉ gradient đọc chữ, không phải inner shadow.
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0.52, 0.73, 1],
                              colors: [
                                Colors.transparent,
                                Color(0x20000000),
                                Color(0xA5000000),
                              ],
                            ),
                          ),
                        ),

                        Positioned(
                          top: ui.placeCardWidth * 0.065,
                          right: ui.placeCardWidth * 0.065,
                          child: _RatingBadge(
                            rating: item.rating,
                            cardWidth: ui.placeCardWidth,
                          ),
                        ),

                        Positioned(
                          left: ui.placeCardWidth * 0.08,
                          right: ui.placeCardWidth * 0.08,
                          bottom: ui.placeCardWidth * 0.08,
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: _font(ui.width, 10.5),
                                  height: 1.12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(
                                height: ui.placeCardWidth * 0.018,
                              ),
                              Text(
                                item.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: _font(ui.width, 9.5),
                                  height: 1.1,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final double rating;
  final double cardWidth;

  const _RatingBadge({
    required this.rating,
    required this.cardWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: cardWidth * 0.045,
        vertical: cardWidth * 0.028,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(
          cardWidth * 0.075,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '★',
            style: TextStyle(
              fontSize: cardWidth * 0.105,
              height: 1,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryIcon,
            ),
          ),
          SizedBox(width: cardWidth * 0.02),
          Text(
            itemRating(rating),
            style: TextStyle(
              fontSize: cardWidth * 0.077,
              height: 1,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  String itemRating(double value) {
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }
}

// ============================================================================
// USER SUGGESTIONS
// ============================================================================

class _UserSuggestionSection extends StatelessWidget {
  final List<_UserSuggestion> items;
  final _HomeMetrics ui;

  const _UserSuggestionSection({
    required this.items,
    required this.ui,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Gợi ý cho bạn',
          ui: ui,
        ),

        SizedBox(height: ui.width * 0.03),

        SizedBox(
          height: ui.userRailHeight,
          child: ListView.separated(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                SizedBox(width: ui.width * 0.045),
            itemBuilder: (context, index) {
              final item = items[index];

              return Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: ui.userCardWidth,
                  height: ui.userCardHeight,
                  padding: EdgeInsets.fromLTRB(
                    ui.userCardWidth * 0.085,
                    ui.userCardWidth * 0.10,
                    ui.userCardWidth * 0.085,
                    ui.userCardWidth * 0.085,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      ui.userCardWidth * 0.125,
                    ),
                    boxShadow: AppColors.elevatedShadow,
                  ),
                  child: Column(
                    children: [
                      _SimpleAvatar(
                        imagePath: item.avatar,
                        size: ui.userAvatarSize,
                      ),

                      SizedBox(
                        height: ui.userCardWidth * 0.04,
                      ),

                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _font(ui.width, 12),
                          fontWeight: FontWeight.w600,
                          color: AppColors.black,
                        ),
                      ),

                      SizedBox(
                        height: ui.userCardWidth * 0.035,
                      ),

                      Text(
                        item.mutualText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _font(ui.width, 9),
                          color: AppColors.grayText,
                        ),
                      ),

                      const Spacer(),

                      Container(
                        width: double.infinity,
                        height: ui.userCardWidth * 0.25,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(
                            ui.userCardWidth * 0.07,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Theo dõi',
                          style: TextStyle(
                            fontSize: _font(ui.width, 9.5),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// COMMON
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final _HomeMetrics ui;

  const _SectionHeader({
    required this.title,
    required this.ui,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: _font(ui.width, 13),
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {},
          child: Text(
            'Xem tất cả',
            style: TextStyle(
              fontSize: _font(ui.width, 11),
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientAvatar extends StatelessWidget {
  final String imagePath;
  final double activeSize;
  final double normalSize;
  final bool highlighted;
  final bool showAddBadge;

  const _GradientAvatar({
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
                child: _AvatarCore(
                  imagePath: imagePath,
                ),
              ),
            )
          else
            SizedBox(
              width: normalSize,
              height: normalSize,
              child: _AvatarCore(
                imagePath: imagePath,
              ),
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

  const _AvatarCore({
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE7EBF3),
        border: Border.all(
          color: AppColors.grayBorder,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _SafeAssetImage(
        path: imagePath,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _SimpleAvatar extends StatelessWidget {
  final String imagePath;
  final double size;

  const _SimpleAvatar({
    required this.imagePath,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE7EBF3),
        border: Border.all(
          color: AppColors.grayBorder,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _SafeAssetImage(
        path: imagePath,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _SafeAssetImage extends StatelessWidget {
  final String path;
  final BoxFit fit;

  const _SafeAssetImage({
    required this.path,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      fit: fit,
      errorBuilder: (_, __, ___) {
        return Container(
          color: const Color(0xFFE7EBF3),
          alignment: Alignment.center,
          child: Icon(
            LucideIcons.image,
            size: 26,
            color: AppColors.grayText,
          ),
        );
      },
    );
  }
}

double _font(double width, double baseAt360) {
  final value = baseAt360 * (width / 360);

  return value
      .clamp(baseAt360 * 0.93, baseAt360 * 1.12)
      .toDouble();
}

// ============================================================================
// MODELS
// ============================================================================

class _MomentItem {
  final String name;
  final String image;
  final bool isSelf;
  final bool highlighted;

  const _MomentItem({
    required this.name,
    required this.image,
    this.isSelf = false,
    this.highlighted = false,
  });
}

class _HomePost {
  final String authorName;
  final String location;
  final String avatar;
  final String caption;
  final List<String> media;
  final int likeCount;
  final int commentCount;

  const _HomePost({
    required this.authorName,
    required this.location,
    required this.avatar,
    required this.caption,
    required this.media,
    required this.likeCount,
    required this.commentCount,
  });
}

class _PlaceSuggestion {
  final String title;
  final String subtitle;
  final double rating;
  final String image;

  const _PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.rating,
    required this.image,
  });
}

class _UserSuggestion {
  final String name;
  final String mutualText;
  final String avatar;

  const _UserSuggestion({
    required this.name,
    required this.mutualText,
    required this.avatar,
  });
}
