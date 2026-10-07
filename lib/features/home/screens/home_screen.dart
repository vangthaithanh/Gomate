import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../map/screens/place_detail_screen.dart';
import '../../map/services/location_service.dart';
import '../../recommendation/data/recommendation_repository.dart';
import '../../recommendation/models/recommendation_models.dart';
import '../../search/models/search_models.dart';
import '../../search/screens/search_screen.dart';
import '../data/post_interaction_repository.dart';
import '../models/post_interaction_models.dart';
import '../widgets/comment_sheet_content.dart';
import '../widgets/share_post_content.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../widgets/post_action_content.dart';
import '../widgets/report_reason_content.dart';
import '../../moments/data/moments_repository.dart';
import '../../moments/widgets/moments_strip.dart';

class HomeScreen extends StatefulWidget {
  /// MainShell truyền callback này để chuyển sang tab Map mà không push
  /// một MapScreen mới, nhờ đó bottom navbar vẫn giữ nguyên.
  final ValueChanged<PostLocationTarget>? onOpenPostLocation;

  /// Cho phép inject repository thật khi backend Social hoàn thiện.
  final PostInteractionRepository? interactionRepository;

  const HomeScreen({
    super.key,
    this.onOpenPostLocation,
    this.interactionRepository,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DemoMomentsRepository _momentsRepository =
      DemoMomentsRepository.instance;

  final List<_HomePost> _posts = const [
    _HomePost(
      id: 'post-1',
      authorName: 'Thune',
      location: 'Thành phố Hồ Chí Minh',
      avatar: 'assets/images/home/moment_thune.jpg',
      caption: '#Hashtag Caption CaptionCaption Caption Caption CaptionCaption',
      media: [
        'assets/images/home/post_1_1.jpg',
        'assets/images/home/post_1_2.jpg',
        'assets/images/home/post_1_3.jpg',
      ],
      likeCount: 4,
      commentCount: 4,
    ),
    _HomePost(
      id: 'post-2',
      authorName: 'ChiThanh',
      location: 'Thành phố Hồ Chí Minh',
      avatar: 'assets/images/home/moment_chithanh.jpg',
      caption: '#Hashtag Caption CaptionCaption Caption Caption CaptionCaption',
      media: [
        'assets/images/home/post_2_1.jpg',
        'assets/images/home/post_2_2.jpg',
      ],
      likeCount: 4,
      commentCount: 4,
    ),
    _HomePost(
      id: 'post-3',
      authorName: 'Buji',
      location: 'Đà Nẵng',
      avatar: 'assets/images/home/moment_buji.jpg',
      caption: '#Hashtag Một chuyến đi đẹp với rất nhiều khoảnh khắc đáng nhớ.',
      media: [
        'assets/images/home/post_3_1.jpg',
        'assets/images/home/post_3_2.jpg',
      ],
      likeCount: 8,
      commentCount: 2,
    ),
    _HomePost(
      id: 'post-4',
      authorName: 'Thune',
      location: 'Thành phố Hồ Chí Minh',
      avatar: 'assets/images/home/moment_thune.jpg',
      caption: '#Hashtag Caption CaptionCaption Caption Caption CaptionCaption',
      media: ['assets/images/home/post_4_1.jpg'],
      likeCount: 3,
      commentCount: 1,
    ),
  ];

  final RecommendationRepository _recommendationRepository =
  RecommendationRepository();
  final GoMateLocationService _locationService = GoMateLocationService();
  late final PostInteractionRepository _postInteractionRepository;
  late Future<RecommendationResponse> _recommendations;

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
    return _momentsRepository.hasAvailableMomentForName(name);
  }

  @override
  void initState() {
    super.initState();

    _momentsRepository.addListener(_onMomentsChanged);

    _postInteractionRepository =
        widget.interactionRepository ?? DemoPostInteractionRepository();

    _recommendations = _loadRecommendations();
  }

  void _onMomentsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _momentsRepository.removeListener(_onMomentsChanged);
    super.dispose();
  }

  void _retryRecommendations() {
    setState(() {
      _recommendations = _loadRecommendations();
    });
  }

