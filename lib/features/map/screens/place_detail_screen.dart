import 'dart:io';
import 'dart:async';
import '../../../core/services/content_access_changes.dart';
import '../../../core/network/api_exception.dart';
import '../../place/data/place_review_repository.dart';
import '../../place/data/place_api.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/gomate_image_viewer.dart';
import '../../../core/widgets/gomate_itinerary_picker.dart';
import '../../../core/widgets/snackbar.dart';
import '../../home/data/post_interaction_repository.dart';
import '../../trip/models/trip_ui_models.dart';
import '../state/map_ui_session.dart';
import '../utils/cloudinary_image_url.dart';
import '../widgets/share_place_content.dart';
import '../../profile/screens/profile_post_feed_screen.dart';
import '../../profile/widgets/profile_ui_widgets.dart';
import '../../messages/widgets/message_widgets.dart' show MessageConfirmContent;

class MapPlaceUi {
  final String id;
  final String name;
  final String subtitle;
  final String address;
  final String distanceText;
  final String openInfo;
  final String priceInfo;
  final double _rating;
  final int _reviewCount;
  double get rating =>
      (PlaceRatingChanges.forPlace(id).value ??
              PlaceRating(_rating, _reviewCount))
          .display;
  int get reviewCount =>
      PlaceRatingChanges.forPlace(id).value?.count ?? _reviewCount;
  final int likeCount;
  final List<String> tags;
  final String? imageAsset;
  final String? imageUrl;
  final List<String> mediaUrls;

  const MapPlaceUi({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.address,
    required this.distanceText,
    required this.openInfo,
    required this.priceInfo,
    required double rating,
    required int reviewCount,
    required this.likeCount,
    required this.tags,
    this.imageAsset,
    this.imageUrl,
    this.mediaUrls = const <String>[],
  }) : _rating = rating,
       _reviewCount = reviewCount;
}

/// UI store tạm thời để không thay đổi backend hiện tại.
class FavoritePlaceStore {
  FavoritePlaceStore._();

  static final Map<String, List<MapPlaceUi>> folders = {
    'Của tôi': <MapPlaceUi>[],
  };

  static List<String> get folderNames => folders.keys.toList();

  static List<MapPlaceUi> placesIn(String folder) =>
      List<MapPlaceUi>.from(folders[folder] ?? const <MapPlaceUi>[]);

  static void ensureFolder(String folder) {
    folders.putIfAbsent(folder, () => <MapPlaceUi>[]);
  }

  static void addToFolder(String folder, MapPlaceUi place) {
    ensureFolder(folder);
    final list = folders[folder]!;
    if (!list.any((item) => item.id == place.id)) list.add(place);
  }

  static void removeFromFolder(String folder, MapPlaceUi place) {
    folders[folder]?.removeWhere((item) => item.id == place.id);
  }

  static bool contains(String folder, MapPlaceUi place) =>
      folders[folder]?.any((item) => item.id == place.id) ?? false;

  static Set<String> foldersContaining(MapPlaceUi place) {
    return folders.entries
        .where((entry) => entry.value.any((item) => item.id == place.id))
        .map((entry) => entry.key)
        .toSet();
  }
}

class PlaceDetailScreen extends StatefulWidget {
  final MapPlaceUi place;
  final PlaceReviewRepository? reviewRepository;
  final PlaceApi? placeApi;

