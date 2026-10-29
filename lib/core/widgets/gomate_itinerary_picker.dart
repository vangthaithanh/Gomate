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
/// - Tin nhắn -> Thêm vào lịch trình.
/// - Chi tiết địa điểm -> Thêm vào lịch trình.
///
/// Luồng search đã chốt:
///
/// 1. Mở picker:
///    <   [ Tìm kiếm lịch trình... ]
///
/// 2. Chạm vào ô nhưng CHƯA nhập:
///    <   [ Tìm kiếm lịch trình... ]
///    => chưa hiện "Huỷ".
///
/// 3. Khi đã nhập từ khoá:
///        [ từ khoá ...        Huỷ ]
///    => nút Back tạm ẩn để search bar có đủ không gian.
///
/// 4. Bấm "Huỷ":
///    - clear keyword;
///    - unfocus / đóng keyboard;
///    - KHÔNG pop route;
///    - quay lại đúng trạng thái số 1.
///
/// 5. Chỉ nút Back mới đóng picker.
///
/// [onCancel] được giữ tên để tương thích code hiện tại, nhưng chỉ dùng cho
/// hành động đóng picker bằng nút Back. Nó KHÔNG được gọi bởi nút "Huỷ" search.
class GoMateItineraryPickerScreen extends StatefulWidget {
  final List<GoMateItineraryPickerItem> items;
  final FutureOr<void> Function(GoMateItineraryPickerItem item) onSelected;

  /// Cho phép search bar hiện chữ "Huỷ" khi đã có keyword.
  final bool showCancel;

  /// Placeholder.
  final String searchHint;

  /// Callback đóng picker bằng nút Back.
  /// Nếu null sẽ dùng Navigator.maybePop().
  final VoidCallback? onCancel;

  /// Empty-state quick create.
  final VoidCallback? onQuickCreate;

  const GoMateItineraryPickerScreen({
    super.key,
    required this.items,
    required this.onSelected,
    this.showCancel = true,
    this.searchHint = 'Tìm kiếm lịch trình...',
    this.onCancel,
    this.onQuickCreate,
  });

  @override
  State<GoMateItineraryPickerScreen> createState() =>
      _GoMateItineraryPickerScreenState();
}