  Future<RecommendationResponse> _loadRecommendations() async {
    double? latitude;
    double? longitude;
    if (_selectedContextCodes().contains('GAN_TOI')) {
      try {
        final result = await _locationService.getCurrentLocation();
        if (result.state == GoMateLocationState.ready &&
            result.position != null) {
          latitude = result.position!.latitude;
          longitude = result.position!.longitude;
        }
      } catch (_) {
        // Home recommendation must stay usable when GPS is unavailable.
      }
    }

    return _recommendationRepository.getMine(
      topK: 10,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Set<String> _selectedContextCodes() {
    final raw = AuthService.instance.user?['interestCodes'];
    final values = <String>[];
    if (raw is List) {
      values.addAll(raw.map((item) => item.toString()));
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          values.addAll(decoded.map((item) => item.toString()));
        }
      } catch (_) {
        values.addAll(raw.split(','));
      }
    }
    return values.map((value) => value.trim()).where((value) {
      return value == 'GAN_TOI' ||
          value == 'LOCAL' ||
          value == 'DANG_HOT' ||
          value == 'DI_TRONG_NGAY' ||
          value == 'CO_REVIEW' ||
          value == 'UU_TIEN_KHAC';
    }).toSet();
  }

  Future<void> _openRecommendedPlace(RecommendedPlace place) async {
    if (place.placeId <= 0) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceDetailScreen(place: _toMapPlaceUi(place)),
      ),
    );
  }

  MapPlaceUi _toMapPlaceUi(RecommendedPlace place) {
    final address = [place.address, place.district, place.province]
        .where((part) => part != null && part.trim().isNotEmpty)
        .cast<String>()
        .join(', ');

    return MapPlaceUi(
      id: place.placeId.toString(),
      name: place.name,
      subtitle: place.description ?? place.displayReason,
      address: address.isEmpty ? place.locationText : address,
      distanceText: 'Xem trên bản đồ',
      openInfo: 'Đang cập nhật',
      priceInfo: 'Đang cập nhật',
      rating: place.rating,
      reviewCount: place.reviewCount,
      likeCount: place.saveCount,
      tags: [
        place.displayCategory,
        if (place.district != null) place.district!,
        if (place.province != null) place.province!,
      ],
      imageUrl: place.thumbnailUrl,
      mediaUrls: [
        if (place.thumbnailUrl != null && place.thumbnailUrl!.isNotEmpty)
          place.thumbnailUrl!,
      ],
    );
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SearchScreen(),
      ),
    );
  }

  Future<void> _openAllRecommendations() async {
    // SearchScreen Discovery đã dùng cùng RecommendationRepository với Home,
    // nên đây chính là màn "xem tất cả" của gợi ý địa điểm.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SearchScreen(),
      ),
    );
  }

  Future<void> _openHashtag(String hashtag) async {
    final tag = hashtag.trim();
    if (tag.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          initialQuery: tag,
          initialTab: SearchTab.posts,
          initialHashtags: <String>{tag},
          startSubmitted: true,
          cancelReturnsToPrevious: true,
        ),
      ),
    );
  }

  Future<void> _openComments(_HomePost post) async {
    await GoMateBottomSheet.show(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      contentPadding: EdgeInsets.zero,
      child: CommentSheetContent(
        postId: post.id,
        repository: _postInteractionRepository,
      ),
    );
  }

  Future<void> _openShare(_HomePost post) async {
    final sentCount = await GoMateBottomSheet.show<int>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      contentPadding: EdgeInsets.zero,
      child: SharePostContent(
        postId: post.id,
        repository: _postInteractionRepository,
      ),
    );

    if (!mounted || sentCount == null || sentCount <= 0) return;

    GoMateSnackBar.show(
      context,
      message: 'Đã gửi bài viết cho $sentCount người',
      bottomOffset: 92,
      icon: LucideIcons.circle_check,
    );
  }

  void _openPostLocation(_HomePost post) {
    final callback = widget.onOpenPostLocation;
    if (callback == null) return;

    callback(
      PostLocationTarget(
        label: post.location,
        placeId: post.placeId,
        latitude: post.latitude,
        longitude: post.longitude,
      ),
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
            final ui = _HomeMetrics.fromWidth(constraints.maxWidth);

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                top: ui.topPadding,
                bottom: ui.bottomPadding,
              ),
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: ui.contentPadding),
                  child: _HomeHeader(
                    ui: ui,
                    onSearchTap: _openSearch,
                  ),
                ),

                SizedBox(height: ui.gapSmall),

                MomentsStrip(
                  repository: _momentsRepository,
                ),

                SizedBox(height: ui.gapMedium),

                _PostSlot(
                  hidden: _hiddenPostIndexes.contains(0),
                  bottomGap: ui.gapSection,
                  child: _FeedPostCard(
                    post: _posts[0],
                    highlighted: _hasHighlightedMoment(_posts[0].authorName),
                    ui: ui,
                    onMoreTap: () => _openPostActions(0),
                    onCommentTap: () => _openComments(_posts[0]),
                    onShareTap: () => _openShare(_posts[0]),
                    onHashtagTap: _openHashtag,
                    onLocationTap: () => _openPostLocation(_posts[0]),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: ui.contentPadding),
                  child: _PlaceSuggestionSection(
                    future: _recommendations,
                    ui: ui,
                    onRetry: _retryRecommendations,
                    onTap: _openRecommendedPlace,
                    onSeeAll: _openAllRecommendations,
                  ),
                ),

                SizedBox(height: ui.gapSection),

                _PostSlot(
                  hidden: _hiddenPostIndexes.contains(1),
                  bottomGap: ui.gapSection,
                  child: _FeedPostCard(
                    post: _posts[1],
                    highlighted: _hasHighlightedMoment(_posts[1].authorName),
                    ui: ui,
                    onMoreTap: () => _openPostActions(1),
                    onCommentTap: () => _openComments(_posts[1]),
                    onShareTap: () => _openShare(_posts[1]),
                    onHashtagTap: _openHashtag,
                    onLocationTap: () => _openPostLocation(_posts[1]),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: ui.contentPadding),
                  child: _UserSuggestionSection(
                    items: _userSuggestions,
                    ui: ui,
                  ),
                ),

                SizedBox(height: ui.gapSection),

                _PostSlot(
                  hidden: _hiddenPostIndexes.contains(2),
                  bottomGap: ui.gapSection,
                  child: _FeedPostCard(
                    post: _posts[2],
                    highlighted: _hasHighlightedMoment(_posts[2].authorName),
                    ui: ui,
                    onMoreTap: () => _openPostActions(2),
                    onCommentTap: () => _openComments(_posts[2]),
                    onShareTap: () => _openShare(_posts[2]),
                    onHashtagTap: _openHashtag,
                    onLocationTap: () => _openPostLocation(_posts[2]),
                  ),
                ),

                _PostSlot(
                  hidden: _hiddenPostIndexes.contains(3),
                  child: _FeedPostCard(
                    post: _posts[3],
                    highlighted: _hasHighlightedMoment(_posts[3].authorName),
                    ui: ui,
                    onMoreTap: () => _openPostActions(3),
                    onCommentTap: () => _openComments(_posts[3]),
                    onShareTap: () => _openShare(_posts[3]),
                    onHashtagTap: _openHashtag,
                    onLocationTap: () => _openPostLocation(_posts[3]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  final Set<int> _hiddenPostIndexes = <int>{};

  Future<void> _openPostActions(int postIndex) async {
    final result = await GoMateBottomSheet.show<PostActionResult>(
      context: context,
      size: GoMateBottomSheetSize.compact,
      child: const PostActionContent(),
    );

    if (!mounted || result == null) return;

    switch (result) {
      case PostActionResult.notInterested:
        _hidePost(postIndex);
        break;

      case PostActionResult.report:
        await _openReportReasons(postIndex);
        break;
    }
  }

  Future<void> _openReportReasons(int postIndex) async {
    final reason = await GoMateBottomSheet.show<ReportReason>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      child: const ReportReasonContent(),
    );

    if (!mounted || reason == null) return;

    HapticFeedback.selectionClick();

    // Hiện tại chỉ hoàn thiện flow UI.
    // `postIndex` và `reason` sẽ dùng khi nối backend Report sau này.
    GoMateSnackBar.show(
      context,
      message: 'Cảm ơn bạn đã đóng góp ý kiến',
      bottomOffset: 92,
      actionLabel: 'Xem báo cáo',
      onAction: () {
        // TODO: Mở trang / chi tiết báo cáo khi feature được triển khai.
      },
    );
  }

  void _hidePost(int postIndex) {
    if (_hiddenPostIndexes.contains(postIndex)) return;

    HapticFeedback.selectionClick();

    setState(() {
      _hiddenPostIndexes.add(postIndex);
    });

    GoMateSnackBar.showUndo(
      context,
      message: 'Đã ẩn bài viết đối với bạn',
      bottomOffset: 92,
      onUndo: () {
        if (!mounted) return;

        setState(() {
          _hiddenPostIndexes.remove(postIndex);
        });
      },
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
    final contentPadding = c(width * 0.053, 16, 22);

    // Figma reference ~375dp:
    // active moment 60, normal 50, each moment slot ~84.
    final momentActive = c(width * 0.160, 56, 64);
    final momentNormal = c(width * 0.133, 47, 54);
    final momentItemWidth = c(width * 0.224, 76, 88);

    // Figma place cards ~150 x 250 on a 375-wide frame.
    final placeCardWidth = c(width * 0.400, 132, 156);
    final placeCardHeight = placeCardWidth * (250 / 150);

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
      headerIconSize: c(width * 0.064, 22, 25),
      logoFontSize: c(width * 0.064, 23, 27),

      momentActiveSize: momentActive,
      momentNormalSize: momentNormal,
      momentItemWidth: momentItemWidth,
      momentStripHeight: momentActive + c(width * 0.085, 30, 36),

      postAvatarSize: c(width * 0.105, 38, 44),
      postIconSize: c(width * 0.05, 18, 21),

      placeCardWidth: placeCardWidth,
      placeCardHeight: placeCardHeight,
      placeCardRadius: c(placeCardWidth * 0.14, 16, 21),
      placeRailHeight: placeCardHeight + c(width * 0.045, 16, 20),

      userCardWidth: userCardWidth,
      userCardHeight: userCardHeight,
      userAvatarSize: userCardWidth * 0.57,
      userRailHeight: userCardHeight + c(width * 0.055, 18, 24),

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
  final VoidCallback onSearchTap;

  const _HomeHeader({
    required this.ui,
    required this.onSearchTap,
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
            onTap: onSearchTap,
          ),

          const Spacer(),

          Text(
            'GoMate',
            style: TextStyle(
              fontSize: ui.logoFontSize,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
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
          child: Icon(icon, size: iconSize, color: AppColors.black),
        ),
      ),
    );
  }
}

// ============================================================================
// MOMENTS
// ============================================================================

// ============================================================================
// POST
// ============================================================================
class _PostSlot extends StatelessWidget {
  final bool hidden;
  final double bottomGap;
  final Widget child;

  const _PostSlot({
    required this.hidden,
    required this.child,
    this.bottomGap = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: !hidden,
      maintainState: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          if (bottomGap > 0) SizedBox(height: bottomGap),
        ],
      ),
    );
  }
}