  const PlaceDetailScreen({
    super.key,
    required this.place,
    this.reviewRepository,
    this.placeApi,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  final PageController _heroController = PageController();
  final PostInteractionRepository _shareRepository =
      DemoPostInteractionRepository();

  List<_PlaceReviewUi> _reviews = [];
  late final _reviewRepo = widget.reviewRepository ?? PlaceReviewRepository();
  late final _placeApi = widget.placeApi ?? PlaceApi();
  PlaceReview? _ownedReview;
  bool _reviewsLoading = true;
  String? _reviewError;
  int _reviewEpoch = 0;
  int? _nextReview;
  String? _actor;
  String _message(Object e) => e is ApiException
      ? e.message
      : 'Không tải được đánh giá. Vui lòng thử lại.';
  _PlaceReviewUi _reviewUi(
    PlaceReview r, {
    bool mine = false,
  }) => _PlaceReviewUi(
    id: r.id.toString(),
    author: mine ? 'Bạn' : r.author,
    subtitle: r.hidden ? 'Đang ẩn' : '',
    timeText: r.createdAt == null
        ? ''
        : '${r.createdAt!.toLocal().day}/${r.createdAt!.toLocal().month}/${r.createdAt!.toLocal().year}',
    body: r.content,
    rating: r.rating.toDouble(),
    images: const [],
    isMine: mine,
  );
  void _sessionChanged() {
    final current = _reviewRepo.auth.user?['id']?.toString();
    if (current == _actor) return;
    _actor = current;
    if (mounted)
      setState(() {
        _myReview = null;
        _ownedReview = null;
        _reviews = [];
      });
    unawaited(_loadReviews());
  }

  void _accessChanged() {
    if (mounted) {
      setState(() => _reviews = []);
      unawaited(_loadReviews());
    }
  }

  Future<void> _loadReviews() async {
    final epoch = ++_reviewEpoch;
    if (!mounted) return;
    setState(() {
      _reviewsLoading = true;
      _reviewError = null;
    });
    try {
      await _placeApi.getPlace(int.parse(place.id));
      if (!mounted || epoch != _reviewEpoch) return;
      if (!_reviewRepo.auth.signedIn) {
        setState(() {
          _reviewsLoading = false;
          _reviewError = 'Đăng nhập để xem và gửi đánh giá.';
        });
        return;
      }
      final values = await Future.wait([
        _reviewRepo.mine(place.id),
        _reviewRepo.page(place.id),
      ]);
      if (!mounted || epoch != _reviewEpoch) return;
      final own = values[0] as PlaceReviewState;
      final page = values[1] as PlaceReviewPage;
      _applyOwn(own);
      setState(() {
        _reviews = page.items
            .where((r) => r.userId != _actor)
            .map((r) => _reviewUi(r))
            .toList();
        _nextReview = page.nextBeforeId;
        _reviewsLoading = false;
      });
    } catch (e) {
      if (mounted && epoch == _reviewEpoch)
        setState(() {
          _reviewError = _message(e);
          _reviewsLoading = false;
        });
    }
  }

  void _applyOwn(PlaceReviewState state) {
    if (!mounted) return;
    PlaceRatingChanges.acknowledge(place.id, state.stats);
    setState(() {
      _ownedReview = state.mine;
      _myReview = state.mine == null
          ? null
          : _reviewUi(state.mine!, mine: true);
    });
  }

  Future<void> _deleteMyReview() async {
    final own = _ownedReview;
    if (own == null) return;
    final confirmed = await GoMateBottomSheet.show<bool>(
      context: context,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MessageConfirmContent(
              title: 'Xóa đánh giá?',
              description:
                  'Đánh giá của bạn sẽ không còn được hiển thị và tính điểm.',
              confirmLabel: 'Xóa',
              onConfirm: () => Navigator.of(sheetContext).pop(true),
            ),
            const SizedBox(height: 12),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.grayText,
                backgroundColor: AppColors.grayBackground,
                minimumSize: const Size(150, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.grayBorder),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.of(sheetContext).pop(false),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      _applyOwn(await _reviewRepo.delete(place.id, own.id));
    } catch (e) {
      if (mounted) GoMateSnackBar.show(context, message: _message(e));
    }
  }

  late Set<String> _selectedFolders;
  _PlaceReviewUi? _myReview;
  int _heroIndex = 0;
  bool _detailHeaderVisible = true;

  MapPlaceUi get place => widget.place;

  List<String> get _heroImages {
    final items = <String>[
      ...place.mediaUrls,
      if (place.imageUrl != null) place.imageUrl!,
      if (place.imageAsset != null) place.imageAsset!,
    ];
    final seen = <String>{};
    return items.where((item) => item.isNotEmpty && seen.add(item)).toList();
  }

  bool get _isFavorite => _selectedFolders.isNotEmpty;

  List<_PlaceReviewUi> get _mainReviews {
    final items = <_PlaceReviewUi>[
      if (_myReview != null) _myReview!,
      ..._reviews.where((item) => !item.isMine),
    ];
    return items.take(3).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _selectedFolders = FavoritePlaceStore.foldersContaining(place);
    _actor = _reviewRepo.auth.user?['id']?.toString();
    _reviewRepo.auth.addListener(_sessionChanged);
    ContentAccessChanges.revision.addListener(_accessChanged);
    unawaited(_loadReviews());
  }

  @override
  void dispose() {
    ++_reviewEpoch;
    _reviewRepo.auth.removeListener(_sessionChanged);
    ContentAccessChanges.revision.removeListener(_accessChanged);
    if (widget.placeApi == null) _placeApi.close();
    _heroController.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    setState(() {
      if (_isFavorite) {
        for (final folder in _selectedFolders.toList()) {
          FavoritePlaceStore.removeFromFolder(folder, place);
        }
        _selectedFolders.clear();
      } else {
        FavoritePlaceStore.addToFolder('Của tôi', place);
        _selectedFolders = {'Của tôi'};
      }
    });
  }

  Future<void> _openReviewComposer({int? selectedRating}) async {
    if (_reviewsLoading || _reviewError != null) {
      GoMateSnackBar.show(
        context,
        message: _reviewError ?? 'Đang tải đánh giá của bạn.',
      );
      return;
    }
    final current = _ownedReview;
    await GoMateBottomSheet.show<bool>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      contentPadding: EdgeInsets.zero,
      child: _ReviewComposer(
        initialRating: selectedRating ?? current?.rating ?? 5,
        initialBody: current?.content ?? '',
        initialImagePaths: const [],
        editing: current != null,
        onSubmit: (rating, body) async {
          final result = await _reviewRepo.save(
            place.id,
            rating,
            body,
            reviewId: current?.id,
          );
          ++_reviewEpoch;
          _reviewsLoading = false;
          _applyOwn(result);
        },
      ),
    );
  }

  Future<void> _openAllReviews() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceReviewsScreen(
          placeId: place.id,
          repository: _reviewRepo,
          nextBeforeId: _nextReview,
          placeName: place.name,
          address: place.address,
          overallRating: place.rating,
          reviewCount: place.reviewCount,
          reviews: <_PlaceReviewUi>[
            if (_myReview != null) _myReview!,
            ..._reviews.where((item) => !item.isMine),
          ],
        ),
      ),
    );
  }

  Future<void> _openSharePlace() async {
    final sentCount = await GoMateBottomSheet.show<int>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      contentPadding: EdgeInsets.zero,
      child: SharePlaceContent(
        placeId: place.id,
        placeName: place.name,
        repository: _shareRepository,
      ),
    );

    if (!mounted || sentCount == null || sentCount <= 0) return;
  }

  Future<void> _openItineraryPicker() async {
    final trips = GoMateMapUiSession.availableTrips;

    final items = trips
        .map(
          (trip) => GoMateItineraryPickerItem(
            id: trip.id,
            title: trip.title,
            dateRange: trip.dateRangeLabel,
            summary: '${trip.days} ngày - ${trip.places.length} địa điểm',
            imageAsset: trip.coverAsset,
            memberCount: trip.isGroup ? trip.memberCount : 0,
          ),
        )
        .toList(growable: false);

    final selected = await Navigator.of(context)
        .push<GoMateItineraryPickerItem>(
          MaterialPageRoute(
            builder: (pickerContext) {
              return GoMateItineraryPickerScreen(
                items: items,
                showCancel: true,
                searchHint: 'Tìm kiếm lịch trình...',
                onCancel: () {
                  Navigator.of(pickerContext).pop();
                },
                onSelected: (item) {
                  Navigator.of(pickerContext).pop(item);
                },
              );
            },
          ),
        );

    if (!mounted || selected == null) return;

    TripUi? trip;

    for (final item in trips) {
      if (item.id == selected.id) {
        trip = item;
        break;
      }
    }

    if (trip == null) return;

    if (!trip.canEditTrip) {
      GoMateSnackBar.show(
        context,
        message: 'Bạn chỉ có quyền xem lộ trình này.',
      );
      return;
    }

    // Luồng từ Place Detail luôn đi đầy đủ:
    // Trip đã chọn -> chọn ngày -> giờ bắt đầu -> giờ kết thúc.
    GoMateMapUiSession.requestAddPlaceFromDetail(placeId: place.id, trip: trip);

    // MainShell đã được yêu cầu đổi về Map.
    // Đóng toàn bộ route detail/search nằm trên MainShell để flow Map
    // luôn hiện ra ngay, bất kể Place Detail được mở từ đâu.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  bool _handleDetailScroll(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.idle) return false;

    final shouldShow =
        notification.metrics.pixels <= 4 ||
        notification.direction == ScrollDirection.forward;

    if (shouldShow != _detailHeaderVisible && mounted) {
      setState(() => _detailHeaderVisible = shouldShow);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final horizontal = (width * 0.055).clamp(18.0, 24.0).toDouble();
    final headerHeight = (width * 0.36).clamp(132.0, 150.0).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            NotificationListener<UserScrollNotification>(
              onNotification: _handleDetailScroll,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Giữ chỗ cho floating header ở đầu trang. Khi cuộn xuống,
                  // khoảng trống này trôi đi cùng content còn header overlay
                  // tự ẩn/hiện theo hướng cuộn kiểu Instagram.
                  SliverToBoxAdapter(child: SizedBox(height: headerHeight)),
                  SliverToBoxAdapter(child: _buildHero(width)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        width * 0.060,
                        horizontal,
                        0,
                      ),
                      child: _buildReviews(width),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: width * 0.075)),
                  SliverToBoxAdapter(
                    child: _buildRelatedPlaces(width, horizontal),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: width * 0.075)),
                  SliverToBoxAdapter(
                    child: _buildRelatedPosts(width, horizontal),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: width * 0.32)),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                ignoring: !_detailHeaderVisible,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 190),
                  curve: Curves.easeOutCubic,
                  offset: _detailHeaderVisible
                      ? Offset.zero
                      : const Offset(0, -1.04),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _detailHeaderVisible ? 1 : 0,
                    child: SizedBox(
                      height: headerHeight,
                      child: _PlaceFloatingHeader(
                        place: place,
                        isFavorite: _isFavorite,
                        onBack: () => Navigator.of(context).pop(),
                        onFavorite: _toggleFavorite,
                        onShare: _openSharePlace,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: safeBottom + (width * 0.035).clamp(12.0, 16.0).toDouble(),
              child: Center(
                child: _AddItineraryButton(onTap: _openItineraryPicker),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(double width) {
    final images = _heroImages;
    final height = (width * 0.98).clamp(330.0, 430.0).toDouble();

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: height,
          child: images.isEmpty
              ? _imageFallback()
              : PageView.builder(
                  controller: _heroController,
                  itemCount: images.length,
                  onPageChanged: (index) => setState(() => _heroIndex = index),
                  itemBuilder: (context, index) => _SmartImage(
                    path: images[index],
                    fit: BoxFit.cover,
                    useCloudinaryHero: true,
                  ),
                ),
        ),
        if (images.length > 1)
          Padding(
            padding: EdgeInsets.symmetric(vertical: width * 0.025),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length.clamp(0, 5).toInt(), (
                index,
              ) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.symmetric(horizontal: width * 0.008),
                  width: (width * 0.016).clamp(6.0, 7.0).toDouble(),
                  height: (width * 0.016).clamp(6.0, 7.0).toDouble(),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _heroIndex == index
                        ? AppColors.primaryIcon
                        : AppColors.grayBorder,
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _imageFallback() {
    return const ColoredBox(
      color: AppColors.blue50,
      child: Center(
        child: Icon(LucideIcons.image, size: 58, color: AppColors.primaryIcon),
      ),
    );
  }

  Widget _buildReviews(double width) {
    final userRating = _myReview?.rating.round() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Đánh giá',
              style: TextStyle(
                fontSize: (width * 0.033).clamp(12.0, 14.0).toDouble(),
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: _openAllReviews,
              child: Text(
                '(${place.reviewCount}) Xem tất cả',
                style: TextStyle(
                  fontSize: (width * 0.028).clamp(10.0, 12.0).toDouble(),
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: width * 0.030),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Avatar(size: (width * 0.085).clamp(31.0, 36.0).toDouble()),
              SizedBox(width: width * 0.040),
              ...List.generate(5, (index) {
                final active = index < userRating;
                return InkWell(
                  key: ValueKey('place-review-open-${index + 1}'),
                  onTap: () => _openReviewComposer(selectedRating: index + 1),
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: width * 0.013),
                    child: Icon(
                      active ? Icons.star_rounded : LucideIcons.star,
                      size: (width * 0.055).clamp(20.0, 24.0).toDouble(),
                      color: active
                          ? AppColors.primaryIcon
                          : AppColors.grayText,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        SizedBox(height: width * 0.042),
        if (_reviewsLoading) const Center(child: CircularProgressIndicator()),
        if (_reviewError != null)
          TextButton(
            onPressed: _loadReviews,
            child: Text('$_reviewError · Thử lại'),
          ),
        if (!_reviewsLoading && _reviewError == null && place.reviewCount == 0)
          const Text(
            'Chưa có đánh giá',
            style: TextStyle(color: AppColors.grayText),
          ),
        for (final review in _mainReviews) ...[
          _ReviewCard(
            review: review,
            onEdit: review.isMine ? () => _openReviewComposer() : null,
            onDelete: review.isMine ? _deleteMyReview : null,
          ),
          SizedBox(height: width * 0.040),
        ],
      ],
    );
  }

  Widget _buildRelatedPlaces(double width, double horizontal) {
    final images = _heroImages;
    final first = images.isEmpty ? null : images.first;

    final cards = <_RelatedPlaceCardData>[
      _RelatedPlaceCardData(
        title: place.name,
        location: place.tags.length > 1 ? place.tags.last : 'Đà Nẵng',
        rating: PlaceRating(place.rating, place.reviewCount),
        image: first,
      ),
    ];

    final cardWidth = (width * 0.400).clamp(132.0, 156.0).toDouble();
    final cardHeight = cardWidth * (250 / 150);
    final railHeight =
        cardHeight + (width * 0.045).clamp(16.0, 20.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          child: Text(
            'Địa điểm liên quan',
            style: TextStyle(
              fontSize: (width * 0.033).clamp(12.0, 14.0).toDouble(),
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        SizedBox(height: width * 0.025),
        SizedBox(
          height: railHeight,
          child: ListView.separated(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            itemCount: cards.length,
            separatorBuilder: (_, __) => SizedBox(width: width * 0.050),
            itemBuilder: (_, index) => Align(
              alignment: Alignment.topCenter,
              child: _RelatedPlaceCard(
                data: cards[index],
                cardWidth: cardWidth,
                cardHeight: cardHeight,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedPosts(double width, double horizontal) {
    final fallback = _heroImages.isEmpty ? null : _heroImages.first;
    // TODO(BACKEND-PROFILE-UI-PREVIEW): thay ảnh/postId/tác giả demo
    // bằng bài viết thật được backend liên kết với địa điểm hiện tại.
    final postImages = <String>[
      'assets/images/checkin.jpg',
      'assets/images/thiennhien.jpg',
      'assets/images/nghiduong.jpg',
      'assets/images/lichsu.jpg',
    ];
    final relatedPosts = <GoMateProfilePostPreview>[
      for (var i = 0; i < postImages.length; i++)
        GoMateProfilePostPreview(
          id: 'ui-preview-related-${place.id}-$i',
          authorId: '', // Chưa có thông tin chủ bài viết.
          authorName: 'Bài viết liên quan',
          caption: place.name,
          location: place.address,
          media: <String>[postImages[i]],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'Bài viết liên quan',
                  style: TextStyle(
                    fontSize: (width * 0.033).clamp(12.0, 14.0).toDouble(),
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${postImages.length} bài viết',
                style: TextStyle(
                  fontSize: (width * 0.028).clamp(10.0, 12.0).toDouble(),
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: width * 0.025),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: postImages.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final asset = postImages[index];
            return InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GoMateProfilePostFeedScreen(
                      posts: relatedPosts,
                      initialIndex: index,
                    ),
                  ),
                );
              },
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback == null
                    ? _imageFallback()
                    : _SmartImage(path: fallback, fit: BoxFit.cover),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PlaceFloatingHeader extends StatelessWidget {
  final MapPlaceUi place;
  final bool isFavorite;

  final VoidCallback onBack;
  final VoidCallback onFavorite;
  final VoidCallback onShare;

  const _PlaceFloatingHeader({
    required this.place,
    required this.isFavorite,
    required this.onBack,
    required this.onFavorite,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = (width * 0.055).clamp(18.0, 24.0).toDouble();

    return Container(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        width * 0.015,
        horizontal,
        width * 0.024,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hàng icon: giữ nguyên luồng hiện tại.
          Row(
            children: [
              _HeaderIconButton(icon: LucideIcons.chevron_left, onTap: onBack),
              const Spacer(),
              _HeaderIconButton(
                icon: isFavorite ? Icons.favorite_rounded : LucideIcons.heart,
                color: isFavorite ? AppColors.primaryIcon : Colors.black,
                onTap: onFavorite,
              ),
              SizedBox(width: width * 0.020),
              _HeaderIconButton(icon: LucideIcons.send, onTap: onShare),
            ],
          ),

          SizedBox(height: width * 0.012),

          // Tên địa điểm.
          Text(
            place.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: (width * 0.050).clamp(18.0, 22.0).toDouble(),
              fontWeight: FontWeight.w800,
              color: AppColors.primaryText,
              height: 1.05,
            ),
          ),

          SizedBox(height: width * 0.010),

          // Đánh giá và phân loại địa điểm.
          Row(
            children: [
              Icon(
                Icons.star_rounded,
                size: (width * 0.040).clamp(15.0, 17.0).toDouble(),
                color: AppColors.primaryIcon,
              ),
              SizedBox(width: width * 0.008),
              Expanded(
                child: Text(
                  '${PlaceRating(place.rating, place.reviewCount).label}   '
                  '${place.tags.isNotEmpty ? place.tags.first : 'Khu du lịch'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: (width * 0.028).clamp(10.5, 12.0).toDouble(),
                    color: AppColors.grayText,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: width * 0.010),

          // Địa chỉ.
          Text(
            place.address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: (width * 0.027).clamp(10.0, 11.5).toDouble(),
              color: AppColors.grayText,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: EdgeInsets.all((width * 0.016).clamp(6.0, 8.0).toDouble()),
        child: Icon(
          icon,
          size: (width * 0.060).clamp(22.0, 26.0).toDouble(),
          color: color,
        ),
      ),
    );
  }
}

class _PlaceReviewUi {
  final String id;
  final String author;
  final String subtitle;
  final String timeText;
  final String body;
  final double rating;
  final List<String> images;
  final bool isMine;

  const _PlaceReviewUi({
    required this.id,
    required this.author,
    required this.subtitle,
    required this.timeText,
    required this.body,
    required this.rating,
    required this.images,
    this.isMine = false,
  });
}

class _ReviewCard extends StatelessWidget {
  final _PlaceReviewUi review;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ReviewCard({required this.review, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all((width * 0.045).clamp(15.0, 19.0).toDouble()),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          (width * 0.040).clamp(14.0, 17.0).toDouble(),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.050),
            blurRadius: 11,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(size: (width * 0.085).clamp(31.0, 36.0).toDouble()),
              SizedBox(width: width * 0.022),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            review.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: (width * 0.034)
                                  .clamp(12.5, 14.5)
                                  .toDouble(),
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        if (review.isMine && onDelete != null)
                          IconButton(
                            tooltip: 'Xóa đánh giá',
                            onPressed: onDelete,
                            icon: const Icon(
                              LucideIcons.trash,
                              size: 16,
                              color: AppColors.grayText,
                            ),
                          ),
                        if (review.isMine && onEdit != null) ...[
                          SizedBox(width: width * 0.020),
                          InkWell(
                            onTap: onEdit,
                            child: Text(
                              'Chỉnh sửa',
                              style: TextStyle(
                                fontSize: (width * 0.026)
                                    .clamp(9.5, 11.0)
                                    .toDouble(),
                                color: AppColors.primaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      review.subtitle,
                      style: TextStyle(
                        fontSize: (width * 0.027).clamp(10.0, 11.5).toDouble(),
                        color: AppColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.star_rounded,
                size: (width * 0.040).clamp(14.0, 17.0).toDouble(),
                color: AppColors.primaryIcon,
              ),
              SizedBox(width: width * 0.010),
              Text(
                review.rating.toStringAsFixed(1).replaceAll('.', ','),
                style: TextStyle(
                  fontSize: (width * 0.030).clamp(11.0, 12.5).toDouble(),
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          SizedBox(height: width * 0.032),
          Text(
            review.body,
            style: TextStyle(
              fontSize: (width * 0.030).clamp(11.0, 12.5).toDouble(),
              color: Colors.black,
            ),
          ),
          if (review.images.isNotEmpty) ...[
            SizedBox(height: width * 0.030),
            _ReviewImages(
              images: review.images,
              author: review.author,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewImages extends StatelessWidget {
  final List<String> images;
  final String author;
  final bool compact;

  const _ReviewImages({
    required this.images,
    required this.author,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final size = compact
        ? (width * 0.20).clamp(72.0, 86.0).toDouble()
        : (width * 0.30).clamp(106.0, 128.0).toDouble();

    return SizedBox(
      height: size,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: images.length,
        separatorBuilder: (_, __) => SizedBox(width: width * 0.012),
        itemBuilder: (context, index) {
          return InkWell(
            onTap: () => GoMateImageViewer.open(
              context,
              images: images,
              initialIndex: index,
              title: author,
            ),
            borderRadius: BorderRadius.circular(11),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: size,
                height: size,
                child: _SmartImage(path: images[index], fit: BoxFit.cover),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final double size;

  const _Avatar({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE7EBF3),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Icon(
        LucideIcons.user_round,
        size: size * 0.58,
        color: Colors.white,
      ),
    );
  }
}

class _RelatedPlaceCardData {
  final String title;
  final String location;
  final PlaceRating rating;
  final String? image;

  const _RelatedPlaceCardData({
    required this.title,
    required this.location,
    required this.rating,
    required this.image,
  });
}

class _RelatedPlaceCard extends StatelessWidget {
  final _RelatedPlaceCardData data;
  final double cardWidth;
  final double cardHeight;

  const _RelatedPlaceCard({
    required this.data,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    final radius = (cardWidth * 0.14).clamp(16.0, 21.0).toDouble();

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.050),
            blurRadius: 11,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (data.image != null)
              _SmartImage(path: data.image!, fit: BoxFit.cover)
            else
              const ColoredBox(color: AppColors.blue50),
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
              top: cardWidth * 0.065,
              right: cardWidth * 0.065,
              child: Container(
                constraints: BoxConstraints(maxWidth: cardWidth * 0.87),
                padding: EdgeInsets.symmetric(
                  horizontal: cardWidth * 0.045,
                  vertical: cardWidth * 0.028,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(cardWidth * 0.075),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        data.rating.hasValidRating
                            ? Icons.star_rounded
                            : LucideIcons.star,
                        size: cardWidth * 0.105,
                        color: data.rating.hasValidRating
                            ? AppColors.primaryIcon
                            : AppColors.grayText,
                      ),
                      SizedBox(width: cardWidth * 0.02),
                      Text(
                        data.rating.compactLabel,
                        style: TextStyle(
                          fontSize: cardWidth * 0.077,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: cardWidth * 0.08,
              right: cardWidth * 0.08,
              bottom: cardWidth * 0.08,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: cardWidth * 0.070,
                      height: 1.12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: cardWidth * 0.018),
                  Text(
                    data.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: cardWidth * 0.063,
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
    );
  }
}

class _SmartImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final bool useCloudinaryHero;

  const _SmartImage({
    required this.path,
    required this.fit,
    this.useCloudinaryHero = false,
  });

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final url = useCloudinaryHero ? cloudinaryPlaceHeroUrl(path) : path;
      return Image.network(
        url,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    if (path.startsWith('/') || path.startsWith('file://')) {
      final filePath = path.startsWith('file://')
          ? Uri.parse(path).toFilePath()
          : path;
      return Image.file(
        File(filePath),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    return Image.asset(
      path,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    return const ColoredBox(
      color: AppColors.blue50,
      child: Center(
        child: Icon(LucideIcons.image, color: AppColors.primaryIcon),
      ),
    );
  }
}

class _AddItineraryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddItineraryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    // Figma reference:
    // artboard: 375
    // button: 189 x 45
    //
    // Quy đổi theo width thật thay vì fix cứng 189px.
    final buttonWidth = (width * (189 / 375)).clamp(178.0, 205.0).toDouble();

    final buttonHeight = (width * (45 / 375)).clamp(43.0, 47.0).toDouble();

    // Figma radius: 20 / height 45.
    final radius = buttonHeight * (20 / 45);

    final iconCircleSize = (buttonHeight * 0.59).clamp(25.0, 27.5).toDouble();

    final iconSize = (iconCircleSize * 0.58).clamp(14.5, 16.0).toDouble();

    final contentGap = (width * (8 / 375)).clamp(7.0, 9.0).toDouble();

    final horizontalPadding = (width * (13 / 375)).clamp(11.0, 14.0).toDouble();

    final fontSize = (width * (14 / 375)).clamp(13.5, 14.5).toDouble();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          width: buttonWidth,
          height: buttonHeight,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            // Figma:
            // #0A43A8 0%
            // #0C6ECF 57%
            // #0D8AE8 100%
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [0.0, 0.57, 1.0],
              colors: [Color(0xFF0A43A8), Color(0xFF0C6ECF), Color(0xFF0D8AE8)],
            ),
            borderRadius: BorderRadius.circular(radius),

            // Figma:
            // 0px 4px 12px rgba(0,0,0,0.08)
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                offset: Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: iconCircleSize,
                height: iconCircleSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: Center(
                    child: Icon(
                      LucideIcons.plus,
                      size: iconSize,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              SizedBox(width: contentGap),

              Flexible(
                child: Text(
                  'Thêm lịch trình',
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.095).clamp(36.0, 42.0).toDouble();

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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 9,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: (width * 0.031).clamp(11.5, 13.0).toDouble(),
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

class _ReviewComposer extends StatefulWidget {
  final int initialRating;
  final String initialBody;
  final List<String> initialImagePaths;
  final bool editing;
  final Future<void> Function(int rating, String content) onSubmit;

  const _ReviewComposer({
    required this.initialRating,
    required this.initialBody,
    required this.initialImagePaths,
    required this.editing,
    required this.onSubmit,
  });

  @override
  State<_ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends State<_ReviewComposer> {
  bool _saving = false;
  String? _error;
  late final TextEditingController _controller;
  late List<String> _images;
  late int _rating;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating.clamp(0, 5).toInt();
    _controller = TextEditingController(text: widget.initialBody);
    _images = List<String>.from(widget.initialImagePaths);
    _controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    GoMateSnackBar.show(
      context,
      message: 'Đính ảnh đánh giá chưa được hỗ trợ ở phiên bản này.',
    );
  }

  Future<void> _submit() async {
    if (_rating <= 0 || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_rating, _controller.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted)
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Chưa lưu được đánh giá. Vui lòng thử lại.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = (width * 0.060).clamp(20.0, 25.0).toDouble();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        0,
        horizontal,
        (width * 0.045).clamp(16.0, 20.0).toDouble(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Đánh giá',
            style: TextStyle(
              fontSize: (width * 0.038).clamp(14.0, 16.0).toDouble(),
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          SizedBox(height: width * 0.010),
          Text(
            'Đánh giá của bạn sẽ được đăng công khai',
            style: TextStyle(
              fontSize: (width * 0.025).clamp(9.5, 11.0).toDouble(),
              color: AppColors.grayText,
            ),
          ),
          SizedBox(height: width * 0.020),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final active = index < _rating;
              return InkWell(
                key: ValueKey('place-review-star-${index + 1}'),
                onTap: _saving
                    ? null
                    : () => setState(() => _rating = index + 1),
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.018),
                  child: Icon(
                    active ? Icons.star_rounded : LucideIcons.star,
                    size: (width * 0.060).clamp(22.0, 26.0).toDouble(),
                    color: active ? AppColors.primaryIcon : AppColors.grayText,
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: width * 0.010),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_controller.text.length}/1000',
              style: TextStyle(
                fontSize: (width * 0.025).clamp(9.5, 11.0).toDouble(),
                color: AppColors.grayText,
              ),
            ),
          ),
          SizedBox(height: width * 0.010),
          Container(
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: (width * 0.14).clamp(54.0, 64.0).toDouble(),
            ),
            padding: EdgeInsets.symmetric(horizontal: width * 0.040),
            decoration: BoxDecoration(
              color: AppColors.grayBackground,
              borderRadius: BorderRadius.circular(15),
            ),
            child: TextField(
              key: const ValueKey('place-review-content'),
              enabled: !_saving,
              controller: _controller,
              maxLength: 1000,
              maxLines: 4,
              minLines: 2,
              cursorColor: AppColors.primaryIcon,
              decoration: const InputDecoration(
                hintText: 'Viết mô tả...',
                hintStyle: TextStyle(color: AppColors.grayText),
                counterText: '',
                border: InputBorder.none,
              ),
            ),
          ),
          SizedBox(height: width * 0.022),
          Row(
            children: [
              InkWell(
                onTap: _pickImages,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: EdgeInsets.all(width * 0.010),
                  child: Icon(
                    LucideIcons.image_plus,
                    size: (width * 0.060).clamp(21.0, 25.0).toDouble(),
                    color: AppColors.primaryIcon,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_images.length}/10',
                style: TextStyle(
                  fontSize: (width * 0.028).clamp(10.0, 12.0).toDouble(),
                  color: AppColors.grayText,
                ),
              ),
            ],
          ),
          if (_images.isNotEmpty) ...[
            SizedBox(height: width * 0.014),
            SizedBox(
              height: (width * 0.24).clamp(88.0, 104.0).toDouble(),
              child: ListView.separated(
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _images.length,
                separatorBuilder: (_, __) => SizedBox(width: width * 0.018),
                itemBuilder: (context, index) {
                  final size = (width * 0.24).clamp(88.0, 104.0).toDouble();
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: size,
                          height: size,
                          child: _SmartImage(
                            path: _images[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 5,
                        right: 5,
                        child: InkWell(
                          onTap: () => setState(() => _images.removeAt(index)),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.62),
                            ),
                            child: const Icon(
                              LucideIcons.x,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          SizedBox(height: width * 0.032),
          SizedBox(
            width: (width * 0.34).clamp(120.0, 150.0).toDouble(),
            child: _GradientButton(
              label: _saving
                  ? 'Đang lưu…'
                  : widget.editing
                  ? 'Chỉnh sửa'
                  : 'Đăng',
              onTap: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ReviewSort { newest, highest, lowest }

class PlaceReviewsScreen extends StatefulWidget {
  final String placeId;
  final PlaceReviewRepository repository;
  final int? nextBeforeId;
  final String placeName;
  final String address;
  final double overallRating;
  final int reviewCount;
  final List<_PlaceReviewUi> reviews;

  const PlaceReviewsScreen({
    super.key,
    required this.placeId,
    required this.repository,
    this.nextBeforeId,
    required this.placeName,
    required this.address,
    required this.overallRating,
    required this.reviewCount,
    required this.reviews,
  });

  @override
  State<PlaceReviewsScreen> createState() => _PlaceReviewsScreenState();
}

class _PlaceReviewsScreenState extends State<PlaceReviewsScreen> {
  late List<_PlaceReviewUi> _items;
  late PlaceRating _overall;
  int? _next;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _items = List.of(widget.reviews);
    _overall = PlaceRating(widget.overallRating, widget.reviewCount);
    _next = widget.nextBeforeId;
    widget.repository.auth.addListener(_reload);
    ContentAccessChanges.revision.addListener(_reload);
    unawaited(_reload());
  }

  int _epoch = 0;
  String? _listError;
  Future<void> _reload() async {
    final epoch = ++_epoch;
    if (!mounted) return;
    setState(() {
      _items = [];
      _next = null;
      _loading = true;
      _listError = null;
    });
    try {
      final page = await widget.repository.page(
        widget.placeId,
        sort: _sort.name,
      );
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _items = page.items.map(_ui).toList();
        _next = page.nextBeforeId;
        _overall = page.stats;
      });
    } catch (e) {
      if (mounted && epoch == _epoch)
        setState(
          () => _listError = e is ApiException
              ? e.message
              : 'Không tải được đánh giá.',
        );
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  _PlaceReviewUi _ui(PlaceReview r) => _PlaceReviewUi(
    id: r.id.toString(),
    author: r.author,
    subtitle: '',
    timeText: r.createdAt == null
        ? ''
        : '${r.createdAt!.toLocal().day}/${r.createdAt!.toLocal().month}/${r.createdAt!.toLocal().year}',
    body: r.content,
    rating: r.rating.toDouble(),
    images: const [],
    isMine: r.userId == widget.repository.auth.user?['id'],
  );
  @override
  void dispose() {
    ++_epoch;
    widget.repository.auth.removeListener(_reload);
    ContentAccessChanges.revision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _more() async {
    if (_loading || _next == null) return;
    final epoch = _epoch;
    setState(() => _loading = true);
    try {
      final result = await widget.repository.page(
        widget.placeId,
        before: _next,
        sort: _sort.name,
      );
      if (!mounted || epoch != _epoch) return;
      setState(() {
        for (final r in result.items) {
          if (!_items.any((i) => i.id == r.id.toString()))
            _items.add(
              _PlaceReviewUi(
                id: r.id.toString(),
                author: r.author,
                subtitle: '',
                timeText: '',
                body: r.content,
                rating: r.rating.toDouble(),
                images: const [],
                isMine: r.userId == widget.repository.auth.user?['id'],
              ),
            );
        }
        _next = result.nextBeforeId;
      });
    } catch (e) {
      if (mounted)
        GoMateSnackBar.show(
          context,
          message: e is ApiException ? e.message : 'Không tải được đánh giá.',
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  _ReviewSort _sort = _ReviewSort.newest;
  bool _showFilters = false;
  bool _headerVisible = true;

  List<_PlaceReviewUi> get _visible {
    final items = List<_PlaceReviewUi>.from(_items);

    switch (_sort) {
      case _ReviewSort.newest:
        return items;
      case _ReviewSort.highest:
        items.sort((a, b) => b.rating.compareTo(a.rating));
        return items;
      case _ReviewSort.lowest:
        items.sort((a, b) => a.rating.compareTo(b.rating));
        return items;
    }
  }

  bool _handleScroll(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.idle) return false;

    final shouldShow =
        notification.metrics.pixels <= 4 ||
        notification.direction == ScrollDirection.forward;
    if (shouldShow != _headerVisible && mounted) {
      setState(() => _headerVisible = shouldShow);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = (width * 0.055).clamp(18.0, 24.0).toDouble();
    final baseHeaderHeight = (width * 0.18).clamp(66.0, 76.0).toDouble();
    final filterHeight = _showFilters
        ? (width * 0.12).clamp(43.0, 50.0).toDouble()
        : 0.0;
    final headerHeight = baseHeaderHeight + filterHeight;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            NotificationListener<UserScrollNotification>(
              onNotification: _handleScroll,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  top: headerHeight + width * 0.025,
                  bottom: width * 0.10,
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      width * 0.030,
                      horizontal,
                      width * 0.035,
                    ),
                    child: _OverallRating(rating: _overall),
                  ),
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                  if (_listError != null)
                    TextButton(
                      onPressed: _reload,
                      child: Text('$_listError · Thử lại'),
                    ),
                  if (!_loading && _listError == null && _items.isEmpty)
                    const Center(child: Text('Chưa có đánh giá')),
                  if (_next != null)
                    TextButton(
                      onPressed: _loading ? null : _more,
                      child: Text(_loading ? 'Đang tải…' : 'Xem thêm đánh giá'),
                    ),
                  for (final review in _visible) ...[
                    _ReviewListItem(review: review),
                    SizedBox(height: width * 0.070),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                ignoring: !_headerVisible,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 190),
                  curve: Curves.easeOutCubic,
                  offset: _headerVisible ? Offset.zero : const Offset(0, -1.04),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _headerVisible ? 1 : 0,
                    child: Container(
                      height: headerHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.035),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: baseHeaderHeight,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontal,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _HeaderIconButton(
                                      icon: LucideIcons.chevron_left,
                                      onTap: () => Navigator.of(context).pop(),
                                    ),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Đánh giá',
                                        style: TextStyle(
                                          fontSize: (width * 0.040)
                                              .clamp(15.0, 17.5)
                                              .toDouble(),
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                      SizedBox(height: width * 0.005),
                                      SizedBox(
                                        width: width * 0.50,
                                        child: Text(
                                          widget.address,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: (width * 0.024)
                                                .clamp(9.0, 10.5)
                                                .toDouble(),
                                            color: AppColors.grayText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: InkWell(
                                      onTap: () => setState(
                                        () => _showFilters = !_showFilters,
                                      ),
                                      customBorder: const CircleBorder(),
                                      child: Padding(
                                        padding: EdgeInsets.all(width * 0.010),
                                        child: Icon(
                                          LucideIcons.sliders_horizontal,
                                          size: (width * 0.060)
                                              .clamp(21.0, 25.0)
                                              .toDouble(),
                                          color: _showFilters
                                              ? AppColors.primaryIcon
                                              : Colors.black,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_showFilters)
                            SizedBox(
                              height: filterHeight,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  horizontal,
                                  0,
                                  horizontal,
                                  width * 0.012,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _SortButton(
                                        label: 'Mới nhất',
                                        active: _sort == _ReviewSort.newest,
                                        onTap: () => setState(() {
                                          _sort = _ReviewSort.newest;
                                          unawaited(_reload());
                                        }),
                                      ),
                                    ),
                                    Expanded(
                                      child: _SortButton(
                                        label: 'Cao nhất',
                                        active: _sort == _ReviewSort.highest,
                                        onTap: () => setState(() {
                                          _sort = _ReviewSort.highest;
                                          unawaited(_reload());
                                        }),
                                      ),
                                    ),
                                    Expanded(
                                      child: _SortButton(
                                        label: 'Thấp nhất',
                                        active: _sort == _ReviewSort.lowest,
                                        onTap: () => setState(() {
                                          _sort = _ReviewSort.lowest;
                                          unawaited(_reload());
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
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

class _OverallRating extends StatelessWidget {
  final PlaceRating rating;

  const _OverallRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final filled = rating.display.round().clamp(0, 5).toInt();
    if (!rating.hasValidRating) {
      return Text(
        rating.label,
        style: TextStyle(
          fontSize: (width * 0.052).clamp(19.0, 23.0).toDouble(),
          fontWeight: FontWeight.w800,
          color: AppColors.primaryText,
        ),
      );
    }

    return Row(
      children: [
        Text(
          rating.compactLabel,
          style: TextStyle(
            fontSize: (width * 0.052).clamp(19.0, 23.0).toDouble(),
            fontWeight: FontWeight.w800,
            color: AppColors.primaryText,
          ),
        ),
        SizedBox(width: width * 0.030),
        Expanded(
          child: Row(
            children: List.generate(5, (index) {
              return Padding(
                padding: EdgeInsets.only(right: width * 0.025),
                child: Icon(
                  index < filled ? Icons.star_rounded : LucideIcons.star,
                  size: (width * 0.048).clamp(17.0, 21.0).toDouble(),
                  color: index < filled
                      ? AppColors.primaryIcon
                      : AppColors.grayText,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ReviewListItem extends StatelessWidget {
  final _PlaceReviewUi review;

  const _ReviewListItem({required this.review});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = (width * 0.055).clamp(18.0, 24.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(size: (width * 0.070).clamp(26.0, 31.0).toDouble()),
                  SizedBox(width: width * 0.020),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                review.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: (width * 0.029)
                                      .clamp(10.5, 12.0)
                                      .toDouble(),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(width: width * 0.018),
                            Flexible(
                              child: Text(
                                '• ${review.timeText}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: (width * 0.024)
                                      .clamp(9.0, 10.0)
                                      .toDouble(),
                                  color: AppColors.grayText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          review.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: (width * 0.023)
                                .clamp(8.5, 9.8)
                                .toDouble(),
                            color: AppColors.grayText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: width * 0.018),
                  Icon(
                    Icons.star_rounded,
                    size: (width * 0.036).clamp(13.0, 15.5).toDouble(),
                    color: AppColors.primaryIcon,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    review.rating.toStringAsFixed(1).replaceAll('.', ','),
                    style: TextStyle(
                      fontSize: (width * 0.025).clamp(9.5, 10.8).toDouble(),
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
              SizedBox(height: width * 0.020),
              Text(
                review.body,
                style: TextStyle(
                  fontSize: (width * 0.026).clamp(9.8, 11.2).toDouble(),
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        if (review.images.isNotEmpty) ...[
          SizedBox(height: width * 0.022),
          Padding(
            padding: EdgeInsets.only(left: width * 0.018),
            child: _ReviewImages(
              images: review.images,
              author: review.author,
              compact: false,
            ),
          ),
        ],
      ],
    );
  }
}

class _SortButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SortButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: width * 0.018),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: (width * 0.027).clamp(10.0, 11.5).toDouble(),
            color: active ? Colors.black : AppColors.grayText,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