class _GoMateItineraryPickerScreenState
    extends State<GoMateItineraryPickerScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late List<GoMateItineraryPickerItem> _visible;
  String _query = '';

  bool get _hasKeyword =>
      widget.showCancel && _query.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _visible = List<GoMateItineraryPickerItem>.of(widget.items);
  }

  @override
  void didUpdateWidget(
      covariant GoMateItineraryPickerScreen oldWidget,
      ) {
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
          ? List<GoMateItineraryPickerItem>.of(widget.items)
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

  /// "Huỷ" trong search KHÔNG đóng picker.
  ///
  /// Nó chỉ quay từ:
  ///
  /// [ keyword ... Huỷ ]
  ///
  /// về:
  ///
  /// < [ Tìm kiếm lịch trình... ]
  void _cancelCurrentSearch() {
    _controller.clear();
    _applySearch('');
    _focusNode.unfocus();
  }

  /// Chỉ nút Back mới thoát picker.
  void _closePicker() {
    final callback = widget.onCancel;

    if (callback != null) {
      callback();
      return;
    }

    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final ui = _PickerMetrics.fromWidth(width);

    return Scaffold(
      // Full-bleed, không tạo artboard trắng nằm trên nền xám.
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: ui.headerTopGap),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ui.headerHorizontal,
              ),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SizeTransition(
                          sizeFactor: animation,
                          axis: Axis.horizontal,
                          axisAlignment: -1,
                          child: child,
                        ),
                      );
                    },
                    child: _hasKeyword
                        ? const SizedBox.shrink(
                      key: ValueKey('picker-no-back'),
                    )
                        : Padding(
                      key: const ValueKey('picker-back'),
                      padding: EdgeInsets.only(
                        right: ui.backToSearchGap,
                      ),
                      child: InkWell(
                        onTap: _closePicker,
                        customBorder: const CircleBorder(),
                        child: SizedBox.square(
                          dimension: ui.backButtonSize,
                          child: Center(
                            child: Icon(
                              LucideIcons.chevron_left,
                              size: ui.backIconSize,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: _PickerSearchField(
                      controller: _controller,
                      focusNode: _focusNode,
                      metrics: ui,
                      hintText: widget.searchHint,
                      showCancel: _hasKeyword,
                      onChanged: _applySearch,
                      onCancel: _cancelCurrentSearch,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: ui.headerToContentGap),

            Expanded(
              child: _buildContent(ui),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(_PickerMetrics ui) {
    if (widget.items.isEmpty) {
      return _EmptyItineraryState(
        metrics: ui,
        text: 'Chưa có lịch trình',
        showCalendarIcon: true,
        onTap: widget.onQuickCreate,
      );
    }

    if (_visible.isEmpty) {
      return _EmptyItineraryState(
        metrics: ui,
        text: 'Không tìm thấy lịch trình',
        showCalendarIcon: false,
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior:
      ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        ui.listHorizontal,
        0,
        ui.listHorizontal,
        ui.listBottomPadding,
      ),
      itemCount: _visible.length,
      separatorBuilder: (_, __) =>
          SizedBox(height: ui.rowGap),
      itemBuilder: (context, index) {
        final item = _visible[index];

        return _ItineraryPickerRow(
          item: item,
          metrics: ui,
          onTap: () => widget.onSelected(item),
        );
      },
    );
  }
}

class _PickerSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final _PickerMetrics metrics;
  final String hintText;

  final bool showCancel;

  final ValueChanged<String> onChanged;
  final VoidCallback onCancel;

  const _PickerSearchField({
    required this.controller,
    required this.focusNode,
    required this.metrics,
    required this.hintText,
    required this.showCancel,
    required this.onChanged,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      height: metrics.searchHeight,
      padding: EdgeInsets.only(
        left: metrics.searchInnerHorizontal,
        right: showCancel
            ? metrics.searchCancelRightPadding
            : metrics.searchInnerHorizontal,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(
          metrics.searchRadius,
        ),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.search,
            size: metrics.searchIconSize,
            color: const Color(0xFF828282),
          ),

          SizedBox(width: metrics.searchIconGap),

          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              cursorColor: AppColors.primaryIcon,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontSize: metrics.searchFontSize,
                fontWeight: FontWeight.w500,
                color: AppColors.black,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: metrics.searchFontSize,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF828282),
                ),
              ),
            ),
          ),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 130),
            child: showCancel
                ? InkWell(
              key: const ValueKey('picker-search-cancel'),
              onTap: onCancel,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal:
                  metrics.cancelHorizontalPadding,
                  vertical:
                  metrics.cancelVerticalPadding,
                ),
                child: Text(
                  'Huỷ',
                  style: TextStyle(
                    fontSize: metrics.cancelFontSize,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            )
                : const SizedBox.shrink(
              key: ValueKey(
                'picker-search-cancel-hidden',
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
        borderRadius: BorderRadius.circular(
          metrics.rowRadius,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: metrics.rowHeight,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: metrics.rowHorizontalPadding,
              vertical: metrics.rowVerticalPadding,
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    metrics.imageRadius,
                  ),
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

                SizedBox(
                  width: metrics.imageToTitleGap,
                ),

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
  final VoidCallback? onTap;

  const _EmptyItineraryState({
    required this.metrics,
    required this.text,
    required this.showCalendarIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Transform.translate(
      offset: Offset(
        0,
        -metrics.emptyLift,
      ),
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

          SizedBox(
            height: metrics.emptyTextToIconGap,
          ),

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
    );

    return Center(
      child: onTap == null
          ? content
          : Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _PickerMetrics {
  final double headerTopGap;
  final double headerHorizontal;
  final double headerToContentGap;

  final double backButtonSize;
  final double backIconSize;
  final double backToSearchGap;

  final double searchHeight;
  final double searchRadius;
  final double searchInnerHorizontal;
  final double searchCancelRightPadding;
  final double searchIconSize;
  final double searchIconGap;
  final double searchFontSize;

  final double cancelHorizontalPadding;
  final double cancelVerticalPadding;
  final double cancelFontSize;

  final double listHorizontal;
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
    required this.headerTopGap,
    required this.headerHorizontal,
    required this.headerToContentGap,
    required this.backButtonSize,
    required this.backIconSize,
    required this.backToSearchGap,
    required this.searchHeight,
    required this.searchRadius,
    required this.searchInnerHorizontal,
    required this.searchCancelRightPadding,
    required this.searchIconSize,
    required this.searchIconGap,
    required this.searchFontSize,
    required this.cancelHorizontalPadding,
    required this.cancelVerticalPadding,
    required this.cancelFontSize,
    required this.listHorizontal,
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
    double c(double value, double min, double max) {
      return value.clamp(min, max).toDouble();
    }

    return _PickerMetrics(
      headerTopGap: c(width * 0.055, 18, 24),
      headerHorizontal: c(width * 0.060, 20, 26),
      headerToContentGap: c(width * 0.065, 22, 28),

      backButtonSize: c(width * 0.105, 38, 44),
      backIconSize: c(width * 0.072, 25, 30),
      backToSearchGap: c(width * 0.022, 7, 10),

      searchHeight: c(width * 0.115, 42, 48),
      searchRadius: c(width * 0.060, 20, 25),
      searchInnerHorizontal: c(width * 0.040, 13, 17),
      searchCancelRightPadding: c(width * 0.012, 4, 6),
      searchIconSize: c(width * 0.065, 23, 27),
      searchIconGap: c(width * 0.025, 8, 11),
      searchFontSize: c(width * 0.038, 14, 16),

      cancelHorizontalPadding: c(width * 0.020, 7, 9),
      cancelVerticalPadding: c(width * 0.018, 6, 8),
      cancelFontSize: c(width * 0.034, 12.5, 14),

      listHorizontal: c(width * 0.075, 25, 31),
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
