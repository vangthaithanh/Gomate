import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../trip/models/trip_ui_models.dart';

class GoMateMapTripHeader extends StatefulWidget {
  final TripUi trip;
  final int selectedDay;
  final int placeCount;
  final bool expanded;

  final VoidCallback onToggleExpanded;
  final VoidCallback? onEdit;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final ValueChanged<int> onDaySwipe;

  const GoMateMapTripHeader({
    super.key,
    required this.trip,
    required this.selectedDay,
    required this.placeCount,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onDaySwipe,
    this.onEdit,
  });

  @override
  State<GoMateMapTripHeader> createState() =>
      _GoMateMapTripHeaderState();
}

class _GoMateMapTripHeaderState extends State<GoMateMapTripHeader> {
  late PageController _dayController;

  int get _safeDay =>
      widget.selectedDay.clamp(1, widget.trip.days).toInt();

  @override
  void initState() {
    super.initState();
    _dayController = PageController(
      initialPage: _safeDay - 1,
    );
  }

  @override
  void didUpdateWidget(covariant GoMateMapTripHeader oldWidget) {
    super.didUpdateWidget(oldWidget);

    final dayChanged = oldWidget.selectedDay != widget.selectedDay;
    final tripChanged = oldWidget.trip.id != widget.trip.id ||
        oldWidget.trip.days != widget.trip.days;

    if (!dayChanged && !tripChanged) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_dayController.hasClients) return;

      final target = _safeDay - 1;
      final current = _dayController.page?.round();

      if (current == target) return;

      _dayController.animateToPage(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _dayController.dispose();
    super.dispose();
  }

  DateTime? _dateForDay(int day) {
    final start = widget.trip.startDate;
    if (start == null) return null;
    return start.add(Duration(days: day - 1));
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return '--/--';
    return '${value.day}/${value.month}';
  }

