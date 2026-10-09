import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../trip/models/trip_ui_models.dart';

class GoMateMapDayRoutePanel extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final radius = (width * 0.035).clamp(12.0, 15.0).toDouble();
    final maxHeight = (width * 0.64).clamp(220.0, 270.0).toDouble();

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(radius),
        ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: width * 0.025),
          Container(
            width: (width * 0.125).clamp(42.0, 48.0).toDouble(),
            height: 3,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          SizedBox(height: width * 0.022),
          if (canEdit)
            InkWell(
              onTap: onOptimize,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.030,
                  vertical: width * 0.008,
                ),
                child: Text(
                  'Tối ưu lộ trình',
                  style: TextStyle(
                    fontSize:
                        (width * 0.033).clamp(12.0, 13.5).toDouble(),
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
                fontSize:
                    (width * 0.033).clamp(12.0, 13.5).toDouble(),
                fontWeight: FontWeight.w800,
                color: AppColors.primaryText,
              ),
            ),
          SizedBox(height: width * 0.018),
          if (places.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                width * 0.08,
                width * 0.035,
                width * 0.08,
                // Empty-state cũng phải chừa đúng vùng navbar.
                // Nhờ vậy panel được kéo cao lên thay vì để text lọt xuống sau nav.
                (bottomInset + width * 0.055)
                    .clamp(30.0, 130.0)
                    .toDouble(),
              ),
              child: Text(
                canEdit
                    ? 'Ngày này chưa có địa điểm. Chọn một địa điểm trên bản đồ và bấm dấu + để thêm.'
                    : 'Ngày này chưa có địa điểm.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize:
                      (width * 0.029).clamp(10.5, 12.0).toDouble(),
                  height: 1.35,
                  color: AppColors.grayText,
                ),
              ),
            )
          else
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                buildDefaultDragHandles: canEdit,
                padding: EdgeInsets.fromLTRB(
                  (width * 0.070).clamp(24.0, 29.0).toDouble(),
                  0,
                  (width * 0.070).clamp(24.0, 29.0).toDouble(),
                  (bottomInset + width * 0.02)
                      .clamp(16.0, 110.0)
                      .toDouble(),
                ),
                itemCount: places.length,
                onReorder: canEdit && onReorder != null
                    ? onReorder!
                    : (_, __) {},
                itemBuilder: (context, index) {
                  final place = places[index];

                  return Padding(
                    // Một place có thể xuất hiện nhiều lần trong cùng ngày.
                    // Không dùng place.id làm Key vì các occurrence cùng địa điểm
                    // sẽ có cùng placeId và Flutter sẽ coi chúng là cùng item.
                    // ObjectKey giữ mỗi TripPlaceUi occurrence là một item riêng.
                    key: ObjectKey(place),
                    padding: EdgeInsets.only(
                      bottom:
                          (width * 0.025).clamp(9.0, 11.0).toDouble(),
                    ),
                    child: _RoutePlaceCard(
                      place: place,
                      canEdit: canEdit,
                      onTap: () => onPlaceTap(index),
                      onRemove: canEdit && onRemove != null
                          ? () => onRemove!(index)
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

    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start - $end';
    }

    return start.isNotEmpty ? start : end;
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
                        fontSize:
                            (width * 0.033).clamp(12.0, 13.5).toDouble(),
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
                        fontSize:
                            (width * 0.029).clamp(10.5, 12.0).toDouble(),
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
                      size:
                          (width * 0.040).clamp(14.0, 16.5).toDouble(),
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

  const _PlaceImage({
    required this.place,
  });

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
        child: Icon(
          LucideIcons.image,
          color: AppColors.primaryIcon,
        ),
      ),
    );
  }
}
