import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../models/map_place.dart';
import 'route_panel_metrics.dart';

class GoMateRouteEditorResult {
  final GoMateMapPlace? originPlace;
  final List<GoMateMapPlace> stops;

  const GoMateRouteEditorResult({
    required this.originPlace,
    required this.stops,
  });
}

/// Editor nổi trên Map. Outer panel có chiều cao cố định giống route summary.
/// Danh sách điểm nằm trong vùng scroll; kéo grip ở từng destination để reorder.
class GoMateRouteEditorSheet extends StatefulWidget {
  final String originLabel;
  final GoMateMapPlace? initialOriginPlace;
  final List<GoMateMapPlace> initialStops;
  final Future<GoMateMapPlace?> Function() onPickPlace;
  final VoidCallback onCancel;
  final ValueChanged<GoMateRouteEditorResult> onDone;

  const GoMateRouteEditorSheet({
    super.key,
    required this.originLabel,
    required this.initialOriginPlace,
    required this.initialStops,
    required this.onPickPlace,
    required this.onCancel,
    required this.onDone,
  });

  @override
  State<GoMateRouteEditorSheet> createState() =>
      _GoMateRouteEditorSheetState();
}

class _GoMateRouteEditorSheetState extends State<GoMateRouteEditorSheet> {
  final ScrollController _listController = ScrollController();

  late List<GoMateMapPlace> _stops;
  GoMateMapPlace? _originPlace;
  bool _picking = false;

  String get _originLabel => _originPlace?.name ?? widget.originLabel;

