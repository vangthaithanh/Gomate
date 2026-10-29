import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../trip/models/trip_ui_models.dart';

class GoMateMapDayRoutePanel extends StatefulWidget {
  final List<TripPlaceUi> places;
  final bool canEdit;
  final double bottomInset;

  final VoidCallback? onOptimize;
  final ValueChanged<int> onPlaceTap;
  final ValueChanged<int>? onRemove;
  final ReorderCallback? onReorder;

  const GoMateMapDayRoutePanel({
    super.key,
    required this.places,
    required this.canEdit,
    required this.onPlaceTap,
    this.bottomInset = 0,
    this.onOptimize,
    this.onRemove,
    this.onReorder,
  });

  static double collapsedHeightFor(double width) =>
      (width * 0.64).clamp(220.0, 270.0).toDouble();

  @override
  State<GoMateMapDayRoutePanel> createState() => _GoMateMapDayRoutePanelState();
}

class _GoMateMapDayRoutePanelState extends State<GoMateMapDayRoutePanel> {
  final _sheetController = DraggableScrollableController();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        if (height <= 0) return const SizedBox.shrink();
        final minimum =
            (GoMateMapDayRoutePanel.collapsedHeightFor(width) / height)
                .clamp(0.0, 1.0)
                .toDouble();

        return DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: minimum,
          minChildSize: minimum,
          maxChildSize: 1,
          expand: false,
          shouldCloseOnMinExtent: false,
          builder: (context, scrollController) => _buildPanel(
            context,
            scrollController,
            onDrag: (details) {
              if (!_sheetController.isAttached) return;
              _sheetController.jumpTo(
                (_sheetController.size - details.delta.dy / height)
                    .clamp(minimum, 1.0)
                    .toDouble(),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPanel(
    BuildContext context,
    ScrollController scrollController, {
    required GestureDragUpdateCallback onDrag,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final radius = (width * 0.035).clamp(12.0, 15.0).toDouble();

    return Container(
      key: const ValueKey('map-day-route-panel'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, -2),
          ),
          BoxShadow(
            color: const Color(0xFF0B3E8A).withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          GestureDetector(
            key: const ValueKey('map-day-route-drag-handle'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: onDrag,
            child: SizedBox(
              height: 30,
              width: double.infinity,
              child: Center(
                child: Container(
                  width: (width * 0.125).clamp(42.0, 48.0).toDouble(),
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
          if (widget.canEdit)
            InkWell(
              onTap: widget.onOptimize,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.030,
                  vertical: width * 0.008,
                ),
                child: Text(
                  'Tối ưu lộ trình',
                  style: TextStyle(
                    fontSize: (width * 0.033).clamp(12.0, 13.5).toDouble(),
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            )
          else
            Text(
              'Lộ trình trong ngày',
              style: TextStyle(
                fontSize: (width * 0.033).clamp(12.0, 13.5).toDouble(),
                fontWeight: FontWeight.w800,
                color: AppColors.primaryText,
              ),
            ),
          SizedBox(height: width * 0.018),
          if (widget.places.isEmpty)
            Expanded(
              child: ListView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  width * 0.08,
                  width * 0.035,
                  width * 0.08,
                  // Empty-state cũng phải chừa đúng vùng navbar.
                  // Nhờ vậy panel được kéo cao lên thay vì để text lọt xuống sau nav.
                  (widget.bottomInset + width * 0.055)
                      .clamp(30.0, double.infinity)
                      .toDouble(),
                ),
                children: [
                  Text(
                    widget.canEdit
                        ? 'Ngày này chưa có địa điểm. Chọn một địa điểm trên bản đồ và bấm dấu + để thêm.'
                        : 'Ngày này chưa có địa điểm.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: (width * 0.029).clamp(10.5, 12.0).toDouble(),
                      height: 1.35,
                      color: AppColors.grayText,
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ReorderableListView.builder(
                scrollController: scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                buildDefaultDragHandles: widget.canEdit,
                padding: EdgeInsets.fromLTRB(
                  (width * 0.070).clamp(24.0, 29.0).toDouble(),
                  0,
                  (width * 0.070).clamp(24.0, 29.0).toDouble(),
                  (widget.bottomInset + width * 0.02)
                      .clamp(16.0, double.infinity)
                      .toDouble(),
                ),
                itemCount: widget.places.length,
                onReorder: widget.canEdit && widget.onReorder != null
                    ? widget.onReorder!
                    : (_, __) {},
                itemBuilder: (context, index) {
                  final place = widget.places[index];

                  return Padding(
                    // Một place có thể xuất hiện nhiều lần trong cùng ngày.
                    // Không dùng place.id làm Key vì các occurrence cùng địa điểm
                    // sẽ có cùng placeId và Flutter sẽ coi chúng là cùng item.
                    // ObjectKey giữ mỗi TripPlaceUi occurrence là một item riêng.
                    key: ObjectKey(place),
                    padding: EdgeInsets.only(
                      bottom: (width * 0.025).clamp(9.0, 11.0).toDouble(),
                    ),
                    child: _RoutePlaceCard(
                      place: place,
                      canEdit: widget.canEdit,
                      onTap: () => widget.onPlaceTap(index),
                      onRemove: widget.canEdit && widget.onRemove != null
                          ? () => widget.onRemove!(index)
                          : null,
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

class _RoutePlaceCard extends StatelessWidget {
  final TripPlaceUi place;
  final bool canEdit;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _RoutePlaceCard({
    required this.place,
    required this.canEdit,
    required this.onTap,
    this.onRemove,
  });

  String get _timeLabel {
    final start = place.startTime.trim();
    final end = place.endTime.trim();

    if (start.isEmpty && end.isEmpty) {
      return 'Chưa đặt thời gian';
    }

    if (place.hasFullTime) {
      return '$start - $end';
    }

    if (start.isNotEmpty) {
      return 'Bắt đầu $start • chưa có giờ kết thúc';
    }

    return 'Chưa đặt thời gian';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.135).clamp(48.0, 54.0).toDouble();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canEdit ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              SizedBox(
                width: height,
                height: height,
                child: _PlaceImage(place: place),
              ),
              SizedBox(width: width * 0.025),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: (width * 0.033).clamp(12.0, 13.5).toDouble(),
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: width * 0.006),
                    Text(
                      _timeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: (width * 0.029).clamp(10.5, 12.0).toDouble(),
                        fontWeight: FontWeight.w400,
                        color: AppColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),
              if (onRemove != null)
                InkWell(
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.all(
                      (width * 0.035).clamp(12.0, 15.0).toDouble(),
                    ),
                    child: Icon(
                      LucideIcons.x,
                      size: (width * 0.040).clamp(14.0, 16.5).toDouble(),
                      color: AppColors.grayText,
                    ),
                  ),
                )
              else
                SizedBox(width: width * 0.035),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceImage extends StatelessWidget {
  final TripPlaceUi place;

  const _PlaceImage({required this.place});

  @override
  Widget build(BuildContext context) {
    final network = place.imageUrl?.trim() ?? '';
    if (network.isNotEmpty) {
      return Image.network(
        network,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    final asset = place.imageAsset?.trim() ?? '';
    if (asset.isNotEmpty) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    return _fallback();
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
