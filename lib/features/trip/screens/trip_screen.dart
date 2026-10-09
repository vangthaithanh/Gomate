import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/gomate_main_tab_header.dart';
import '../../../core/widgets/gomate_search_field.dart';
import '../../../core/widgets/snackbar.dart';
import '../../messages/data/message_repository.dart';
import '../../messages/widgets/message_widgets.dart';
import '../../map/state/map_ui_session.dart';
import '../models/trip_ui_models.dart';
import 'create_trip_screen.dart';
import 'trip_detail_screen.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() =>
      _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  final MessageRepository _messageRepository =
      DemoMessageRepository.instance;

  @override
  void initState() {
    super.initState();

    // Trip là nguồn dữ liệu UI demo hiện tại.
    // Map dùng cùng danh sách này thay vì tạo một bộ demo khác.
    GoMateMapUiSession.registerTrips(_trips);

    GoMateMapUiSession.revision.addListener(
      _pullTripChangesFromMap,
    );
  }

  void _pullTripChangesFromMap() {
    if (!mounted) return;

    final shared = GoMateMapUiSession.availableTrips;

    setState(() {
      _trips
        ..clear()
        ..addAll(shared);
    });
  }

  void _syncMapTripSession() {
    GoMateMapUiSession.registerTrips(_trips);
  }

  late final List<TripUi> _trips = <TripUi>[
    TripUi(
      id: 'trip-personal-v2',
      title: 'Đà lạt cá nhân',
      days: 4,
      destination: 'Đà Lạt',
      coverAsset: 'assets/images/home_dalat.jpg',
      currentUserRole: TripAccessRole.personal,
      startDate: DateTime(2026, 10, 12),
      endDate: DateTime(2026, 10, 15),
      members: const [
        TripMemberUi(
          id: 'me',
          name: 'Thune',
          role: TripAccessRole.personal,
        ),
      ],
    ),
    TripUi(
      id: 'trip_da_lat_leader',
      title: 'Đà lạt ơi',
      days: 4,
      destination: 'Đà Lạt',
      coverAsset: 'assets/images/checkin.jpg',
      isGroup: true,
      currentUserRole: TripAccessRole.leader,
      conversationId: 'group_cover_read',
      startDate: DateTime(2026, 10, 12),
      endDate: DateTime(2026, 10, 15),
      members: const [
        TripMemberUi(
          id: 'me',
          name: 'Thune',
          role: TripAccessRole.leader,
        ),
        TripMemberUi(
          id: 'chi',
          name: 'ChiThanh',
          role: TripAccessRole.deputy,
        ),
        TripMemberUi(
          id: 'thune_a',
          name: 'Thune',
        ),
        TripMemberUi(
          id: 'thanh',
          name: 'Thanh',
        ),
      ],
    ),
    TripUi(
      id: 'trip_da_lat_deputy',
      title: 'Đà lạt ơi',
      days: 4,
      destination: 'Đà Lạt',
      coverAsset: 'assets/images/survey_city.jpg',
      isGroup: true,
      currentUserRole: TripAccessRole.deputy,
      conversationId: 'group_deputy_demo',
      startDate: DateTime(2026, 10, 12),
      endDate: DateTime(2026, 10, 15),
      members: const [
        TripMemberUi(
          id: 'me',
          name: 'Thune',
          role: TripAccessRole.deputy,
        ),
        TripMemberUi(
          id: 'chi',
          name: 'ChiThanh',
          role: TripAccessRole.leader,
        ),
        TripMemberUi(
          id: 'thune_a',
          name: 'Thune',
        ),
      ],
    ),
    TripUi(
      id: 'trip_da_lat_member',
      title: 'Đà lạt ơi',
      days: 4,
      destination: 'Đà Lạt',
      coverAsset: 'assets/images/thiennhien.jpg',
      isGroup: true,
      currentUserRole: TripAccessRole.member,
      conversationId: 'group_unread',
      startDate: DateTime(2026, 10, 12),
      endDate: DateTime(2026, 10, 15),
      members: const [
        TripMemberUi(
          id: 'me',
          name: 'Thune',
        ),
        TripMemberUi(
          id: 'chi',
          name: 'ChiThanh',
          role: TripAccessRole.leader,
        ),
        TripMemberUi(
          id: 'thune_a',
          name: 'Thune',
          role: TripAccessRole.deputy,
        ),
      ],
    ),
  ];

  bool get _isSearching =>
      _searchController.text.trim().isNotEmpty;

  List<TripUi> get _visibleTrips {
    final query =
    _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return List<TripUi>.unmodifiable(_trips);
    }

    return _trips
        .where(
          (trip) =>
      trip.title.toLowerCase().contains(query) ||
          trip.destination.toLowerCase().contains(query),
    )
        .toList(growable: false);
  }

  TripUi? get _pinnedTrip {
    for (final item in _trips) {
      if (item.isActive) {
        return item;
      }
    }

    return null;
  }

  @override
  void dispose() {
    GoMateMapUiSession.revision.removeListener(
      _pullTripChangesFromMap,
    );

    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createTrip() async {
    final created =
    await Navigator.of(context).push<TripUi>(
      MaterialPageRoute(
        builder: (_) => CreateTripScreen(
          messageRepository: _messageRepository,
        ),
      ),
    );

    if (!mounted || created == null) {
      return;
    }

    final normalized =
    created.copyWith(isActive: false);

    setState(() {
      _trips.insert(0, normalized);
    });

    _syncMapTripSession();

    await _openTrip(normalized);
  }

  Future<void> _openTrip(
      TripUi trip,
      ) async {
    final result =
    await Navigator.of(context).push<TripDetailResult>(
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(
          trip: trip,
          messageRepository: _messageRepository,
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final index = _trips.indexWhere(
          (item) => item.id == result.trip.id,
    );

    if (result.removeFromList) {
      if (index >= 0) {
        setState(() {
          _trips.removeAt(index);
        });

        _syncMapTripSession();
      }

      return;
    }

    if (index >= 0) {
      setState(() {
        _trips[index] = result.trip;
      });

      _syncMapTripSession();
    }
  }

  Future<void> _openActions(
      TripUi trip,
      ) async {
    final result =
    await GoMateBottomSheet.show<_ListAction>(
      context: context,
      contentPadding: EdgeInsets.zero,
      child: _ListActionContent(
        trip: trip,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    switch (result) {
      case _ListAction.pin:
        _pin(trip);
        break;

      case _ListAction.unpin:
        _unpin(trip);
        break;

      case _ListAction.delete:
        await _deleteTrip(trip);
        break;

      case _ListAction.leave:
        await _leaveTrip(trip);
        break;
    }
  }

  void _pin(
      TripUi target,
      ) {
    setState(() {
      for (var i = 0; i < _trips.length; i++) {
        _trips[i] = _trips[i].copyWith(
          isActive: _trips[i].id == target.id,
        );
      }
    });

    _syncMapTripSession();

    GoMateSnackBar.show(
      context,
      message: 'Đã ghim lịch trình',
      bottomOffset: 92,
    );
  }

  void _unpin(
      TripUi target,
      ) {
    final index = _trips.indexWhere(
          (item) => item.id == target.id,
    );

    if (index < 0) return;

    setState(() {
      _trips[index] =
          _trips[index].copyWith(isActive: false);
    });

    _syncMapTripSession();

    GoMateSnackBar.show(
      context,
      message: 'Đã bỏ ghim lịch trình',
      bottomOffset: 92,
    );
  }

  Future<void> _deleteTrip(
      TripUi trip,
      ) async {
    final confirmed =
    await GoMateBottomSheet.show<bool>(
      context: context,
      child: MessageConfirmContent(
        title: 'Xoá lịch trình?',
        description: trip.isGroup
            ? 'Xoá lịch trình nhóm đồng nghĩa với việc xoá đoạn chat nhóm. '
            'Hành động này không thể hoàn tác.'
            : 'Lịch trình này sẽ bị xoá vĩnh viễn. '
            'Hành động này không thể hoàn tác.',
        onConfirm: () =>
            Navigator.of(context).pop(true),
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    final conversationId = trip.conversationId;

    if (trip.isGroup && conversationId != null) {
      _messageRepository.deleteGroupAndItinerary(
        conversationId,
      );
    }

    setState(() {
      _trips.removeWhere(
            (item) => item.id == trip.id,
      );
    });

    _syncMapTripSession();

    GoMateSnackBar.show(
      context,
      message: 'Đã xoá lịch trình',
      bottomOffset: 92,
    );
  }

  Future<void> _leaveTrip(
      TripUi trip,
      ) async {
    final confirmed =
    await GoMateBottomSheet.show<bool>(
      context: context,
      child: MessageConfirmContent(
        title: 'Rời lịch trình?',
        description:
        'Rời lịch trình đồng nghĩa với việc bạn rời đoạn chat nhóm.',
        onConfirm: () =>
            Navigator.of(context).pop(true),
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    final conversationId = trip.conversationId;

    if (conversationId != null) {
      _messageRepository.leaveGroup(
        conversationId,
      );
    }

    setState(() {
      _trips.removeWhere(
            (item) => item.id == trip.id,
      );
    });

    _syncMapTripSession();

    GoMateSnackBar.show(
      context,
      message: 'Đã rời lịch trình',
      bottomOffset: 92,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final headerUi =
    GoMateMainTabHeaderMetrics.fromWidth(width);

    final visible = _visibleTrips;
    final pinned = _pinnedTrip;

    final horizontal =
    (width * 0.065).clamp(22.0, 28.0).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            GoMateMainTabHeader(
              title: 'Lịch trình',
              trailingWidget: const _TripCreateIcon(),
              onTrailingTap: _createTrip,
            ),

            SizedBox(height: headerUi.contentGap),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal:
                (width * 0.075).clamp(24.0, 30.0).toDouble(),
              ),
              child: GoMateSearchField(
                controller: _searchController,
                hintText: 'Tìm....',
                showCancel: _isSearching,
                onChanged: (_) => setState(() {}),
                onCancel: () {
                  _searchController.clear();
                  FocusScope.of(context).unfocus();
                  setState(() {});
                },
              ),
            ),

            SizedBox(
              height:
              (width * 0.050).clamp(17.0, 21.0).toDouble(),
            ),

            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                  bottom: 110,
                ),
                children: [
                  if (!_isSearching && pinned != null) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontal,
                      ),
                      child: Text(
                        'Đang diễn ra',
                        style: TextStyle(
                          fontSize:
                          (width * 0.032).clamp(11.5, 13.0).toDouble(),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    SizedBox(
                      height:
                      (width * 0.030).clamp(10.0, 13.0).toDouble(),
                    ),

                    // Khôi phục hero pinned kiểu cũ:
                    // ảnh full-width, không bị bó hẹp trong card nhỏ.
                    _PinnedTripCard(
                      trip: pinned,
                      onTap: () => _openTrip(pinned),
                    ),

                    SizedBox(
                      height:
                      (width * 0.060).clamp(20.0, 25.0).toDouble(),
                    ),
                  ],

                  if (visible.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        top: width * 0.28,
                      ),
                      child: const Center(
                        child: Text(
                          'Không tìm thấy lịch trình',
                          style: TextStyle(
                            color: AppColors.grayText,
                          ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontal,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < visible.length; i++) ...[
                            _TripCard(
                              trip: visible[i],
                              onTap: () =>
                                  _openTrip(visible[i]),
                              onMoreTap: () =>
                                  _openActions(visible[i]),
                            ),
                            if (i != visible.length - 1)
                              SizedBox(
                                height: (width * 0.050)
                                    .clamp(17.0, 21.0)
                                    .toDouble(),
                              ),
                          ],
                        ],
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

enum _ListAction {
  pin,
  unpin,
  delete,
  leave,
}

class _ListActionContent extends StatelessWidget {
  final TripUi trip;

  const _ListActionContent({
    required this.trip,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        (width * 0.075).clamp(24.0, 30.0).toDouble(),
        0,
        (width * 0.075).clamp(24.0, 30.0).toDouble(),
        (width * 0.050).clamp(18.0, 22.0).toDouble(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ListActionRow(
            icon: trip.isActive
                ? LucideIcons.pin_off
                : LucideIcons.pin,
            label: trip.isActive
                ? 'Bỏ ghim lịch trình'
                : 'Ghim lịch trình',
            onTap: () => Navigator.of(context).pop(
              trip.isActive
                  ? _ListAction.unpin
                  : _ListAction.pin,
            ),
          ),

          const Divider(
            color: AppColors.grayBorder,
          ),

          if (trip.canDeleteTrip)
            _ListActionRow(
              icon: LucideIcons.trash,
              label: 'Xoá lịch trình',
              color: AppColors.primaryText,
              onTap: () => Navigator.of(context).pop(
                _ListAction.delete,
              ),
            )
          else
            _ListActionRow(
              icon: LucideIcons.log_out,
              label: 'Rời lịch trình',
              color: AppColors.primaryText,
              onTap: () => Navigator.of(context).pop(
                _ListAction.leave,
              ),
            ),
        ],
      ),
    );
  }
}

class _ListActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ListActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: (width * 0.13).clamp(48.0, 54.0).toDouble(),
        child: Row(
          children: [
            Icon(
              icon,
              size: (width * 0.060).clamp(21.0, 24.0).toDouble(),
              color: color,
            ),
            SizedBox(
              width: (width * 0.045).clamp(15.0, 18.0).toDouble(),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize:
                (width * 0.032).clamp(11.5, 12.5).toDouble(),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripUi trip;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const _TripCard({
    required this.trip,
    required this.onTap,
    required this.onMoreTap,
  });

  String _memberLine() {
    if (trip.pendingInviteIds.isEmpty) {
      return '${trip.memberCount} thành viên';
    }

    return '${trip.memberCount} thành viên • '
        '${trip.pendingInviteIds.length} lời mời';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final cardHeight =
    (width * 0.225).clamp(84.0, 94.0).toDouble();

    final imageWidth =
    (width * 0.21).clamp(78.0, 88.0).toDouble();

    final radius =
    (width * 0.038).clamp(13.0, 16.0).toDouble();

    return Container(
      height: cardHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 9,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ảnh tràn sát viền trái của card, không có padding.
              _TripImage(
                asset: trip.coverAsset,
                width: imageWidth,
                height: cardHeight,
              ),

              SizedBox(
                width:
                (width * 0.030).clamp(10.0, 13.0).toDouble(),
              ),

              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical:
                    (width * 0.020).clamp(7.0, 9.0).toDouble(),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TripTitleWithRole(
                        trip: trip,
                        iconSize:
                        (width * 0.036).clamp(13.0, 15.0).toDouble(),
                        iconGap:
                        (width * 0.012).clamp(4.0, 5.0).toDouble(),
                        style: TextStyle(
                          fontSize:
                          (width * 0.032).clamp(11.5, 13.0).toDouble(),
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryText,
                        ),
                      ),

                      SizedBox(
                        height:
                        (width * 0.010).clamp(3.0, 4.0).toDouble(),
                      ),

                      Text(
                        trip.dateRangeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize:
                          (width * 0.025).clamp(9.0, 10.5).toDouble(),
                          height: 1.1,
                          color: AppColors.grayText,
                        ),
                      ),

                      if (trip.isGroup) ...[
                        SizedBox(
                          height:
                          (width * 0.006).clamp(2.0, 3.0).toDouble(),
                        ),

                        Text(
                          _memberLine(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize:
                            (width * 0.025).clamp(9.0, 10.5).toDouble(),
                            height: 1.1,
                            color: AppColors.grayText,
                          ),
                        ),
                      ],

                      SizedBox(
                        height:
                        (width * 0.006).clamp(2.0, 3.0).toDouble(),
                      ),

                      Text(
                        '${trip.days} ngày - ${trip.places.length} địa điểm',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize:
                          (width * 0.025).clamp(9.0, 10.5).toDouble(),
                          height: 1.1,
                          color: AppColors.grayText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              InkWell(
                onTap: onMoreTap,
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width:
                  (width * 0.13).clamp(44.0, 52.0).toDouble(),
                  child: Center(
                    child: Icon(
                      LucideIcons.ellipsis_vertical,
                      size:
                      (width * 0.050).clamp(18.0, 21.0).toDouble(),
                      color: AppColors.grayText,
                    ),
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

List<String> _pinnedTripPlaceImages(TripUi trip) {
  const demoPlaceImages = <String>[
    'assets/images/survey_landmark.jpg',
    'assets/images/thiennhien.jpg',
    'assets/images/nghiduong.jpg',
    'assets/images/checkin.jpg',
    'assets/images/survey_city.jpg',
    'assets/images/survey_beach.jpg',
  ];

  if (trip.places.isEmpty) {
    return <String>[
      trip.coverAsset.trim().isEmpty
          ? 'assets/images/home_dalat.jpg'
          : trip.coverAsset,
    ];
  }

  final count =
  trip.places.length.clamp(1, demoPlaceImages.length);

  return demoPlaceImages.take(count).toList(growable: false);
}

class _PinnedTripCard extends StatefulWidget {
  final TripUi trip;
  final VoidCallback onTap;

  const _PinnedTripCard({
    required this.trip,
    required this.onTap,
  });

  @override
  State<_PinnedTripCard> createState() =>
      _PinnedTripCardState();
}

class _PinnedTripCardState extends State<_PinnedTripCard> {
  Timer? _timer;
  int _imageIndex = 0;

  List<String> get _images =>
      _pinnedTripPlaceImages(widget.trip);

  @override
  void initState() {
    super.initState();
    _startSlideShow();
  }

  @override
  void didUpdateWidget(
      covariant _PinnedTripCard oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.trip.id != widget.trip.id ||
        oldWidget.trip.places.length != widget.trip.places.length) {
      _imageIndex = 0;
      _startSlideShow();
    }
  }

  void _startSlideShow() {
    _timer?.cancel();

    if (_images.length <= 1) return;

    _timer = Timer.periodic(
      const Duration(seconds: 5),
          (_) {
        if (!mounted) return;

        setState(() {
          _imageIndex =
              (_imageIndex + 1) % _images.length;
        });
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _memberText(TripUi trip) {
    if (trip.pendingInviteIds.isEmpty) {
      return '${trip.memberCount} thành viên';
    }

    return '${trip.memberCount} thành viên • '
        '${trip.pendingInviteIds.length} lời mời';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final height =
    (width * 0.34).clamp(122.0, 140.0).toDouble();

    final horizontal =
    (width * 0.052).clamp(18.0, 22.0).toDouble();

    final bottom =
    (width * 0.050).clamp(17.0, 21.0).toDouble();

    final images = _images;
    final safeIndex =
    _imageIndex.clamp(0, images.length - 1);
    final image = images[safeIndex];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 550),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey<String>(image),
                  child: _TripImage(
                    asset: image,
                    width: double.infinity,
                    height: height,
                  ),
                ),
              ),

              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      Color(0x14000000),
                      Color(0x82000000),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  14,
                  horizontal,
                  bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),

                    _TripTitleWithRole(
                      trip: widget.trip,
                      iconSize:
                      (width * 0.040).clamp(14.0, 16.0).toDouble(),
                      iconGap:
                      (width * 0.014).clamp(5.0, 6.0).toDouble(),
                      style: TextStyle(
                        fontSize:
                        (width * 0.044).clamp(16.0, 18.0).toDouble(),
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),

                    SizedBox(
                      height:
                      (width * 0.022).clamp(7.0, 9.0).toDouble(),
                    ),

                    _PinnedMetaRow(
                      icon: LucideIcons.calendar_days,
                      text: widget.trip.dateRangeLabel,
                    ),

                    if (widget.trip.isGroup) ...[
                      SizedBox(
                        height:
                        (width * 0.016).clamp(5.0, 7.0).toDouble(),
                      ),

                      _PinnedMetaRow(
                        icon: LucideIcons.users_round,
                        text: _memberText(widget.trip),
                      ),
                    ],

                    SizedBox(
                      height:
                      (width * 0.016).clamp(5.0, 7.0).toDouble(),
                    ),

                    Text(
                      '${widget.trip.days} ngày - '
                          '${widget.trip.places.length} địa điểm',
                      style: TextStyle(
                        fontSize:
                        (width * 0.027).clamp(10.0, 11.5).toDouble(),
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              if (images.length > 1)
                Positioned(
                  right: horizontal,
                  bottom: bottom,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      images.length,
                          (index) {
                        final active =
                            index == _imageIndex;

                        return AnimatedContainer(
                          duration:
                          const Duration(milliseconds: 220),
                          margin:
                          const EdgeInsets.only(left: 4),
                          width: active ? 12 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white
                                : Colors.white.withOpacity(0.55),
                            borderRadius:
                            BorderRadius.circular(99),
                          ),
                        );
                      },
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

class _PinnedMetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PinnedMetaRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Row(
      children: [
        Icon(
          icon,
          size:
          (width * 0.037).clamp(13.0, 15.0).toDouble(),
          color: Colors.white,
        ),
        SizedBox(
          width:
          (width * 0.014).clamp(5.0, 6.0).toDouble(),
        ),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize:
              (width * 0.027).clamp(10.0, 11.5).toDouble(),
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _TripTitleWithRole extends StatelessWidget {
  final TripUi trip;
  final TextStyle style;
  final double iconSize;
  final double iconGap;

  const _TripTitleWithRole({
    required this.trip,
    required this.style,
    required this.iconSize,
    required this.iconGap,
  });

  bool get _showLeader =>
      trip.isGroup &&
          trip.currentUserRole == TripAccessRole.leader;

  bool get _showDeputy =>
      trip.isGroup &&
          trip.currentUserRole == TripAccessRole.deputy;

  @override
  Widget build(BuildContext context) {
    final showRoleIcon = _showLeader || _showDeputy;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            trip.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (showRoleIcon) ...[
          SizedBox(width: iconGap),
          Icon(
            Icons.key,
            size: iconSize,
            color: _showLeader
                ? AppColors.primaryIcon
                : AppColors.grayText,
          ),
        ],
      ],
    );
  }
}

class _TripImage extends StatelessWidget {
  final String asset;
  final double width;
  final double height;

  const _TripImage({
    required this.asset,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedAsset = asset.trim().isEmpty
        ? 'assets/images/home_dalat.jpg'
        : asset;

    return Image.asset(
      resolvedAsset,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          width: width,
          height: height,
          color: AppColors.blue50,
          alignment: Alignment.center,
          child: const Icon(
            LucideIcons.image,
            color: AppColors.primaryIcon,
          ),
        );
      },
    );
  }
}

class _TripCreateIcon extends StatelessWidget {
  const _TripCreateIcon();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final boxSize =
    (width * (31 / 375)).clamp(29.0, 32.0).toDouble();

    final calendarSize =
    (width * (27.27 / 375)).clamp(25.0, 28.0).toDouble();

    final badgeSize =
    (width * (20.45 / 375)).clamp(18.0, 20.5).toDouble();

    final plusSize =
    (width * (13.64 / 375)).clamp(11.5, 13.5).toDouble();

    return SizedBox.square(
      dimension: boxSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Icon(
              LucideIcons.calendar,
              size: calendarSize,
              color: Colors.black,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(
                  color: Colors.white,
                  width: 1.6,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                LucideIcons.plus,
                size: plusSize,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