class _FeedPostCard extends StatefulWidget {
  final VoidCallback onMoreTap;
  final VoidCallback onCommentTap;
  final VoidCallback onShareTap;
  final ValueChanged<String> onHashtagTap;
  final VoidCallback onLocationTap;
  final _HomePost post;
  final bool highlighted;
  final _HomeMetrics ui;

  const _FeedPostCard({
    super.key,
    required this.post,
    required this.highlighted,
    required this.ui,
    required this.onMoreTap,
    required this.onCommentTap,
    required this.onShareTap,
    required this.onHashtagTap,
    required this.onLocationTap,
  });

  @override
  State<_FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<_FeedPostCard> {
  late final PageController _pageController;
  late int _likeCount;

  int _currentPage = 0;
  int _likeBurstToken = 0;

  bool _isLiked = false;
  bool _showLikeBurst = false;
  bool _isBookmarked = false;

  List<String> get _media => widget.post.media.take(12).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _likeCount = widget.post.likeCount;
  }

  void _toggleLike() {
    HapticFeedback.selectionClick();

    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
  }

  Future<void> _likeFromDoubleTap() async {
    HapticFeedback.lightImpact();

    final token = ++_likeBurstToken;

    setState(() {
      if (!_isLiked) {
        _isLiked = true;
        _likeCount += 1;
      }

      _showLikeBurst = true;
    });

    await Future<void>.delayed(
      const Duration(milliseconds: 650),
    );

    if (!mounted || token != _likeBurstToken) return;

    setState(() {
      _showLikeBurst = false;
    });
  }