  String _weekdayLabel(DateTime? value) {
    if (value == null) return '';

    const labels = <String>[
      '',
      'Thứ 2',
      'Thứ 3',
      'Thứ 4',
      'Thứ 5',
      'Thứ 6',
      'Thứ 7',
      'C.Nhật',
    ];

    return labels[value.weekday];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (!widget.expanded) {
      return _CompactTripHeader(
        trip: widget.trip,
        onTap: widget.onToggleExpanded,
      );
    }

    final panelWidth =
        (width * 0.85).clamp(292.0, 360.0).toDouble();
    final headerHeight =
        (width * 0.215).clamp(78.0, 88.0).toDouble();
    final topBarHeight =
        (width * 0.080).clamp(28.0, 33.0).toDouble();

    return Container(
      width: panelWidth,
      height: headerHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: const Color(0xFF0B3E8A).withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: topBarHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0x4DDADADA),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: (width * 0.018)
                            .clamp(6.0, 8.0)
                            .toDouble(),
                        // chừa slot riêng cho chevron để nó nằm sát mép phải
                        right: (topBarHeight * 0.95)
                            .clamp(27.0, 31.0)
                            .toDouble(),
                      ),
                      child: Row(
                        children: [
                          _TripCover(
                            asset: widget.trip.coverAsset,
                            size: topBarHeight,
                          ),
                          SizedBox(
                            width: (width * 0.018)
                                .clamp(6.0, 8.0)
                                .toDouble(),
                          ),
                          Flexible(
                            child: Text(
                              widget.trip.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: (width * 0.037)
                                    .clamp(13.0, 14.5)
                                    .toDouble(),
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          if (widget.onEdit != null) ...[
                            SizedBox(width: width * 0.015),
                            InkWell(
                              onTap: widget.onEdit,
                              customBorder: const CircleBorder(),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Icon(
                                  LucideIcons.pencil,
                                  size: (width * 0.040)
                                      .clamp(14.0, 16.0)
                                      .toDouble(),
                                  color: AppColors.grayText,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // V20: nút thu gọn có slot riêng, bám sát mép phải panel.
                Positioned(
                  top: 0,
                  right: 1,
                  bottom: 0,
                  child: InkWell(
                    onTap: widget.onToggleExpanded,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: (topBarHeight * 0.92)
                          .clamp(26.0, 30.0)
                          .toDouble(),
                      child: Center(
                        child: Icon(
                          LucideIcons.chevron_up,
                          size: (width * 0.043)
                              .clamp(15.0, 18.0)
                              .toDouble(),
                          color: AppColors.grayText,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // V20: dùng PageView thật thay cho gesture threshold.
          // Người dùng có thể vuốt trái/phải tự nhiên hoặc bấm arrow.
          Expanded(
            child: PageView.builder(
              controller: _dayController,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.trip.days,
              onPageChanged: (index) {
                final nextDay = index + 1;
                final delta = nextDay - widget.selectedDay;
                if (delta != 0) {
                  widget.onDaySwipe(delta);
                }
              },
              itemBuilder: (context, index) {
                final day = index + 1;
                final date = _dateForDay(day);

                // Trong lúc kéo sang trang kế bên, count sẽ được parent cập nhật
                // ngay khi onPageChanged hoàn tất.
                final count = day == widget.selectedDay
                    ? widget.placeCount
                    : widget.placeCount;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: (width * 0.010)
                        .clamp(3.5, 4.5)
                        .toDouble(),
                  ),
                  child: Row(
                    children: [
                      _ChevronButton(
                        icon: LucideIcons.chevron_left,
                        onTap: widget.onPreviousDay,
                      ),
                      SizedBox(width: width * 0.004),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              'Ngày $day',
                              style: TextStyle(
                                fontSize: (width * 0.034)
                                    .clamp(12.0, 13.5)
                                    .toDouble(),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: width * 0.022),
                            Text(
                              '$count địa điểm',
                              style: TextStyle(
                                fontSize: (width * 0.025)
                                    .clamp(9.0, 10.5)
                                    .toDouble(),
                                fontWeight: FontWeight.w600,
                                color: AppColors.grayText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: (width * 0.025)
                              .clamp(9.0, 11.0)
                              .toDouble(),
                          vertical: (width * 0.010)
                              .clamp(3.0, 4.5)
                              .toDouble(),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x4DDADADA),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _dateLabel(date),
                              style: TextStyle(
                                fontSize: (width * 0.034)
                                    .clamp(12.0, 13.5)
                                    .toDouble(),
                                height: 1,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryText,
                              ),
                            ),
                            SizedBox(height: width * 0.008),
                            Text(
                              _weekdayLabel(date),
                              style: TextStyle(
                                fontSize: (width * 0.024)
                                    .clamp(8.5, 10.0)
                                    .toDouble(),
                                height: 1,
                                fontWeight: FontWeight.w600,
                                color: AppColors.grayText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: width * 0.004),
                      _ChevronButton(
                        icon: LucideIcons.chevron_right,
                        onTap: widget.onNextDay,
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
  }
}

class _CompactTripHeader extends StatelessWidget {
  final TripUi trip;
  final VoidCallback onTap;

  const _CompactTripHeader({
    required this.trip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.086).clamp(31.0, 36.0).toDouble();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: (width * 0.54).clamp(176.0, 226.0).toDouble(),
          ),
          height: height,
          padding: EdgeInsets.only(
            right: (width * 0.022).clamp(8.0, 10.0).toDouble(),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: const Color(0xFFE2EAF5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 9,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: AppColors.primaryIcon.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TripCover(asset: trip.coverAsset, size: height),
              SizedBox(width: width * 0.015),
              Flexible(
                child: Text(
                  trip.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize:
                        (width * 0.034).clamp(12.0, 14.0).toDouble(),
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(width: width * 0.012),
              Icon(
                LucideIcons.chevron_down,
                size: (width * 0.038).clamp(14.0, 16.0).toDouble(),
                color: AppColors.grayText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripCover extends StatelessWidget {
  final String asset;
  final double size;

  const _TripCover({
    required this.asset,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => ColoredBox(
          color: AppColors.blue50,
          child: SizedBox.square(
            dimension: size,
            child: const Icon(
              LucideIcons.image,
              color: AppColors.primaryIcon,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ChevronButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox.square(
        dimension: (width * 0.060).clamp(22.0, 26.0).toDouble(),
        child: Center(
          child: Icon(
            icon,
            size: (width * 0.042).clamp(15.0, 17.5).toDouble(),
            color: AppColors.grayText,
          ),
        ),
      ),
    );
  }
}
