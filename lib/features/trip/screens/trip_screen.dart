import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../models/trip_ui_models.dart';
import 'create_trip_screen.dart';
import 'trip_detail_screen.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Dữ liệu mẫu phục vụ UI hiện tại.
  // Không thay đổi backend / repository.
  final List<TripUi> _trips = <TripUi>[
    TripUi(
      id: 'trip-demo-1',
      title: 'Đà lạt ơi',
      days: 4,
      destination: 'Đà Lạt',
      coverAsset: 'assets/images/home_dalat.jpg',
      isActive: false,
      isGroup: true,
      members: [
        TripMemberUi(name: 'Thune'),
        TripMemberUi(name: 'ChiThanh'),
        TripMemberUi(name: 'Buji'),
        TripMemberUi(name: 'An'),
      ],
      places: [
        TripPlaceUi(name: 'Hồ Xuân Hương', startTime: '08:00', endTime: '09:00', day: 1),
        TripPlaceUi(name: 'Quảng trường Lâm Viên', startTime: '09:30', endTime: '10:30', day: 1),
        TripPlaceUi(name: 'Chợ Đà Lạt', startTime: '11:00', endTime: '12:00', day: 1),
        TripPlaceUi(name: 'Ga Đà Lạt', startTime: '13:30', endTime: '14:30', day: 2),
        TripPlaceUi(name: 'Dinh Bảo Đại', startTime: '15:00', endTime: '16:00', day: 2),
        TripPlaceUi(name: 'Hồ Tuyền Lâm', startTime: '08:00', endTime: '09:00', day: 3),
        TripPlaceUi(name: 'Thiền viện Trúc Lâm', startTime: '09:30', endTime: '10:30', day: 3),
        TripPlaceUi(name: 'Thác Datanla', startTime: '11:00', endTime: '12:00', day: 3),
        TripPlaceUi(name: 'Đồi chè Cầu Đất', startTime: '07:30', endTime: '09:00', day: 4),
        TripPlaceUi(name: 'Vườn hoa thành phố', startTime: '10:00', endTime: '11:00', day: 4),
        TripPlaceUi(name: 'Nhà thờ Con Gà', startTime: '13:00', endTime: '14:00', day: 4),
        TripPlaceUi(name: 'Đồi Robin', startTime: '15:00', endTime: '16:00', day: 4),
      ],
    ),
    TripUi(
      id: 'trip-demo-2',
      title: 'Đà lạt ơi',
      days: 4,
      destination: 'Đà Lạt',
      coverAsset: 'assets/images/home_dalat.jpg',
      isActive: false,
      isGroup: true,
      members: [
        TripMemberUi(name: 'Thune'),
        TripMemberUi(name: 'ChiThanh'),
        TripMemberUi(name: 'Buji'),
        TripMemberUi(name: 'An'),
      ],
      places: [
        TripPlaceUi(name: 'Hồ Xuân Hương', startTime: '08:00', endTime: '09:00', day: 1),
        TripPlaceUi(name: 'Quảng trường Lâm Viên', startTime: '09:30', endTime: '10:30', day: 1),
        TripPlaceUi(name: 'Chợ Đà Lạt', startTime: '11:00', endTime: '12:00', day: 1),
        TripPlaceUi(name: 'Ga Đà Lạt', startTime: '13:30', endTime: '14:30', day: 2),
        TripPlaceUi(name: 'Dinh Bảo Đại', startTime: '15:00', endTime: '16:00', day: 2),
        TripPlaceUi(name: 'Hồ Tuyền Lâm', startTime: '08:00', endTime: '09:00', day: 3),
        TripPlaceUi(name: 'Thiền viện Trúc Lâm', startTime: '09:30', endTime: '10:30', day: 3),
        TripPlaceUi(name: 'Thác Datanla', startTime: '11:00', endTime: '12:00', day: 3),
        TripPlaceUi(name: 'Đồi chè Cầu Đất', startTime: '07:30', endTime: '09:00', day: 4),
        TripPlaceUi(name: 'Vườn hoa thành phố', startTime: '10:00', endTime: '11:00', day: 4),
        TripPlaceUi(name: 'Nhà thờ Con Gà', startTime: '13:00', endTime: '14:00', day: 4),
        TripPlaceUi(name: 'Đồi Robin', startTime: '15:00', endTime: '16:00', day: 4),
      ],
    ),
    TripUi(
      id: 'trip-demo-3',
      title: 'Đà lạt ơi',
      days: 4,
      destination: 'Đà Lạt',
      coverAsset: 'assets/images/home_dalat.jpg',
      isActive: false,
      isGroup: true,
      members: [
        TripMemberUi(name: 'Thune'),
        TripMemberUi(name: 'ChiThanh'),
        TripMemberUi(name: 'Buji'),
        TripMemberUi(name: 'An'),
      ],
      places: [
        TripPlaceUi(name: 'Hồ Xuân Hương', startTime: '08:00', endTime: '09:00', day: 1),
        TripPlaceUi(name: 'Quảng trường Lâm Viên', startTime: '09:30', endTime: '10:30', day: 1),
        TripPlaceUi(name: 'Chợ Đà Lạt', startTime: '11:00', endTime: '12:00', day: 1),
        TripPlaceUi(name: 'Ga Đà Lạt', startTime: '13:30', endTime: '14:30', day: 2),
        TripPlaceUi(name: 'Dinh Bảo Đại', startTime: '15:00', endTime: '16:00', day: 2),
        TripPlaceUi(name: 'Hồ Tuyền Lâm', startTime: '08:00', endTime: '09:00', day: 3),
        TripPlaceUi(name: 'Thiền viện Trúc Lâm', startTime: '09:30', endTime: '10:30', day: 3),
        TripPlaceUi(name: 'Thác Datanla', startTime: '11:00', endTime: '12:00', day: 3),
        TripPlaceUi(name: 'Đồi chè Cầu Đất', startTime: '07:30', endTime: '09:00', day: 4),
        TripPlaceUi(name: 'Vườn hoa thành phố', startTime: '10:00', endTime: '11:00', day: 4),
        TripPlaceUi(name: 'Nhà thờ Con Gà', startTime: '13:00', endTime: '14:00', day: 4),
        TripPlaceUi(name: 'Đồi Robin', startTime: '15:00', endTime: '16:00', day: 4),
      ],
    ),
    TripUi(
      id: 'trip-demo-4',
      title: 'Đà lạt ơi',
      days: 4,
      destination: 'Đà Lạt',
      coverAsset: 'assets/images/home_dalat.jpg',
      isActive: false,
      isGroup: true,
      members: [
        TripMemberUi(name: 'Thune'),
        TripMemberUi(name: 'ChiThanh'),
        TripMemberUi(name: 'Buji'),
        TripMemberUi(name: 'An'),
      ],
      places: [
        TripPlaceUi(name: 'Hồ Xuân Hương', startTime: '08:00', endTime: '09:00', day: 1),
        TripPlaceUi(name: 'Quảng trường Lâm Viên', startTime: '09:30', endTime: '10:30', day: 1),
        TripPlaceUi(name: 'Chợ Đà Lạt', startTime: '11:00', endTime: '12:00', day: 1),
        TripPlaceUi(name: 'Ga Đà Lạt', startTime: '13:30', endTime: '14:30', day: 2),
        TripPlaceUi(name: 'Dinh Bảo Đại', startTime: '15:00', endTime: '16:00', day: 2),
        TripPlaceUi(name: 'Hồ Tuyền Lâm', startTime: '08:00', endTime: '09:00', day: 3),
        TripPlaceUi(name: 'Thiền viện Trúc Lâm', startTime: '09:30', endTime: '10:30', day: 3),
        TripPlaceUi(name: 'Thác Datanla', startTime: '11:00', endTime: '12:00', day: 3),
        TripPlaceUi(name: 'Đồi chè Cầu Đất', startTime: '07:30', endTime: '09:00', day: 4),
        TripPlaceUi(name: 'Vườn hoa thành phố', startTime: '10:00', endTime: '11:00', day: 4),
        TripPlaceUi(name: 'Nhà thờ Con Gà', startTime: '13:00', endTime: '14:00', day: 4),
        TripPlaceUi(name: 'Đồi Robin', startTime: '15:00', endTime: '16:00', day: 4),
      ],
    ),
  ];

  bool get _isSearching => _searchController.text.trim().isNotEmpty;

  TripUi? get _pinnedTrip {
    for (final trip in _trips) {
      if (trip.isActive) return trip;
    }
    return null;
  }

  List<TripUi> get _visibleTrips {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return List<TripUi>.unmodifiable(_trips);
    }

    return _trips.where((trip) {
      return trip.title.toLowerCase().contains(query) ||
          trip.destination.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final ui = _TripMetrics.fromWidth(width);
    final visibleTrips = _visibleTrips;
    final pinnedTrip = _pinnedTrip;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(ui),
            SizedBox(height: ui.headerToSearchGap),
            _buildSearchField(ui),
            SizedBox(height: ui.searchToContentGap),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(bottom: ui.bottomPadding),
                children: [
                  if (!_isSearching && pinnedTrip != null) ...[
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ui.horizontalPadding,
                      ),
                      child: Text(
                        'Đang diễn ra',
                        style: TextStyle(
                          fontSize: ui.sectionTitleSize,
                          fontWeight: FontWeight.w700,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                    SizedBox(height: ui.sectionGap),
                    _PinnedTripCard(
                      trip: pinnedTrip,
                      ui: ui,
                      dateText: _dateText(pinnedTrip),
                      onTap: () => _openTrip(pinnedTrip),
                    ),
                    SizedBox(height: ui.pinnedToListGap),
                  ],
                  if (visibleTrips.isEmpty)
                    _buildEmptySearch(ui)
                  else
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ui.horizontalPadding,
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < visibleTrips.length; i++) ...[
                            _TripListCard(
                              trip: visibleTrips[i],
                              ui: ui,
                              dateText: _dateText(visibleTrips[i]),
                              onTap: () => _openTrip(visibleTrips[i]),
                              onMoreTap: () => _openTripActions(visibleTrips[i]),
                            ),
                            if (i != visibleTrips.length - 1)
                              SizedBox(height: ui.cardGap),
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

  Widget _buildHeader(_TripMetrics ui) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ui.horizontalPadding,
        ui.headerTopPadding,
        ui.horizontalPadding,
        0,
      ),
      child: SizedBox(
        height: ui.headerHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Text(
                'Lịch trình',
                style: TextStyle(
                  fontSize: ui.titleSize,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryText,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: _createTrip,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: ui.headerButtonSize,
                  height: ui.headerButtonSize,
                  child: Center(
                    child: Icon(
                      LucideIcons.calendar_plus,
                      size: ui.headerIconSize,
                      color: AppColors.black,
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

  Widget _buildSearchField(_TripMetrics ui) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ui.searchHorizontalPadding),
      child: Container(
        height: ui.searchHeight,
        decoration: BoxDecoration(
          color: AppColors.grayBackground,
          borderRadius: BorderRadius.circular(ui.searchRadius),
        ),
        padding: EdgeInsets.symmetric(horizontal: ui.searchInnerPadding),
        child: Row(
          children: [
            Icon(
              LucideIcons.search,
              size: ui.searchIconSize,
              color: AppColors.grayText,
            ),
            SizedBox(width: ui.searchIconGap),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                cursorColor: AppColors.primaryIcon,
                textInputAction: TextInputAction.search,
                style: TextStyle(
                  fontSize: ui.searchFontSize,
                  color: AppColors.black,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: 'Tìm....',
                  hintStyle: TextStyle(
                    fontSize: ui.searchFontSize,
                    color: AppColors.grayText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (_isSearching)
              InkWell(
                onTap: () {
                  _searchController.clear();
                  FocusScope.of(context).unfocus();
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ui.cancelHorizontalPadding,
                    vertical: 6,
                  ),
                  child: Text(
                    'Huỷ',
                    style: TextStyle(
                      fontSize: ui.cancelFontSize,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
              )
            else
              Text(
                'Huỷ',
                style: TextStyle(
                  fontSize: ui.cancelFontSize,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearch(_TripMetrics ui) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ui.horizontalPadding,
        ui.emptyTopPadding,
        ui.horizontalPadding,
        0,
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              LucideIcons.search_x,
              size: ui.emptyIconSize,
              color: AppColors.grayText,
            ),
            SizedBox(height: ui.emptyGap),
            Text(
              'Không tìm thấy lịch trình',
              style: TextStyle(
                fontSize: ui.emptyTextSize,
                fontWeight: FontWeight.w600,
                color: AppColors.grayText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateText(TripUi trip) {
    // TripUi hiện chưa có startDate / endDate.
    // Giữ backend nguyên trạng và chỉ dùng text demo cho dữ liệu mẫu.
    if (trip.id.startsWith('trip-demo-')) {
      return '12-15 tháng 10, 2026';
    }
    return 'Thời gian chưa cập nhật';
  }

  Future<void> _openTripActions(TripUi trip) async {
    final action = await GoMateBottomSheet.show<_TripAction>(
      context: context,
      size: GoMateBottomSheetSize.compact,
      showDragHandle: true,
      contentPadding: EdgeInsets.zero,
      child: _TripActionSheet(
        isPinned: trip.isActive,
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _TripAction.pin:
        _pinTrip(trip);
        break;
      case _TripAction.unpin:
        _unpinTrip(trip);
        break;
      case _TripAction.delete:
        await _confirmDelete(trip);
        break;
    }
  }

  void _pinTrip(TripUi trip) {
    setState(() {
      for (int i = 0; i < _trips.length; i++) {
        final current = _trips[i];
        _trips[i] = current.copyWith(
          isActive: current.id == trip.id,
        );
      }
    });

    GoMateSnackBar.show(
      context,
      message: 'Đã ghim lịch trình "${trip.title}"',
      bottomOffset: 92,
      icon: LucideIcons.circle_check,
    );
  }

  void _unpinTrip(TripUi trip) {
    final index = _trips.indexWhere((item) => item.id == trip.id);
    if (index < 0) return;

    setState(() {
      _trips[index] = _trips[index].copyWith(isActive: false);
    });

    GoMateSnackBar.show(
      context,
      message: 'Đã bỏ ghim lịch trình',
      bottomOffset: 92,
      icon: LucideIcons.circle_check,
    );
  }

  Future<void> _confirmDelete(TripUi trip) async {
    final shouldDelete = await GoMateBottomSheet.show<bool>(
      context: context,
      size: GoMateBottomSheetSize.compact,
      showDragHandle: true,
      child: _DeleteTripConfirm(
        tripTitle: trip.title,
      ),
    );

    if (!mounted || shouldDelete != true) return;

    final originalIndex = _trips.indexWhere((item) => item.id == trip.id);
    if (originalIndex < 0) return;

    final removedTrip = _trips[originalIndex];

    setState(() {
      _trips.removeAt(originalIndex);
    });

    GoMateSnackBar.showUndo(
      context,
      message: 'Đã xoá lịch trình',
      bottomOffset: 92,
      onUndo: () {
        if (!mounted) return;

        setState(() {
          final safeIndex = originalIndex.clamp(0, _trips.length);
          _trips.insert(safeIndex, removedTrip);
        });
      },
    );
  }

  Future<void> _createTrip() async {
    final result = await Navigator.of(context).push<TripUi>(
      MaterialPageRoute(
        builder: (_) => const CreateTripScreen(),
      ),
    );

    if (!mounted || result == null) return;

    // CreateTripScreen hiện đang trả isActive=true.
    // Ở màn danh sách, "ghim" phải là thao tác chủ động qua menu ba chấm,
    // nên lịch trình mới được thêm ở trạng thái chưa ghim.
    setState(() {
      _trips.insert(
        0,
        result.copyWith(isActive: false),
      );
    });
  }

  Future<void> _openTrip(TripUi trip) async {
    final updated = await Navigator.of(context).push<TripUi>(
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(
          trip: trip,
        ),
      ),
    );

    if (!mounted || updated == null) return;

    final index = _trips.indexWhere((item) => item.id == updated.id);
    if (index < 0) return;

    final wasPinned = _trips[index].isActive;

    setState(() {
      // Giữ trạng thái pin do TripScreen quản lý.
      _trips[index] = updated.copyWith(isActive: wasPinned);
    });
  }
}

enum _TripAction {
  pin,
  unpin,
  delete,
}

class _TripActionSheet extends StatelessWidget {
  final bool isPinned;

  const _TripActionSheet({
    required this.isPinned,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = (width * 0.075).clamp(24.0, 30.0).toDouble();
    final rowHeight = (width * 0.13).clamp(48.0, 56.0).toDouble();
    final iconSize = (width * 0.058).clamp(21.0, 24.0).toDouble();
    final fontSize = (width * 0.043).clamp(15.0, 17.0).toDouble();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        0,
        horizontal,
        (width * 0.06).clamp(20.0, 26.0).toDouble(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TripActionRow(
            height: rowHeight,
            icon: isPinned ? LucideIcons.pin_off : LucideIcons.pin,
            iconSize: iconSize,
            label: isPinned ? 'Bỏ ghim lịch trình' : 'Ghim lịch trình',
            fontSize: fontSize,
            color: AppColors.black,
            onTap: () => Navigator.of(context).pop(
              isPinned ? _TripAction.unpin : _TripAction.pin,
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.grayBorder.withOpacity(0.9),
          ),
          _TripActionRow(
            height: rowHeight,
            icon: LucideIcons.trash,
            iconSize: iconSize,
            label: 'Xoá lịch trình',
            fontSize: fontSize,
            color: AppColors.primaryText,
            onTap: () => Navigator.of(context).pop(_TripAction.delete),
          ),
        ],
      ),
    );
  }
}

class _TripActionRow extends StatelessWidget {
  final double height;
  final IconData icon;
  final double iconSize;
  final String label;
  final double fontSize;
  final Color color;
  final VoidCallback onTap;

  const _TripActionRow({
    required this.height,
    required this.icon,
    required this.iconSize,
    required this.label,
    required this.fontSize,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Icon(
              icon,
              size: iconSize,
              color: color,
            ),
            SizedBox(width: iconSize * 1.25),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteTripConfirm extends StatelessWidget {
  final String tripTitle;

  const _DeleteTripConfirm({
    required this.tripTitle,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = (width * 0.045).clamp(16.0, 18.0).toDouble();
    final bodySize = (width * 0.035).clamp(12.5, 14.0).toDouble();
    final buttonHeight = (width * 0.12).clamp(44.0, 50.0).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Xoá lịch trình?',
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryText,
          ),
        ),
        SizedBox(height: width * 0.025),
        Text(
          'Bạn có chắc muốn xoá "$tripTitle" không?',
          style: TextStyle(
            fontSize: bodySize,
            height: 1.35,
            color: AppColors.grayText,
          ),
        ),
        SizedBox(height: width * 0.055),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: buttonHeight,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.grayBorder),
                    foregroundColor: AppColors.primaryText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(buttonHeight / 2),
                    ),
                  ),
                  child: const Text(
                    'Huỷ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            SizedBox(width: width * 0.03),
            Expanded(
              child: SizedBox(
                height: buttonHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(buttonHeight / 2),
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(buttonHeight / 2),
                      ),
                    ),
                    child: const Text(
                      'Xoá',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TripListCard extends StatelessWidget {
  final TripUi trip;
  final _TripMetrics ui;
  final String dateText;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const _TripListCard({
    required this.trip,
    required this.ui,
    required this.dateText,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minHeight: ui.cardHeight,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(ui.cardRadius),
        boxShadow: ui.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ui.cardRadius),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(ui.cardRadius),
                ),
                child: _TripImage(
                  asset: trip.coverAsset,
                  width: ui.cardImageWidth,
                  height: ui.cardHeight,
                ),
              ),
              SizedBox(width: ui.cardContentGap),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: ui.cardVerticalPadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui.cardTitleSize,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryText,
                        ),
                      ),
                      SizedBox(height: ui.cardLineGap),
                      Text(
                        dateText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui.cardMetaSize,
                          height: 1.1,
                          color: AppColors.grayText,
                        ),
                      ),
                      SizedBox(height: ui.cardSmallGap),
                      Text(
                        '${_memberCount(trip)} thành viên',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui.cardMetaSize,
                          height: 1.1,
                          color: AppColors.grayText,
                        ),
                      ),
                      SizedBox(height: ui.cardSmallGap),
                      Text(
                        '${trip.days} ngày - ${trip.places.length} địa điểm',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: ui.cardMetaSize,
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
                  width: ui.moreButtonWidth,
                  child: Center(
                    child: Icon(
                      LucideIcons.ellipsis_vertical,
                      size: ui.moreIconSize,
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

  static int _memberCount(TripUi trip) {
    if (trip.members.isNotEmpty) return trip.members.length;
    return trip.isGroup ? 1 : 1;
  }
}


List<String> _pinnedTripPlaceImages(TripUi trip) {
  // TODO(integration): khi backend Place/Trip trả media cho từng địa điểm,
  // thay danh sách demo này bằng ảnh thật theo trip.places.
  //
  // Hiện tại TripPlaceUi chỉ có name/startTime/endTime/day nên chưa có
  // trường ảnh. Các asset dưới đây chỉ phục vụ UI slideshow.
  // Dùng các ảnh THẬT đang có sẵn trong assets/images/ để
  // nhìn thấy slideshow ngay khi chạy project.
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

  final count = trip.places.length.clamp(1, demoPlaceImages.length);
  return demoPlaceImages.take(count).toList(growable: false);
}

class _PinnedTripCard extends StatefulWidget {
  final TripUi trip;
  final _TripMetrics ui;
  final String dateText;
  final VoidCallback onTap;

  const _PinnedTripCard({
    required this.trip,
    required this.ui,
    required this.dateText,
    required this.onTap,
  });

  @override
  State<_PinnedTripCard> createState() => _PinnedTripCardState();
}

class _PinnedTripCardState extends State<_PinnedTripCard> {
  Timer? _timer;
  int _imageIndex = 0;

  List<String> get _images => _pinnedTripPlaceImages(widget.trip);

  @override
  void initState() {
    super.initState();
    _startSlideShow();
  }

  @override
  void didUpdateWidget(covariant _PinnedTripCard oldWidget) {
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

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;

      setState(() {
        _imageIndex = (_imageIndex + 1) % _images.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final ui = widget.ui;
    final images = _images;
    final image = images[_imageIndex.clamp(0, images.length - 1)];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        child: SizedBox(
          width: double.infinity,
          height: ui.pinnedHeight,
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
                    height: ui.pinnedHeight,
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
                  ui.pinnedHorizontalPadding,
                  ui.pinnedTopPadding,
                  ui.pinnedHorizontalPadding,
                  ui.pinnedBottomPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Text(
                      trip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: ui.pinnedTitleSize,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: ui.pinnedLineGap),
                    _PinnedMetaRow(
                      icon: LucideIcons.calendar_days,
                      text: widget.dateText,
                      ui: ui,
                    ),
                    SizedBox(height: ui.pinnedMetaGap),
                    _PinnedMetaRow(
                      icon: LucideIcons.users_round,
                      text:
                      '${trip.members.isEmpty ? 1 : trip.members.length} thành viên',
                      ui: ui,
                    ),
                    SizedBox(height: ui.pinnedMetaGap),
                    Text(
                      '${trip.days} ngày - ${trip.places.length} địa điểm',
                      style: TextStyle(
                        fontSize: ui.pinnedMetaSize,
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
                  right: ui.pinnedHorizontalPadding,
                  bottom: ui.pinnedBottomPadding,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(images.length, (index) {
                      final active = index == _imageIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.only(left: 4),
                        width: active ? 12 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      );
                    }),
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
  final _TripMetrics ui;

  const _PinnedMetaRow({
    required this.icon,
    required this.text,
    required this.ui,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: ui.pinnedIconSize,
          color: Colors.white,
        ),
        SizedBox(width: ui.pinnedIconGap),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ui.pinnedMetaSize,
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
        // Giữ fallback hiện tại nếu asset không tồn tại.
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

class _TripMetrics {
  final double width;
  final double horizontalPadding;
  final double searchHorizontalPadding;
  final double headerTopPadding;
  final double headerHeight;
  final double headerButtonSize;
  final double headerIconSize;
  final double titleSize;
  final double headerToSearchGap;
  final double searchHeight;
  final double searchRadius;
  final double searchInnerPadding;
  final double searchIconSize;
  final double searchIconGap;
  final double searchFontSize;
  final double cancelFontSize;
  final double cancelHorizontalPadding;
  final double searchToContentGap;
  final double sectionTitleSize;
  final double sectionGap;
  final double pinnedHeight;
  final double pinnedHorizontalPadding;
  final double pinnedTopPadding;
  final double pinnedBottomPadding;
  final double pinnedTitleSize;
  final double pinnedMetaSize;
  final double pinnedIconSize;
  final double pinnedIconGap;
  final double pinnedLineGap;
  final double pinnedMetaGap;
  final double pinnedToListGap;
  final double cardHeight;
  final double cardImageWidth;
  final double cardRadius;
  final double cardContentGap;
  final double cardVerticalPadding;
  final double cardTitleSize;
  final double cardMetaSize;
  final double cardLineGap;
  final double cardSmallGap;
  final double cardGap;
  final double moreButtonWidth;
  final double moreIconSize;
  final double bottomPadding;
  final double emptyTopPadding;
  final double emptyIconSize;
  final double emptyGap;
  final double emptyTextSize;
  final List<BoxShadow> cardShadow;

  const _TripMetrics({
    required this.width,
    required this.horizontalPadding,
    required this.searchHorizontalPadding,
    required this.headerTopPadding,
    required this.headerHeight,
    required this.headerButtonSize,
    required this.headerIconSize,
    required this.titleSize,
    required this.headerToSearchGap,
    required this.searchHeight,
    required this.searchRadius,
    required this.searchInnerPadding,
    required this.searchIconSize,
    required this.searchIconGap,
    required this.searchFontSize,
    required this.cancelFontSize,
    required this.cancelHorizontalPadding,
    required this.searchToContentGap,
    required this.sectionTitleSize,
    required this.sectionGap,
    required this.pinnedHeight,
    required this.pinnedHorizontalPadding,
    required this.pinnedTopPadding,
    required this.pinnedBottomPadding,
    required this.pinnedTitleSize,
    required this.pinnedMetaSize,
    required this.pinnedIconSize,
    required this.pinnedIconGap,
    required this.pinnedLineGap,
    required this.pinnedMetaGap,
    required this.pinnedToListGap,
    required this.cardHeight,
    required this.cardImageWidth,
    required this.cardRadius,
    required this.cardContentGap,
    required this.cardVerticalPadding,
    required this.cardTitleSize,
    required this.cardMetaSize,
    required this.cardLineGap,
    required this.cardSmallGap,
    required this.cardGap,
    required this.moreButtonWidth,
    required this.moreIconSize,
    required this.bottomPadding,
    required this.emptyTopPadding,
    required this.emptyIconSize,
    required this.emptyGap,
    required this.emptyTextSize,
    required this.cardShadow,
  });

  factory _TripMetrics.fromWidth(double width) {
    double c(double value, double min, double max) {
      return value.clamp(min, max).toDouble();
    }

    final horizontalPadding = c(width * 0.065, 22, 28);
    // Card có 4 dòng nội dung nên không được ép quá thấp.
    // Ở màn 360-390dp, khoảng 86-92dp giữ đúng tỷ lệ mockup
    // và tránh RenderFlex overflow (sọc vàng-đen).
    final cardHeight = c(width * 0.225, 84, 94);
    final cardRadius = c(width * 0.038, 13, 16);

    return _TripMetrics(
      width: width,
      horizontalPadding: horizontalPadding,
      searchHorizontalPadding: c(width * 0.075, 24, 30),
      headerTopPadding: c(width * 0.020, 6, 9),
      headerHeight: c(width * 0.115, 42, 48),
      headerButtonSize: c(width * 0.105, 38, 44),
      headerIconSize: c(width * 0.060, 21, 24),
      titleSize: c(width * 0.053, 19, 22),
      headerToSearchGap: c(width * 0.030, 10, 13),
      searchHeight: c(width * 0.095, 36, 42),
      searchRadius: c(width * 0.050, 18, 22),
      searchInnerPadding: c(width * 0.035, 12, 15),
      searchIconSize: c(width * 0.047, 17, 20),
      searchIconGap: c(width * 0.018, 6, 8),
      searchFontSize: c(width * 0.033, 12, 13.5),
      cancelFontSize: c(width * 0.032, 11.5, 13),
      cancelHorizontalPadding: c(width * 0.012, 4, 6),
      searchToContentGap: c(width * 0.050, 17, 21),
      sectionTitleSize: c(width * 0.032, 11.5, 13),
      sectionGap: c(width * 0.030, 10, 13),
      pinnedHeight: c(width * 0.34, 122, 140),
      pinnedHorizontalPadding: c(width * 0.052, 18, 22),
      pinnedTopPadding: c(width * 0.040, 14, 17),
      pinnedBottomPadding: c(width * 0.050, 17, 21),
      pinnedTitleSize: c(width * 0.044, 16, 18),
      pinnedMetaSize: c(width * 0.027, 10, 11.5),
      pinnedIconSize: c(width * 0.037, 13, 15),
      pinnedIconGap: c(width * 0.014, 5, 6),
      pinnedLineGap: c(width * 0.022, 7, 9),
      pinnedMetaGap: c(width * 0.016, 5, 7),
      pinnedToListGap: c(width * 0.060, 20, 25),
      cardHeight: cardHeight,
      cardImageWidth: c(width * 0.21, 78, 88),
      cardRadius: cardRadius,
      cardContentGap: c(width * 0.030, 10, 13),
      cardVerticalPadding: c(width * 0.020, 7, 9),
      cardTitleSize: c(width * 0.032, 11.5, 13),
      cardMetaSize: c(width * 0.025, 9, 10.5),
      cardLineGap: c(width * 0.010, 3, 4),
      cardSmallGap: c(width * 0.006, 2, 3),
      cardGap: c(width * 0.050, 17, 21),
      moreButtonWidth: c(width * 0.13, 44, 52),
      moreIconSize: c(width * 0.050, 18, 21),
      bottomPadding: c(width * 0.31, 108, 128),
      emptyTopPadding: c(width * 0.16, 56, 68),
      emptyIconSize: c(width * 0.09, 30, 36),
      emptyGap: c(width * 0.030, 10, 13),
      emptyTextSize: c(width * 0.035, 12.5, 14),
      cardShadow: const [
        BoxShadow(
          color: Color(0x16000000),
          blurRadius: 9,
          offset: Offset(0, 3),
        ),
      ],
    );
  }
}
