import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/app_colors.dart';

class GoMateItineraryPickerItem {
  final String id;
  final String title;
  final String dateRange;
  final String summary;
  final String imageAsset;
  final int memberCount;

  const GoMateItineraryPickerItem({
    required this.id,
    required this.title,
    required this.dateRange,
    required this.summary,
    required this.imageAsset,
    this.memberCount = 0,
  });
}

/// Picker lịch trình dùng chung cho:
/// - Tin nhắn -> Thêm vào lịch trình
/// - Chi tiết địa điểm -> Thêm vào lịch trình
///
/// Chỉ xử lý UI + tìm kiếm.
/// Business action sau khi chọn được truyền qua [onSelected].
class GoMateItineraryPickerScreen extends StatefulWidget {
  final List<GoMateItineraryPickerItem> items;
  final FutureOr<void> Function(GoMateItineraryPickerItem item) onSelected;

  const GoMateItineraryPickerScreen({
    super.key,
    required this.items,
    required this.onSelected,
  });

  @override
  State<GoMateItineraryPickerScreen> createState() =>
      _GoMateItineraryPickerScreenState();
}

class _GoMateItineraryPickerScreenState
    extends State<GoMateItineraryPickerScreen> {
  final TextEditingController _controller = TextEditingController();

  late List<GoMateItineraryPickerItem> _visible;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _visible = widget.items;
  }

  @override
  void didUpdateWidget(covariant GoMateItineraryPickerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.items, widget.items)) {
      _applySearch(_query);
    }
  }

  void _applySearch(String value) {
    final q = value.trim().toLowerCase();

    setState(() {
      _query = value;
      _visible = q.isEmpty
          ? widget.items
          : widget.items
              .where(
                (item) =>
                    item.title.toLowerCase().contains(q) ||
                    item.dateRange.toLowerCase().contains(q) ||
                    item.summary.toLowerCase().contains(q),
              )
              .toList(growable: false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final metrics = _PickerMetrics.fromWidth(width);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.outerHorizontal,
            metrics.outerTop,
            metrics.outerHorizontal,
            0,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(metrics.pageRadius),
            ),
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                children: [
                  SizedBox(height: metrics.searchTopGap),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: metrics.searchHorizontal,
                    ),
                    child: _PickerSearchField(
                      controller: _controller,
                      metrics: metrics,
                      onChanged: _applySearch,
                    ),
                  ),
                  SizedBox(height: metrics.searchToContentGap),
                  Expanded(
                    child: _buildContent(metrics),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(_PickerMetrics metrics) {
    if (widget.items.isEmpty) {
      return _EmptyItineraryState(
        metrics: metrics,
        text: 'Chưa có lịch trình',
        showCalendarIcon: true,
      );
    }

    if (_visible.isEmpty) {
      return _EmptyItineraryState(
        metrics: metrics,
        text: 'Không tìm thấy lịch trình',
        showCalendarIcon: false,
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        metrics.listHorizontal,
        metrics.listTopPadding,
        metrics.listHorizontal,
        metrics.listBottomPadding,
      ),
      itemCount: _visible.length,
      separatorBuilder: (_, __) => SizedBox(height: metrics.rowGap),
      itemBuilder: (context, index) {
        final item = _visible[index];

        return _ItineraryPickerRow(
          item: item,
          metrics: metrics,
          onTap: () => widget.onSelected(item),
        );
      },
    );
  }
}

class _PickerSearchField extends StatelessWidget {
  final TextEditingController controller;
  final _PickerMetrics metrics;
  final ValueChanged<String> onChanged;

  const _PickerSearchField({
    required this.controller,
    required this.metrics,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: metrics.searchHeight,
      padding: EdgeInsets.symmetric(
        horizontal: metrics.searchInnerHorizontal,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(metrics.searchRadius),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.search,
            size: metrics.searchIconSize,
            color: const Color(0xFF858585),
          ),
          SizedBox(width: metrics.searchIconGap),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: AppColors.primaryIcon,
              style: TextStyle(
                fontSize: metrics.searchFontSize,
                fontWeight: FontWeight.w400,
                color: AppColors.black,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Tìm lịch trình ....',
                hintStyle: TextStyle(
                  fontSize: metrics.searchFontSize,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF8B8B8B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItineraryPickerRow extends StatelessWidget {
  final GoMateItineraryPickerItem item;
  final _PickerMetrics metrics;
  final VoidCallback onTap;

  const _ItineraryPickerRow({
    required this.item,
    required this.metrics,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageAsset = item.imageAsset.trim().isEmpty
        ? 'assets/images/survey_city.jpg'
        : item.imageAsset;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(metrics.rowRadius),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: metrics.rowHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: metrics.rowHorizontalPadding,
              vertical: metrics.rowVerticalPadding,
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(metrics.imageRadius),
                  child: Image.asset(
                    imageAsset,
                    width: metrics.imageSize,
                    height: metrics.imageSize,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: metrics.imageSize,
                      height: metrics.imageSize,
                      color: AppColors.blue50,
                      alignment: Alignment.center,
                      child: Icon(
                        LucideIcons.image,
                        size: metrics.imageFallbackIconSize,
                        color: AppColors.primaryIcon,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: metrics.imageToTitleGap),
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: metrics.titleFontSize,
                      height: 1.1,
                      fontWeight: FontWeight.w500,
                      color: AppColors.black,
                    ),
                  ),
                ),
                if (item.memberCount > 0) ...[
                  SizedBox(width: metrics.memberGap),
                  Text(
                    '${item.memberCount} thành viên',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: metrics.memberFontSize,
                      height: 1.1,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF969696),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyItineraryState extends StatelessWidget {
  final _PickerMetrics metrics;
  final String text;
  final bool showCalendarIcon;

  const _EmptyItineraryState({
    required this.metrics,
    required this.text,
    required this.showCalendarIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: Offset(0, -metrics.emptyLift),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: metrics.emptyTextSize,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF8A8A8A),
              ),
            ),
            SizedBox(height: metrics.emptyTextToIconGap),
            if (showCalendarIcon)
              SizedBox(
                width: metrics.emptyIconBox,
                height: metrics.emptyIconBox,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Icon(
                        LucideIcons.calendar,
                        size: metrics.emptyCalendarSize,
                        color: AppColors.primaryIcon,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: metrics.emptyPlusBadge,
                        height: metrics.emptyPlusBadge,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryIcon,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          LucideIcons.plus,
                          size: metrics.emptyPlusIcon,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Icon(
                LucideIcons.search,
                size: metrics.emptyCalendarSize,
                color: AppColors.grayText,
              ),
          ],
        ),
      ),
    );
  }
}

class _PickerMetrics {
  final double width;

  final double outerHorizontal;
  final double outerTop;
  final double pageRadius;

  final double searchTopGap;
  final double searchHorizontal;
  final double searchHeight;
  final double searchRadius;
  final double searchInnerHorizontal;
  final double searchIconSize;
  final double searchIconGap;
  final double searchFontSize;
  final double searchToContentGap;

  final double listHorizontal;
  final double listTopPadding;
  final double listBottomPadding;
  final double rowHeight;
  final double rowGap;
  final double rowRadius;
  final double rowHorizontalPadding;
  final double rowVerticalPadding;

  final double imageSize;
  final double imageRadius;
  final double imageFallbackIconSize;
  final double imageToTitleGap;

  final double titleFontSize;
  final double memberFontSize;
  final double memberGap;

  final double emptyLift;
  final double emptyTextSize;
  final double emptyTextToIconGap;
  final double emptyIconBox;
  final double emptyCalendarSize;
  final double emptyPlusBadge;
  final double emptyPlusIcon;

  const _PickerMetrics({
    required this.width,
    required this.outerHorizontal,
    required this.outerTop,
    required this.pageRadius,
    required this.searchTopGap,
    required this.searchHorizontal,
    required this.searchHeight,
    required this.searchRadius,
    required this.searchInnerHorizontal,
    required this.searchIconSize,
    required this.searchIconGap,
    required this.searchFontSize,
    required this.searchToContentGap,
    required this.listHorizontal,
    required this.listTopPadding,
    required this.listBottomPadding,
    required this.rowHeight,
    required this.rowGap,
    required this.rowRadius,
    required this.rowHorizontalPadding,
    required this.rowVerticalPadding,
    required this.imageSize,
    required this.imageRadius,
    required this.imageFallbackIconSize,
    required this.imageToTitleGap,
    required this.titleFontSize,
    required this.memberFontSize,
    required this.memberGap,
    required this.emptyLift,
    required this.emptyTextSize,
    required this.emptyTextToIconGap,
    required this.emptyIconBox,
    required this.emptyCalendarSize,
    required this.emptyPlusBadge,
    required this.emptyPlusIcon,
  });

  factory _PickerMetrics.fromWidth(double width) {
    double c(double value, double min, double max) =>
        value.clamp(min, max).toDouble();

    return _PickerMetrics(
      width: width,
      outerHorizontal: c(width * 0.022, 7, 10),
      outerTop: c(width * 0.020, 6, 9),
      pageRadius: c(width * 0.080, 24, 30),

      searchTopGap: c(width * 0.070, 22, 29),
      searchHorizontal: c(width * 0.072, 23, 30),
      searchHeight: c(width * 0.105, 38, 44),
      searchRadius: c(width * 0.060, 20, 24),
      searchInnerHorizontal: c(width * 0.040, 13, 17),
      searchIconSize: c(width * 0.060, 21, 25),
      searchIconGap: c(width * 0.020, 7, 9),
      searchFontSize: c(width * 0.038, 13.5, 16),
      searchToContentGap: c(width * 0.080, 25, 32),

      listHorizontal: c(width * 0.075, 24, 31),
      listTopPadding: c(width * 0.012, 4, 6),
      listBottomPadding: c(width * 0.080, 26, 34),
      rowHeight: c(width * 0.155, 56, 64),
      rowGap: c(width * 0.025, 8, 11),
      rowRadius: c(width * 0.030, 10, 12),
      rowHorizontalPadding: c(width * 0.020, 6, 9),
      rowVerticalPadding: c(width * 0.014, 5, 7),

      imageSize: c(width * 0.125, 44, 52),
      imageRadius: c(width * 0.020, 7, 9),
      imageFallbackIconSize: c(width * 0.050, 18, 21),
      imageToTitleGap: c(width * 0.050, 17, 21),

      titleFontSize: c(width * 0.038, 13.5, 16),
      memberFontSize: c(width * 0.034, 12, 14.5),
      memberGap: c(width * 0.030, 10, 13),

      emptyLift: c(width * 0.19, 66, 78),
      emptyTextSize: c(width * 0.034, 12, 14),
      emptyTextToIconGap: c(width * 0.030, 10, 13),
      emptyIconBox: c(width * 0.085, 30, 35),
      emptyCalendarSize: c(width * 0.067, 24, 28),
      emptyPlusBadge: c(width * 0.044, 16, 18),
      emptyPlusIcon: c(width * 0.030, 10, 12),
    );
  }
}
