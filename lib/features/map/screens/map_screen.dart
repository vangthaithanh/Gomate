import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../trip/screens/create_trip_screen.dart';
import 'place_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final List<MapPlaceUi> _places = const [
    MapPlaceUi(
      id: '1',
      name: 'Tiệm Cà Phê Gió',
      subtitle: 'Quán cà phê chill ngắm đồi thông và hoàng hôn.',
      address: '42 Đường Trần Hưng Đạo, Đà Lạt',
      distanceText: '2,4 km',
      openInfo: '08:00 - 22:00',
      priceInfo: 'Đồ uống từ 45k',
      rating: 4.5,
      reviewCount: 30,
      likeCount: 13,
      tags: ['Sống ảo', 'View đẹp', 'Cà phê'],
    ),
    MapPlaceUi(
      id: '2',
      name: 'Hồ Xuân Hương',
      subtitle: 'Điểm đi dạo, đạp vịt và ngắm cảnh ngay trung tâm.',
      address: 'Phường 1, Đà Lạt, Lâm Đồng',
      distanceText: '1,1 km',
      openInfo: 'Cả ngày',
      priceInfo: 'Miễn phí',
      rating: 4.8,
      reviewCount: 120,
      likeCount: 52,
      tags: ['Dạo chơi', 'Trung tâm', 'Nhẹ nhàng'],
    ),
    MapPlaceUi(
      id: '3',
      name: 'Chợ Đà Lạt',
      subtitle: 'Thiên đường ăn vặt và mua đặc sản địa phương.',
      address: 'Nguyễn Thị Minh Khai, Đà Lạt',
      distanceText: '1,8 km',
      openInfo: '06:00 - 21:30',
      priceInfo: 'Ăn uống từ 20k',
      rating: 4.4,
      reviewCount: 87,
      likeCount: 41,
      tags: ['Ẩm thực', 'Đặc sản', 'Nhộn nhịp'],
    ),
    MapPlaceUi(
      id: '4',
      name: 'Que Garden',
      subtitle: 'Khu vườn bonsai và hồ cá koi nổi tiếng.',
      address: 'Đường Khởi Nghĩa Bắc Sơn, Đà Lạt',
      distanceText: '4,0 km',
      openInfo: '07:30 - 17:00',
      priceInfo: 'Vé từ 70k',
      rating: 4.6,
      reviewCount: 64,
      likeCount: 25,
      tags: ['Check-in', 'Vườn', 'Gia đình'],
    ),
  ];

  MapPlaceUi? _selectedPlace;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildMap(),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                _buildTopSearch(),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                  child: _selectedPlace == null
                      ? _buildHintCard()
                      : _buildRouteCard(_selectedPlace!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOP SEARCH
  // ============================================================

  Widget _buildTopSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),

      child: Row(
        children: [
          _mapButton(
            icon: Icons.search_rounded,
            onTap: _openSearchSheet,
          ),

          const Spacer(),

          // Phím tắt tạo lịch trình.
          _tripShortcutButton(),

          const SizedBox(width: 10),

          _mapButton(
            icon: Icons.my_location_rounded,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _tripShortcutButton() {
    return Tooltip(
      message: 'Tạo lịch trình',

      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CreateTripScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),

        child: Container(
          width: 52,
          height: 52,

          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(16),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),

          child: Stack(
            clipBehavior: Clip.none,

            children: [
              const Center(
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: 23,
                  color: AppColors.textPrimary,
                ),
              ),

              Positioned(
                right: 8,
                bottom: 8,

                child: Container(
                  width: 17,
                  height: 17,

                  decoration: BoxDecoration(
                    color: AppColors.blue500,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 1.5,
                    ),
                  ),

                  child: const Icon(
                    Icons.add_rounded,
                    size: 11,
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

  // ============================================================
  // MAP
  // ============================================================

  Widget _buildMap() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: AppColors.background,
              child: CustomPaint(
                painter: _MapPainter(),
              ),
            ),
            ..._buildMarkers(
              constraints.maxWidth,
              constraints.maxHeight,
            ),
            if (_selectedPlace != null)
              IgnorePointer(
                child: CustomPaint(
                  painter: _RoutePainter(),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildMarkers(
      double width,
      double height,
      ) {
    final offsets = <Offset>[
      const Offset(0.24, 0.30),
      const Offset(0.62, 0.25),
      const Offset(0.54, 0.48),
      const Offset(0.75, 0.42),
    ];

    return List.generate(_places.length, (index) {
      final place = _places[index];
      final point = offsets[index];
      final active = _selectedPlace?.id == place.id;

      return Positioned(
        left: width * point.dx - 19,
        top: height * point.dy - 38,
        child: GestureDetector(
          onTap: () => _openPlace(place),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.blue500
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  place.name,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? Colors.white
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? AppColors.blue500
                      : Colors.white,
                  border: Border.all(
                    color: AppColors.blue500,
                    width: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ============================================================
  // BOTTOM CARDS
  // ============================================================

  Widget _buildHintCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Khám phá bản đồ',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tìm kiếm địa điểm, xem thông tin và bắt đầu chỉ đường.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(MapPlaceUi place) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.place_rounded,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${place.distanceText} • ${place.openInfo}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedPlace = null;
                  });
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metric(
                  Icons.route_outlined,
                  '3000 m',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metric(
                  Icons.schedule_outlined,
                  '50 min',
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: () => _openPlace(place),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.blue500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(
      IconData icon,
      String text,
      ) {
    return Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.blue50.withOpacity(0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.blue500,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH SHEET
  // ============================================================

  Future<void> _openSearchSheet() async {
    final place = await showModalBottomSheet<MapPlaceUi>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MapSearchSheet(
        places: _places,
      ),
    );

    if (place == null) return;

    setState(() {
      _selectedPlace = place;
    });
  }

  Future<void> _openPlace(MapPlaceUi place) async {
    final route = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceDetailScreen(
          place: place,
        ),
      ),
    );

    if (route == true) {
      setState(() {
        _selectedPlace = place;
      });
    }
  }

  Widget _mapButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.97),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

// ============================================================================
// SEARCH SHEET
// Bố cục: Search -> Danh mục -> Grid 2 cột
// ============================================================================

class _MapSearchSheet extends StatefulWidget {
  final List<MapPlaceUi> places;

  const _MapSearchSheet({
    required this.places,
  });

  @override
  State<_MapSearchSheet> createState() => _MapSearchSheetState();
}

class _MapSearchSheetState extends State<_MapSearchSheet> {
  final TextEditingController _controller = TextEditingController();

  final List<String> _categories = const [
    'Tất cả',
    'Ăn uống',
    'Check-in',
    'Thiên nhiên',
    'Văn hóa',
    'Local',
  ];

  String _selectedCategory = 'Tất cả';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<MapPlaceUi> get _results {
    final keyword = _controller.text.trim().toLowerCase();

    return widget.places.where((place) {
      final matchesKeyword =
          keyword.isEmpty ||
              place.name.toLowerCase().contains(keyword) ||
              place.address.toLowerCase().contains(keyword) ||
              place.subtitle.toLowerCase().contains(keyword) ||
              place.tags.join(' ').toLowerCase().contains(keyword);

      if (!matchesKeyword) return false;

      if (_selectedCategory == 'Tất cả') {
        return true;
      }

      final source = [
        place.name,
        place.subtitle,
        place.address,
        ...place.tags,
      ].join(' ').toLowerCase();

      switch (_selectedCategory) {
        case 'Ăn uống':
          return source.contains('ẩm thực') ||
              source.contains('cà phê') ||
              source.contains('ăn') ||
              source.contains('đặc sản');

        case 'Check-in':
          return source.contains('check-in') ||
              source.contains('sống ảo') ||
              source.contains('view đẹp');

        case 'Thiên nhiên':
          return source.contains('hồ') ||
              source.contains('vườn') ||
              source.contains('đồi') ||
              source.contains('thiên nhiên');

        case 'Văn hóa':
          return source.contains('văn hóa') ||
              source.contains('dinh') ||
              source.contains('ga');

        case 'Local':
          return source.contains('local') ||
              source.contains('chợ') ||
              source.contains('đặc sản');

        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.58,
      maxChildSize: 0.96,
      snap: true,
      snapSizes: const [0.58, 0.88, 0.96],
      builder: (context, scrollController) {
        final results = _results;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.blue100,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 16),

              // SEARCH
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                ),
                child: TextField(
                  controller: _controller,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Bạn muốn đi đâu?',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                      onPressed: () {
                        _controller.clear();
                        setState(() {});
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 19,
                      ),
                    ),
                    filled: true,
                    fillColor:
                    AppColors.blue50.withOpacity(0.45),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                      BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // CATEGORY TITLE
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                ),
                child: Row(
                  children: [
                    const Text(
                      'Danh mục',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 16,
                              color: AppColors.blue500,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Bộ lọc',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.blue500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                height: 38,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final category =
                    _categories[index];
                    final active =
                        _selectedCategory == category;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                      child: AnimatedContainer(
                        duration:
                        const Duration(milliseconds: 180),
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 15,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.blue500
                              : AppColors.blue50,
                          borderRadius:
                          BorderRadius.circular(20),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              // LIST TITLE
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                ),
                child: Row(
                  children: [
                    Text(
                      _controller.text.trim().isEmpty
                          ? 'Gợi ý địa điểm'
                          : 'Kết quả tìm kiếm',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${results.length} địa điểm',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // GRID
              Expanded(
                child: results.isEmpty
                    ? const _SearchEmptyState()
                    : GridView.builder(
                  controller: scrollController,
                  padding:
                  const EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    24,
                  ),
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.76,
                  ),
                  itemCount: results.length,
                  itemBuilder: (_, index) {
                    final place = results[index];

                    return _PlaceGridCard(
                      place: place,
                      onTap: () async {
                        await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PlaceDetailScreen(
                                  place: place,
                                ),
                          ),
                        );

                        if (!context.mounted) return;

                        // Chỉ chọn địa điểm để đưa về Map
                        // khi người dùng quay lại từ chi tiết.
                        Navigator.pop(
                          context,
                          place,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// GRID PLACE CARD
// ============================================================================

class _PlaceGridCard extends StatelessWidget {
  final MapPlaceUi place;
  final VoidCallback onTap;

  const _PlaceGridCard({
    required this.place,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.blue100.withOpacity(0.42),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _PlaceImage(place: place),

                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.94),
                        borderRadius:
                        BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Color(0xFFFFB547),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            place.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
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
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  11,
                  10,
                  11,
                  11,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        const Icon(
                          Icons.route_outlined,
                          size: 14,
                          color: AppColors.blue500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place.distanceText,
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color:
                              AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _shortCategory(place),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortCategory(MapPlaceUi place) {
    if (place.tags.isEmpty) return 'Địa điểm';

    return place.tags.take(2).join(' • ');
  }
}

class _PlaceImage extends StatelessWidget {
  final MapPlaceUi place;

  const _PlaceImage({
    required this.place,
  });

  @override
  Widget build(BuildContext context) {
    if (place.imageAsset != null) {
      return Image.asset(
        place.imageAsset!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _placeholder(),
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.blue100,
            AppColors.blue50,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.landscape_outlined,
        size: 36,
        color: AppColors.blue500,
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 34,
              color: AppColors.blue300,
            ),
            SizedBox(height: 10),
            Text(
              'Không tìm thấy địa điểm',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Thử từ khóa hoặc danh mục khác.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MAP PAINTERS - UI MOCK ONLY
// ============================================================================

class _MapPainter extends CustomPainter {
  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final mainRoad = Paint()
      ..color = const Color(0xFFD7E6EF)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    final subRoad = Paint()
      ..color = const Color(0xFFE7F0F5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 6; i++) {
      final y = 100.0 + i * 110;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + 35),
        i.isEven ? mainRoad : subRoad,
      );
    }

    for (int i = 0; i < 5; i++) {
      final x = 30.0 + i * 85;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + 40, size.height),
        i.isEven ? subRoad : mainRoad,
      );
    }

    final park = Paint()
      ..color = const Color(0xFFDFF2E3)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.66,
          size.height * 0.12,
          size.width * 0.26,
          size.height * 0.32,
        ),
        const Radius.circular(24),
      ),
      park,
    );
  }

  @override
  bool shouldRepaint(
      covariant CustomPainter oldDelegate,
      ) => false;
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final routePaint = Paint()
      ..color = AppColors.blue500
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(
        size.width * 0.18,
        size.height * 0.80,
      )
      ..lineTo(
        size.width * 0.22,
        size.height * 0.66,
      )
      ..lineTo(
        size.width * 0.40,
        size.height * 0.58,
      )
      ..lineTo(
        size.width * 0.55,
        size.height * 0.40,
      )
      ..lineTo(
        size.width * 0.62,
        size.height * 0.25,
      );

    canvas.drawPath(path, routePaint);
  }

  @override
  bool shouldRepaint(
      covariant CustomPainter oldDelegate,
      ) => false;
}
