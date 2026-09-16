import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../map/screens/place_detail_screen.dart';
import '../models/trip_ui_models.dart';

class TripDetailScreen extends StatefulWidget {
  final TripUi trip;

  const TripDetailScreen({
    super.key,
    required this.trip,
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late TripUi _trip;
  int _selectedDay = 0;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3F8),
      body: WillPopScope(
        onWillPop: () async {
          Navigator.pop(context, _trip);
          return false;
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildFullScreenMap(),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(
                  children: [
                    _circleMapButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context, _trip),
                    ),
                    const Spacer(),
                    _circleMapButton(
                      icon: Icons.my_location_rounded,
                      onTap: () => _message(
                        'UI demo: đưa bản đồ về vị trí hiện tại.',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            DraggableScrollableSheet(
              initialChildSize: 0.47,
              minChildSize: 0.24,
              maxChildSize: 0.92,
              snap: true,
              snapSizes: const [0.24, 0.47, 0.92],
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 18,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: CustomScrollView(
                    controller: scrollController,
                    physics: const ClampingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
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
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: _buildTripInfo(),
                            ),
                            const SizedBox(height: 18),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: _buildDayTabs(),
                            ),
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),

                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          32,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(
                            [
                              _buildScheduleContent(),
                              const SizedBox(height: 24),
                              _buildAiAction(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAP
  // ============================================================

  Widget _buildFullScreenMap() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: const Color(0xFFEAF3F8),
              child: CustomPaint(
                painter: _MapPatternPainter(),
              ),
            ),

            Positioned(
              top: 130,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  _trip.destination,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary.withOpacity(0.45),
                  ),
                ),
              ),
            ),

            ..._buildPlacePins(
              constraints.maxWidth,
              constraints.maxHeight,
            ),

            if (_trip.isGroup)
              ..._buildMemberPins(
                constraints.maxWidth,
                constraints.maxHeight,
              ),

            if (_trip.isActive)
              Positioned(
                left: 14,
                top: 92,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.navigation_rounded,
                        size: 15,
                        color: AppColors.blue500,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Đang theo dõi hành trình',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildPlacePins(
      double width,
      double height,
      ) {
    if (_trip.places.isEmpty) return [];

    final offsets = <Offset>[
      const Offset(0.24, 0.23),
      const Offset(0.54, 0.18),
      const Offset(0.72, 0.30),
      const Offset(0.39, 0.35),
      const Offset(0.79, 0.20),
    ];

    return List.generate(
      _trip.places.length.clamp(0, 5),
          (index) {
        final point = offsets[index % offsets.length];

        return Positioned(
          left: width * point.dx - 18,
          top: height * point.dy - 18,
          child: GestureDetector(
            onTap: () => _message(
              'Địa điểm: ${_trip.places[index].name}',
            ),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.blue500,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildMemberPins(
      double width,
      double height,
      ) {
    final members = _trip.members.isEmpty
        ? const [
      TripMemberUi(
        name: 'Bạn',
        isOwner: true,
        lastSeen: 'Vừa xong',
      ),
      TripMemberUi(
        name: 'An',
        lastSeen: '2 phút trước',
      ),
      TripMemberUi(
        name: 'Linh',
        lastSeen: '5 phút trước',
      ),
    ]
        : _trip.members;

    final offsets = <Offset>[
      const Offset(0.20, 0.38),
      const Offset(0.63, 0.27),
      const Offset(0.78, 0.41),
    ];

    return List.generate(
      members.length.clamp(0, 3),
          (index) {
        final member = members[index];
        final point = offsets[index % offsets.length];

        return Positioned(
          left: width * point.dx - 22,
          top: height * point.dy - 22,
          child: GestureDetector(
            onTap: () => _message(
              '${member.name} • ${member.lastSeen}',
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.blue500,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    member.name.isEmpty
                        ? '?'
                        : member.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue500,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.94),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _circleMapButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  // ============================================================
  // TRIP INFO
  // ============================================================

  Widget _buildTripInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 66,
          height: 66,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.blue50,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Image.asset(
            _trip.coverAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return const Icon(
                Icons.luggage_outlined,
                color: AppColors.blue500,
              );
            },
          ),
        ),

        const SizedBox(width: 13),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _trip.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${_trip.days} ngày • ${_trip.places.length} địa điểm',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 15,
                    color: AppColors.blue500,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _trip.destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        _smallAction(
          icon: Icons.ios_share_rounded,
          onTap: () => _message(
            'UI demo: chia sẻ lịch trình.',
          ),
        ),

        const SizedBox(width: 6),

        _smallAction(
          icon: _trip.isGroup
              ? Icons.groups_rounded
              : Icons.edit_outlined,
          onTap: _trip.isGroup
              ? _showGroupMembers
              : () => _message(
            'UI demo: chỉnh sửa thông tin chung của lịch trình.',
          ),
        ),
      ],
    );
  }

  Widget _smallAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.blue50.withOpacity(0.55),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          icon,
          size: 19,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  // ============================================================
  // DAYS / PLACES
  // ============================================================

  Widget _buildDayTabs() {
    final labels = [
      'Tất cả',
      ...List.generate(
        _trip.days,
            (index) => 'Ngày ${index + 1}',
      ),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final active = _selectedDay == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDay = index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.blue500
                    : AppColors.blue50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  fontSize: 13,
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
    );
  }

  Widget _buildScheduleContent() {
    if (_selectedDay == 0) {
      return Column(
        children: List.generate(
          _trip.days,
              (index) => _dayCard(index + 1),
        ),
      );
    }

    return _singleDay(_selectedDay);
  }

  Widget _dayCard(int day) {
    final places = _trip.places
        .where((item) => item.day == day)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.blue100.withOpacity(0.60),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blue500,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    'Ngày $day',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    _trip.destination,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),

                Text(
                  '${places.length} địa điểm',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (places.isEmpty)
              _addPlaceArea(day)
            else ...[
              ...places.map(_placeRow),
              const SizedBox(height: 4),
              _addPlaceArea(day),
            ],
          ],
        ),
      ),
    );
  }

  Widget _singleDay(int day) {
    final places = _trip.places
        .where((item) => item.day == day)
        .toList();

    return Column(
      children: [
        if (places.isEmpty)
          _addPlaceArea(day)
        else ...[
          ...places.map(_placeRow),
          const SizedBox(height: 8),
          _addPlaceArea(day),
        ],
      ],
    );
  }

  Widget _addPlaceArea(int day) {
    return InkWell(
      onTap: () => _addPlace(day),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 15,
        ),
        decoration: BoxDecoration(
          color: AppColors.blue50.withOpacity(0.30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.blue100,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_rounded,
              size: 19,
              color: AppColors.blue500,
            ),
            const SizedBox(width: 6),
            Text(
              'Thêm địa điểm cho ngày $day',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeRow(TripPlaceUi place) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.blue50.withOpacity(0.38),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.place_rounded,
                size: 20,
                color: AppColors.blue500,
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${place.startTime} – ${place.endTime}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: AppColors.textSecondary,
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  _editPlace(place);
                } else if (value == 'delete') {
                  _deletePlace(place);
                } else if (value == 'map') {
                  _message(
                    'UI demo: tập trung bản đồ vào ${place.name}.',
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'map',
                  child: Text('Xem trên bản đồ'),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Sửa'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Xoá'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // AI
  // ============================================================

  Widget _buildAiAction() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 19,
                color: AppColors.blue500,
              ),
              SizedBox(width: 8),
              Text(
                'AI hỗ trợ lịch trình',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _trip.places.isEmpty
                ? 'Thêm ít nhất một địa điểm để bắt đầu nhận gợi ý địa điểm tiếp theo.'
                : 'AI có thể gợi ý địa điểm đi tiếp và hỗ trợ sắp xếp toàn bộ chuyến đi.',
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => _message(
                'UI demo: AI sẽ tạo và sắp xếp lịch trình hoàn chỉnh.',
              ),
              icon: const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
              ),
              label: const Text(
                'AI lên lịch cho tôi',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.blue500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _addPlace(int day) async {
    final result = await showModalBottomSheet<TripPlaceUi>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPlaceSheet(day: day),
    );

    if (result == null) return;

    setState(() {
      _trip = _trip.copyWith(
        places: [
          ..._trip.places,
          result,
        ],
      );
    });
  }

  Future<void> _editPlace(
      TripPlaceUi place,
      ) async {
    final result = await showModalBottomSheet<TripPlaceUi>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPlaceSheet(
        day: place.day,
        initialPlace: place,
      ),
    );

    if (result == null) return;

    final list = [..._trip.places];
    final index = list.indexOf(place);

    if (index == -1) return;

    list[index] = result;

    setState(() {
      _trip = _trip.copyWith(
        places: list,
      );
    });
  }

  void _deletePlace(
      TripPlaceUi place,
      ) {
    setState(() {
      final list = [..._trip.places];
      list.remove(place);

      _trip = _trip.copyWith(
        places: list,
      );
    });
  }

  void _showGroupMembers() {
    final members = _trip.members.isEmpty
        ? const [
      TripMemberUi(
        name: 'Bạn',
        isOwner: true,
        lastSeen: 'Vừa xong',
      ),
      TripMemberUi(
        name: 'An',
        lastSeen: '2 phút trước',
      ),
      TripMemberUi(
        name: 'Linh',
        lastSeen: '5 phút trước',
      ),
    ]
        : _trip.members;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupMembersSheet(
        tripTitle: _trip.title,
        members: members,
      ),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(text),
      ),
    );
  }
}

// ============================================================================
// ADD PLACE SHEET
// Tìm kiếm + Ưa thích dùng chung dữ liệu Map
// ============================================================================

class _AddPlaceSheet extends StatefulWidget {
  final int day;
  final TripPlaceUi? initialPlace;

  const _AddPlaceSheet({
    required this.day,
    this.initialPlace,
  });

  @override
  State<_AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends State<_AddPlaceSheet> {
  final TextEditingController _searchController =
  TextEditingController();

  int _tab = 0;
  String? _selectedPlace;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<String> _searchPlaces = const [
    'Hồ Xuân Hương',
    'Quảng trường Lâm Viên',
    'Vườn hoa thành phố Đà Lạt',
    'Dinh Bảo Đại',
    'Đồi chè Cầu Đất',
    'Chợ Đà Lạt',
    'Ga Đà Lạt',
  ];

  @override
  void initState() {
    super.initState();

    final initial = widget.initialPlace;

    if (initial != null) {
      _selectedPlace = initial.name;
      _searchController.text = initial.name;
      _startTime = _parseTime(initial.startTime);
      _endTime = _parseTime(initial.endTime);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');

    if (parts.length != 2) return null;

    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _formatTime(TimeOfDay? value) {
    if (value == null) return '--:--';

    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  bool get _canSubmit =>
      _selectedPlace != null &&
          _startTime != null &&
          _endTime != null;

  @override
  Widget build(BuildContext context) {
    final keyboard =
        MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: keyboard,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.76,
        minChildSize: 0.52,
        maxChildSize: 0.92,
        expand: false,
        snap: true,
        snapSizes: const [
          0.52,
          0.76,
          0.92,
        ],
        builder: (
            context,
            scrollController,
            ) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),

                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.blue100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 15),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.initialPlace == null
                                  ? 'Thêm địa điểm'
                                  : 'Sửa địa điểm',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color:
                                AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Ngày ${widget.day}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color:
                                AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  child: _buildTabs(),
                ),

                const SizedBox(height: 14),

                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      18,
                    ),
                    children: [
                      if (_tab == 0)
                        _buildSearchTab()
                      else
                        _buildFavoriteTab(),

                      AnimatedSwitcher(
                        duration: const Duration(
                          milliseconds: 220,
                        ),
                        child: _selectedPlace == null
                            ? const SizedBox.shrink()
                            : Column(
                          key: ValueKey(
                            _selectedPlace,
                          ),
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),

                            Container(
                              width: double.infinity,
                              padding:
                              const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.blue50
                                    .withOpacity(0.35),
                                borderRadius:
                                BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.place_rounded,
                                    size: 19,
                                    color:
                                    AppColors.blue500,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedPlace!,
                                      maxLines: 1,
                                      overflow:
                                      TextOverflow.ellipsis,
                                      style:
                                      const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight:
                                        FontWeight.w700,
                                        color: AppColors
                                            .textPrimary,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedPlace =
                                        null;
                                        _startTime = null;
                                        _endTime = null;
                                      });
                                    },
                                    child: const Text(
                                      'Đổi',
                                      style: TextStyle(
                                        fontWeight:
                                        FontWeight.w700,
                                        color: AppColors
                                            .blue500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            const Text(
                              'Chọn thời gian',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                FontWeight.w700,
                                color:
                                AppColors.textPrimary,
                              ),
                            ),

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Expanded(
                                  child: _timeBox(
                                    label: 'Bắt đầu',
                                    value: _startTime,
                                    onTap: () =>
                                        _pickTime(true),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _timeBox(
                                    label: 'Kết thúc',
                                    value: _endTime,
                                    onTap: () =>
                                        _pickTime(false),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 22),

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _canSubmit
                                    ? _submit
                                    : null,
                                style: ElevatedButton
                                    .styleFrom(
                                  elevation: 0,
                                  backgroundColor:
                                  AppColors.blue500,
                                  disabledBackgroundColor:
                                  AppColors.blue100,
                                  foregroundColor:
                                  Colors.white,
                                  shape:
                                  RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius
                                        .circular(26),
                                  ),
                                ),
                                child: Text(
                                  widget.initialPlace ==
                                      null
                                      ? 'Thêm địa điểm'
                                      : 'Lưu thay đổi',
                                  style:
                                  const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight:
                                    FontWeight.w700,
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
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.blue50.withOpacity(0.48),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _tabButton(
            index: 0,
            icon: Icons.search_rounded,
            text: 'Tìm kiếm',
          ),
          _tabButton(
            index: 1,
            icon: Icons.favorite_border_rounded,
            text: 'Ưa thích',
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required int index,
    required IconData icon,
    required String text,
  }) {
    final active = _tab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? Colors.white
                : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: active
                    ? AppColors.blue500
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    final keyword =
    _searchController.text.trim().toLowerCase();

    final results = keyword.isEmpty
        ? _searchPlaces
        : _searchPlaces
        .where(
          (item) => item
          .toLowerCase()
          .contains(keyword),
    )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tìm và chọn địa điểm',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 9),

        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'VD: Hồ Xuân Hương...',
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.textSecondary,
            ),
            filled: true,
            fillColor:
            AppColors.blue50.withOpacity(0.45),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 10),

        if (results.isEmpty)
          const _EmptyPlaceState(
            icon: Icons.search_off_rounded,
            title: 'Không tìm thấy địa điểm',
            subtitle:
            'Hãy thử một từ khóa khác.',
          )
        else
          ...results.map(
                (name) => _placeChoice(
              name: name,
            ),
          ),
      ],
    );
  }

  Widget _buildFavoriteTab() {
    final folders =
        FavoritePlaceStore.folderNames;

    if (folders.isEmpty) {
      return const _EmptyPlaceState(
        icon: Icons.favorite_border_rounded,
        title: 'Chưa có địa điểm yêu thích',
        subtitle:
        'Hãy lưu địa điểm từ trang Map trước.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thư mục yêu thích',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 10),

        ...folders.map(
              (folder) {
            final places =
            FavoritePlaceStore.placesIn(folder);

            return Padding(
              padding:
              const EdgeInsets.only(bottom: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                  AppColors.blue50.withOpacity(
                    0.32,
                  ),
                  borderRadius:
                  BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.folder_outlined,
                          size: 19,
                          color: AppColors.blue500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            folder,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight:
                              FontWeight.w700,
                              color:
                              AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${places.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors
                                .textSecondary,
                          ),
                        ),
                      ],
                    ),

                    if (places.isEmpty) ...[
                      const SizedBox(height: 9),
                      const Text(
                        'Chưa có địa điểm trong thư mục này.',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                          AppColors.textSecondary,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 9),
                      ...places.map(
                            (place) => _placeChoice(
                          name: place.name,
                          subtitle: place.address,
                          favorite: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _placeChoice({
    required String name,
    String? subtitle,
    bool favorite = false,
  }) {
    final selected =
        _selectedPlace == name;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPlace = name;
            _searchController.text = name;
          });
        },
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : const Color(0xFFF8FAFB),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? AppColors.blue300
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: Icon(
                  favorite
                      ? Icons.favorite_rounded
                      : Icons.place_outlined,
                  size: 19,
                  color: AppColors.blue500,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                        FontWeight.w700,
                        color:
                        AppColors.textPrimary,
                      ),
                    ),

                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors
                              .textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.blue500,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeBox({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 7),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
            ),
            decoration: BoxDecoration(
              color:
              AppColors.blue50.withOpacity(0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: AppColors.blue500,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(value),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: value == null
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickTime(
      bool start,
      ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start
          ? (_startTime ??
          const TimeOfDay(
            hour: 8,
            minute: 0,
          ))
          : (_endTime ??
          const TimeOfDay(
            hour: 9,
            minute: 30,
          )),
    );

    if (picked == null) return;

    setState(() {
      if (start) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  void _submit() {
    Navigator.pop(
      context,
      TripPlaceUi(
        name: _selectedPlace!,
        startTime: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
        day: widget.day,
      ),
    );
  }
}

// ============================================================================
// GROUP MEMBERS SHEET
// ============================================================================

class _GroupMembersSheet extends StatelessWidget {
  final String tripTitle;
  final List<TripMemberUi> members;

  const _GroupMembersSheet({
    required this.tripTitle,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.54,
      minChildSize: 0.36,
      maxChildSize: 0.80,
      expand: false,
      snap: true,
      snapSizes: const [
        0.36,
        0.54,
        0.80,
      ],
      builder: (
          context,
          scrollController,
          ) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.blue100,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 15),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nhóm chuyến đi',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$tripTitle • ${members.length} thành viên',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color:
                              AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    24,
                  ),
                  itemCount: members.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 10),
                  itemBuilder: (
                      context,
                      index,
                      ) {
                    final member = members[index];

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.blue50
                            .withOpacity(0.35),
                        borderRadius:
                        BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          _MemberAvatar(
                            member: member,
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        member.name,
                                        style:
                                        const TextStyle(
                                          fontSize: 14,
                                          fontWeight:
                                          FontWeight
                                              .w700,
                                          color: AppColors
                                              .textPrimary,
                                        ),
                                      ),
                                    ),

                                    if (member
                                        .isOwner) ...[
                                      const SizedBox(
                                        width: 7,
                                      ),
                                      Container(
                                        padding:
                                        const EdgeInsets
                                            .symmetric(
                                          horizontal: 7,
                                          vertical: 3,
                                        ),
                                        decoration:
                                        BoxDecoration(
                                          color: AppColors
                                              .blue100,
                                          borderRadius:
                                          BorderRadius
                                              .circular(
                                            10,
                                          ),
                                        ),
                                        child:
                                        const Text(
                                          'Chủ',
                                          style:
                                          TextStyle(
                                            fontSize: 10,
                                            fontWeight:
                                            FontWeight
                                                .w700,
                                            color: AppColors
                                                .blue500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                const SizedBox(height: 3),

                                Text(
                                  'Vị trí • ${member.lastSeen}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors
                                        .textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Icon(
                            Icons.map_outlined,
                            color: AppColors.blue500,
                          ),
                        ],
                      ),
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

class _MemberAvatar extends StatelessWidget {
  final TripMemberUi member;

  const _MemberAvatar({
    required this.member,
  });

  @override
  Widget build(BuildContext context) {
    final firstLetter = member.name.isEmpty
        ? '?'
        : member.name
        .substring(0, 1)
        .toUpperCase();

    return Container(
      width: 46,
      height: 46,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.blue50,
      ),
      child: member.avatarAsset.isEmpty
          ? Center(
        child: Text(
          firstLetter,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.blue500,
          ),
        ),
      )
          : Image.asset(
        member.avatarAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Center(
            child: Text(
              firstLetter,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.blue500,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyPlaceState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyPlaceState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 22,
      ),
      decoration: BoxDecoration(
        color: AppColors.blue50.withOpacity(0.30),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.blue300,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MAP PLACEHOLDER
// ============================================================================

class _MapPatternPainter extends CustomPainter {
  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final roadPaint = Paint()
      ..color = const Color(0xFFD2E2EB)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final thinRoadPaint = Paint()
      ..color = const Color(0xFFDCE8EE)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 10; i++) {
      final y = 30.0 + i * 55;

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + 24),
        i.isEven ? roadPaint : thinRoadPaint,
      );
    }

    for (int i = 0; i < 7; i++) {
      final x = 32.0 + i * 70;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x + 35, size.height),
        i.isEven ? thinRoadPaint : roadPaint,
      );
    }

    final park = Paint()
      ..color = const Color(0xFFDDEFD9)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.62,
          size.height * 0.10,
          size.width * 0.33,
          size.height * 0.38,
        ),
        const Radius.circular(28),
      ),
      park,
    );

    final lake = Paint()
      ..color = const Color(0xFFB9DBF4)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.66,
        size.height * 0.18,
        34,
        92,
      ),
      lake,
    );
  }

  @override
  bool shouldRepaint(
      covariant CustomPainter oldDelegate,
      ) {
    return false;
  }
}