  void _toggleBookmark() {
    HapticFeedback.selectionClick();

    setState(() {
      _isBookmarked = !_isBookmarked;
    });

    if (_isBookmarked) {
      GoMateSnackBar.show(
        context,
        message: 'Đã lưu vào bộ sưu tập',
        bottomOffset: 92,
        icon: LucideIcons.bookmark,
      );
    } else {
      GoMateSnackBar.show(
        context,
        message: 'Đã gỡ khỏi bộ sưu tập',
        bottomOffset: 92,
        icon: LucideIcons.circle_check,
      );
    }
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
          padding: EdgeInsets.symmetric(horizontal: ui.contentPadding),
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
                    InkWell(
                      onTap: widget.onLocationTap,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: ui.width * 0.004,
                        ),
                        child: Text(
                          post.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _font(ui.width, 11.5),
                            height: 1.1,
                            color: AppColors.grayText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              InkWell(
                onTap: widget.onMoreTap,
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
          padding: EdgeInsets.symmetric(horizontal: ui.contentPadding),
          child: _PostCaption(
            text: post.caption,
            width: ui.width,
            onHashtagTap: widget.onHashtagTap,
          ),
        ),

        SizedBox(height: ui.width * 0.025),

        // ------------------------------------------------------------
        // ẢNH FULL-BLEED
        //
        // Không Padding, không ClipRRect, không margin hai bên.
        // AspectRatio 1:1 nên tự co theo mọi màn hình.
        // ------------------------------------------------------------
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: _likeFromDoubleTap,
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
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

                IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _showLikeBurst ? 1 : 0,
                      duration: const Duration(milliseconds: 130),
                      curve: Curves.easeOut,
                      child: AnimatedScale(
                        scale: _showLikeBurst ? 1 : 0.58,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        child: _FilledHeart(
                          size: ui.width * 0.22,
                          color: AppColors.primaryIcon,
                          shadow: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
          padding: EdgeInsets.symmetric(horizontal: ui.contentPadding),
          child: Row(
            children: [
              _ActionIcon(
                icon: LucideIcons.heart,
                text: '$_likeCount',
                iconSize: ui.postIconSize,
                width: ui.width,

                // Chưa like: đen
                // Đã like: xanh
                iconColor:
                _isLiked
                    ? AppColors.primaryIcon
                    : AppColors.black,

                textColor:
                _isLiked
                    ? AppColors.primaryIcon
                    : AppColors.black,

                filled: _isLiked,
                onTap: _toggleLike,
              ),

              SizedBox(width: ui.width * 0.046),

              _ActionIcon(
                icon: LucideIcons.message_circle,
                text: '${post.commentCount}',
                iconSize: ui.postIconSize,
                width: ui.width,
                iconColor: AppColors.black,
                textColor: AppColors.black,
                onTap: widget.onCommentTap,
              ),

              SizedBox(width: ui.width * 0.042),

              InkWell(
                onTap: widget.onShareTap,
                borderRadius: BorderRadius.circular(ui.postIconSize),
                child: Padding(
                  padding: EdgeInsets.all(ui.width * 0.006),
                  child: Icon(
                    LucideIcons.send,
                    size: ui.postIconSize,
                    color: AppColors.black,
                  ),
                ),
              ),

              const Spacer(),

              InkWell(
                onTap: _toggleBookmark,
                borderRadius: BorderRadius.circular(ui.postIconSize),
                child: Padding(
                  padding: EdgeInsets.all(ui.width * 0.006),
                  child: _isBookmarked
                      ? Icon(
                    Icons.bookmark_rounded,
                    size: ui.postIconSize,
                    color: AppColors.primaryIcon,
                  )
                      : Icon(
                    LucideIcons.bookmark,
                    size: ui.postIconSize,
                    color: AppColors.black,
                  ),
                ),
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
  final ValueChanged<String> onHashtagTap;

  const _PostCaption({
    required this.text,
    required this.width,
    required this.onHashtagTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = text
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);

    return Wrap(
      spacing: width * 0.010,
      runSpacing: width * 0.004,
      children: tokens.map((token) {
        final isHashtag = token.startsWith('#');

        if (!isHashtag) {
          return Text(
            token,
            style: TextStyle(
              fontSize: _font(width, 12.5),
              height: 1.22,
              color: AppColors.black,
              fontWeight: FontWeight.w400,
            ),
          );
        }

        return InkWell(
          onTap: () => onHashtagTap(token),
          borderRadius: BorderRadius.circular(6),
          child: Text(
            token,
            style: TextStyle(
              fontSize: _font(width, 12.5),
              height: 1.22,
              color: AppColors.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }).toList(growable: false),
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

    final normalSize = (width * 0.014).clamp(4.5, 6.0).toDouble();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(visibleCount, (index) {
        final active = index == currentIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.symmetric(horizontal: width * 0.005),
          width: active ? normalSize * 1.35 : normalSize,
          height: active ? normalSize * 1.35 : normalSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.primaryIcon : AppColors.grayBorder,
          ),
        );
      }),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String text;
  final double iconSize;
  final double width;
  final Color iconColor;
  final Color textColor;
  final bool filled;
  final VoidCallback? onTap;

  const _ActionIcon({
    required this.icon,
    required this.text,
    required this.iconSize,
    required this.width,
    this.iconColor = AppColors.primaryIcon,
    this.textColor = AppColors.black,
    this.filled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (filled && icon == LucideIcons.heart)
          _FilledHeart(
            size: iconSize,
            color: iconColor,
          )
        else
          Icon(
            icon,
            size: iconSize,
            color: iconColor,
          ),
        SizedBox(width: width * 0.013),
        Text(
          text,
          style: TextStyle(
            fontSize: _font(width, 14),
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(iconSize),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: width * 0.006,
        ),
        child: content,
      ),
    );
  }
}

class _FilledHeart extends StatelessWidget {
  final double size;
  final Color color;
  final bool shadow;

  const _FilledHeart({
    required this.size,
    required this.color,
    this.shadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.favorite_rounded,
      size: size,
      color: color,
      shadows: shadow
          ? [
        Shadow(
          blurRadius: 16,
          color: Colors.white.withOpacity(0.72),
          offset: const Offset(0, 0),
        ),
        const Shadow(
          blurRadius: 10,
          color: Color(0x42000000),
          offset: Offset(0, 3),
        ),
      ]
          : null,
    );
  }
}

// ============================================================================
// PLACE SUGGESTIONS
// ============================================================================

class _PlaceSuggestionSection extends StatelessWidget {
  final Future<RecommendationResponse> future;
  final _HomeMetrics ui;
  final VoidCallback onRetry;
  final ValueChanged<RecommendedPlace> onTap;
  final VoidCallback onSeeAll;

  const _PlaceSuggestionSection({
    required this.future,
    required this.ui,
    required this.onRetry,
    required this.onTap,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Gợi ý cho bạn',
          ui: ui,
          onSeeAll: onSeeAll,
        ),

        SizedBox(height: ui.width * 0.03),

        FutureBuilder<RecommendationResponse>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingRail();
            }

            if (snapshot.hasError) {
              return _buildMessageRail(
                icon: LucideIcons.refresh_cw,
                message: 'Chưa tải được gợi ý.',
                actionLabel: 'Thử lại',
                onAction: onRetry,
              );
            }

            final places =
                snapshot.data?.items
                    .where((place) => place.placeId > 0)
                    .take(10)
                    .toList(growable: false) ??
                    const <RecommendedPlace>[];

            if (places.isEmpty) {
              return _buildMessageRail(
                icon: LucideIcons.map_pin,
                message: 'Chưa có gợi ý phù hợp.',
              );
            }

            return _buildPlaceRail(
              places
                  .map(_PlaceSuggestion.fromRecommended)
                  .toList(growable: false),
              places,
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlaceRail(
      List<_PlaceSuggestion> items,
      List<RecommendedPlace> sourcePlaces,
      ) {
    return SizedBox(
      height: ui.placeRailHeight,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: ui.width * 0.050),
        itemBuilder: (context, index) {
          final item = items[index];

          return Align(
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => onTap(sourcePlaces[index]),
              child: Container(
                width: ui.placeCardWidth,
                height: ui.placeCardHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(ui.placeCardRadius),
                  boxShadow: AppColors.elevatedShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ui.placeCardRadius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _SafeNetworkImage(url: item.imageUrl, fit: BoxFit.cover),

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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                            SizedBox(height: ui.placeCardWidth * 0.018),
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingRail() {
    return SizedBox(
      height: ui.placeRailHeight,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, __) => SizedBox(width: ui.width * 0.050),
        itemBuilder: (_, __) {
          return Container(
            width: ui.placeCardWidth,
            height: ui.placeCardHeight,
            decoration: BoxDecoration(
              color: const Color(0xFFE7EBF3),
              borderRadius: BorderRadius.circular(ui.placeCardRadius),
            ),
            alignment: Alignment.center,
            child: SizedBox(
              width: ui.placeCardWidth * 0.18,
              height: ui.placeCardWidth * 0.18,
              child: const CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageRail({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return SizedBox(
      height: ui.placeRailHeight,
      child: Container(
        height: ui.placeCardHeight,
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FB),
          borderRadius: BorderRadius.circular(ui.placeCardRadius),
          border: Border.all(color: AppColors.grayBorder),
        ),
        padding: EdgeInsets.symmetric(horizontal: ui.width * 0.04),
        child: Row(
          children: [
            Icon(icon, size: ui.width * 0.055, color: AppColors.grayText),
            SizedBox(width: ui.width * 0.03),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _font(ui.width, 12),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final double rating;
  final double cardWidth;

  const _RatingBadge({required this.rating, required this.cardWidth});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: cardWidth * 0.045,
        vertical: cardWidth * 0.028,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(cardWidth * 0.075),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: cardWidth * 0.105,
            color: AppColors.primaryIcon,
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

  const _UserSuggestionSection({required this.items, required this.ui});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Gợi ý cho bạn', ui: ui),

        SizedBox(height: ui.width * 0.03),

        SizedBox(
          height: ui.userRailHeight,
          child: ListView.separated(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => SizedBox(width: ui.width * 0.045),
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

                      SizedBox(height: ui.userCardWidth * 0.04),

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

                      SizedBox(height: ui.userCardWidth * 0.035),

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
  final VoidCallback? onSeeAll;

  const _SectionHeader({
    required this.title,
    required this.ui,
    this.onSeeAll,
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
          onTap: onSeeAll,
          child: Text(
            'Xem tất cả',
            style: TextStyle(
              fontSize: _font(ui.width, 13),
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
      child: _SafeAssetImage(path: imagePath, fit: BoxFit.cover),
    );
  }
}

class _SimpleAvatar extends StatelessWidget {
  final String imagePath;
  final double size;

  const _SimpleAvatar({required this.imagePath, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE7EBF3),
        border: Border.all(color: AppColors.grayBorder, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: _SafeAssetImage(path: imagePath, fit: BoxFit.cover),
    );
  }
}

class _SafeAssetImage extends StatelessWidget {
  final String path;
  final BoxFit fit;

  const _SafeAssetImage({required this.path, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      fit: fit,
      errorBuilder: (_, __, ___) {
        return Container(
          color: const Color(0xFFE7EBF3),
          alignment: Alignment.center,
          child: Icon(LucideIcons.image, size: 26, color: AppColors.grayText),
        );
      },
    );
  }
}

class _SafeNetworkImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;

  const _SafeNetworkImage({required this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final source = url?.trim();
    if (source == null || source.isEmpty) {
      return const _ImageFallback();
    }

    return Image.network(
      source,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            const _ImageFallback(),
            Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  value: progress.expectedTotalBytes == null
                      ? null
                      : progress.cumulativeBytesLoaded /
                      progress.expectedTotalBytes!,
                ),
              ),
            ),
          ],
        );
      },
      errorBuilder: (_, __, ___) => const _ImageFallback(),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE7EBF3),
      alignment: Alignment.center,
      child: Icon(LucideIcons.image, size: 26, color: AppColors.grayText),
    );
  }
}

double _font(double width, double baseAt360) {
  final value = baseAt360 * (width / 360);

  return value.clamp(baseAt360 * 0.93, baseAt360 * 1.12).toDouble();
}

// ============================================================================
// MODELS
// ============================================================================


class _HomePost {
  final String id;
  final String authorName;

  /// Backend sau này ưu tiên:
  /// 1) tên Place được gắn vào bài;
  /// 2) nếu không gắn Place thì dùng label GPS đã lưu lúc đăng.
  final String location;

  /// Nếu post gắn Place thật thì backend trả placeId.
  /// Nếu không có Place, backend có thể trả tọa độ GPS đã chụp lúc đăng.
  final String? placeId;
  final double? latitude;
  final double? longitude;

  final String avatar;
  final String caption;
  final List<String> media;
  final int likeCount;
  final int commentCount;

  const _HomePost({
    required this.id,
    required this.authorName,
    required this.location,
    this.placeId,
    this.latitude,
    this.longitude,
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
  final String? imageUrl;

  const _PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.rating,
    required this.imageUrl,
  });

  factory _PlaceSuggestion.fromRecommended(RecommendedPlace place) {
    final rating = place.rating > 0 ? place.rating : place.score.clamp(0, 5);
    return _PlaceSuggestion(
      title: place.name,
      subtitle: place.locationText,
      rating: rating.toDouble(),
      imageUrl: place.thumbnailUrl,
    );
  }
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