  @override
  void initState() {
    super.initState();
    _stops = List<GoMateMapPlace>.from(widget.initialStops);
    _originPlace = widget.initialOriginPlace;
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<GoMateMapPlace?> _pick() async {
    if (_picking) return null;
    setState(() => _picking = true);
    try {
      return await widget.onPickPlace();
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _replaceOrigin() async {
    final place = await _pick();
    if (!mounted || place == null) return;

    setState(() {
      _originPlace = place;
      _stops.removeWhere((item) => item.placeId == place.placeId);
    });
  }

  Future<void> _replaceStop(int index) async {
    final place = await _pick();
    if (!mounted || place == null) return;
    if (_originPlace?.placeId == place.placeId) return;
    if (index < 0 || index >= _stops.length) return;

    setState(() {
      _stops.removeWhere(
        (item) => item.placeId == place.placeId && item != _stops[index],
      );
      if (index < _stops.length) {
        _stops[index] = place;
      }
    });
  }

  Future<void> _addStop() async {
    final place = await _pick();
    if (!mounted || place == null) return;
    if (_originPlace?.placeId == place.placeId) return;
    if (_stops.any((item) => item.placeId == place.placeId)) return;

    setState(() => _stops.add(place));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_listController.hasClients) return;
      _listController.animateTo(
        _listController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < 0 || oldIndex >= _stops.length) return;
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _stops.removeAt(oldIndex);
      final target = newIndex.clamp(0, _stops.length).toInt();
      _stops.insert(target, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final panelHeight = goMateRoutePanelHeight(context);
    final padding = (width * 0.044).clamp(15.0, 18.0).toDouble();

    return Container(
      width: double.infinity,
      height: panelHeight,
      padding: EdgeInsets.fromLTRB(padding, padding * 0.72, padding, padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          (width * 0.042).clamp(15.0, 18.0).toDouble(),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.040),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _EditorField(
            label: _originLabel,
            onTap: _replaceOrigin,
            onRemove: _originPlace == null
                ? null
                : () => setState(() => _originPlace = null),
            reserveGripSpace: true,
          ),
          SizedBox(height: width * 0.020),
          Expanded(
            child: Scrollbar(
              controller: _listController,
              thumbVisibility: _stops.length >= 2,
              thickness: 3.5,
              radius: const Radius.circular(999),
              child: ReorderableListView.builder(
                scrollController: _listController,
                buildDefaultDragHandles: false,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(right: width * 0.014),
                itemCount: _stops.length + 1,
                onReorder: _onReorder,
                itemBuilder: (context, index) {
                  if (index == _stops.length) {
                    return Padding(
                      key: const ValueKey('add-route-stop'),
                      padding: EdgeInsets.only(top: width * 0.004),
                      child: _AddPlaceField(
                        loading: _picking,
                        onTap: _addStop,
                      ),
                    );
                  }

                  final stop = _stops[index];
                  return Padding(
                    key: ValueKey('route-stop-${stop.placeId}'),
                    padding: EdgeInsets.only(bottom: width * 0.020),
                    child: _EditorField(
                      label: stop.name,
                      onTap: () => _replaceStop(index),
                      onRemove: () => setState(() => _stops.removeAt(index)),
                      dragHandle: ReorderableDelayedDragStartListener(
                        index: index,
                        child: const _DragGrip(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: width * 0.020),
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onCancel,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: width * 0.008),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: (width * 0.060).clamp(22.0, 25.0).toDouble(),
                          height: (width * 0.060).clamp(22.0, 25.0).toDouble(),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryIcon,
                          ),
                          child: Icon(
                            LucideIcons.x,
                            size: (width * 0.038).clamp(13.0, 16.0).toDouble(),
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: width * 0.020),
                        Text(
                          'Huỷ',
                          style: TextStyle(
                            fontSize:
                                (width * 0.030).clamp(11.0, 12.5).toDouble(),
                            color: AppColors.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: (width * 0.42).clamp(145.0, 175.0).toDouble(),
                child: _GradientButton(
                  label: 'Hoàn tất',
                  onTap: () {
                    if (_stops.isEmpty) return;
                    widget.onDone(
                      GoMateRouteEditorResult(
                        originPlace: _originPlace,
                        stops: List<GoMateMapPlace>.from(_stops),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditorField extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final Widget? dragHandle;
  final bool reserveGripSpace;

  const _EditorField({
    required this.label,
    required this.onTap,
    required this.onRemove,
    this.dragHandle,
    this.reserveGripSpace = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.098).clamp(38.0, 43.0).toDouble();
    final gripWidth = (width * 0.052).clamp(18.0, 21.0).toDouble();

    return Row(
      children: [
        SizedBox(
          width: gripWidth,
          child: dragHandle ??
              (reserveGripSpace ? const SizedBox.shrink() : null),
        ),
        SizedBox(width: width * 0.012),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(height / 2),
              child: Ink(
                height: height,
                padding: EdgeInsets.symmetric(horizontal: width * 0.046),
                decoration: BoxDecoration(
                  color: AppColors.grayBackground,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: (width * 0.032).clamp(11.8, 13.5).toDouble(),
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: width * 0.016),
        SizedBox(
          width: (width * 0.070).clamp(25.0, 29.0).toDouble(),
          child: onRemove == null
              ? const SizedBox.shrink()
              : InkWell(
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.all(width * 0.006),
                    child: Icon(
                      LucideIcons.x,
                      size: (width * 0.050).clamp(18.0, 21.0).toDouble(),
                      color: AppColors.grayText,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _DragGrip extends StatelessWidget {
  const _DragGrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 30,
      child: Center(
        child: Wrap(
          spacing: 3,
          runSpacing: 3,
          children: List.generate(
            6,
            (_) => Container(
              width: 3,
              height: 3,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.grayText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddPlaceField extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _AddPlaceField({
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.098).clamp(38.0, 43.0).toDouble();
    final gripWidth = (width * 0.052).clamp(18.0, 21.0).toDouble();

    return Row(
      children: [
        SizedBox(width: gripWidth),
        SizedBox(width: width * 0.012),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: loading ? null : onTap,
              borderRadius: BorderRadius.circular(height / 2),
              child: Ink(
                height: height,
                padding: EdgeInsets.symmetric(horizontal: width * 0.046),
                decoration: BoxDecoration(
                  color: AppColors.grayBackground,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    loading ? 'Đang mở tìm kiếm...' : 'Nhập địa điểm....',
                    style: TextStyle(
                      fontSize: (width * 0.032).clamp(11.8, 13.5).toDouble(),
                      color: AppColors.grayText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: width * 0.016),
        SizedBox(width: (width * 0.070).clamp(25.0, 29.0).toDouble()),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.087).clamp(34.0, 39.0).toDouble();

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
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: (width * 0.029).clamp(10.5, 12.0).toDouble(),
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
