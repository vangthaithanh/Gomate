import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../models/map_place.dart';
import '../models/map_route.dart';
import 'route_panel_metrics.dart';

class GoMateDirectionsRouteSheet extends StatelessWidget {
  final GoMateMapRoute route;
  final String originLabel;
  final List<GoMateMapPlace> stops;

  final VoidCallback onOriginTap;
  final VoidCallback onDestinationTap;
  final VoidCallback onSwap;
  final VoidCallback onEdit;
  final VoidCallback onAddStop;
  final VoidCallback onStart;
  final VoidCallback onClose;

  const GoMateDirectionsRouteSheet({
    super.key,
    required this.route,
    required this.originLabel,
    required this.stops,
    required this.onOriginTap,
    required this.onDestinationTap,
    required this.onSwap,
    required this.onEdit,
    required this.onAddStop,
    required this.onStart,
    required this.onClose,
  });

  bool get _twoPointMode => stops.length == 1;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final panelHeight = goMateRoutePanelHeight(context);
    final padding = (width * 0.046).clamp(16.0, 19.0).toDouble();

    return Container(
      height: panelHeight,
      padding: EdgeInsets.fromLTRB(padding, padding * 0.72, padding, padding * 0.92),
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
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      _distanceText(route.distanceKm),
                      style: TextStyle(
                        fontSize: (width * 0.034).clamp(12.5, 14.5).toDouble(),
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(width: width * 0.020),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFD1D1D1),
                      ),
                    ),
                    SizedBox(width: width * 0.020),
                    Expanded(
                      child: Text(
                        _durationText(route.durationMinutes, stops.length),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: (width * 0.031).clamp(11.5, 13.0).toDouble(),
                          fontWeight: FontWeight.w500,
                          color: AppColors.grayText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onClose,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: EdgeInsets.all(width * 0.006),
                  child: Icon(
                    LucideIcons.x,
                    size: (width * 0.055).clamp(20.0, 23.0).toDouble(),
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: width * 0.024),
          Expanded(
            child: _twoPointMode
                ? _TwoPointFields(
                    originLabel: originLabel,
                    destinationLabel: stops.first.name,
                    onOriginTap: onOriginTap,
                    onDestinationTap: onDestinationTap,
                    onSwap: onSwap,
                  )
                : _MultiPointSummary(
                    originLabel: originLabel,
                    stops: stops,
                    onTap: onEdit,
                  ),
          ),
          SizedBox(height: width * 0.022),
          Row(
            children: [
              Expanded(child: _AddStopButton(onTap: onAddStop)),
              SizedBox(width: width * 0.040),
              Expanded(
                child: _GradientButton(
                  label: 'Bắt đầu',
                  onTap: onStart,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _distanceText(double km) {
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  String _durationText(int minutes, int stopCount) {
    final duration = minutes >= 60
        ? '${(minutes / 60).ceil()} tiếng'
        : '$minutes phút';
    if (stopCount <= 1) return duration;
    return '$duration (${stopCount} điểm dừng)';
  }
}

class _TwoPointFields extends StatelessWidget {
  final String originLabel;
  final String destinationLabel;
  final VoidCallback onOriginTap;
  final VoidCallback onDestinationTap;
  final VoidCallback onSwap;

  const _TwoPointFields({
    required this.originLabel,
    required this.destinationLabel,
    required this.onOriginTap,
    required this.onDestinationTap,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RouteField(
                label: originLabel,
                onTap: onOriginTap,
              ),
              SizedBox(height: width * 0.030),
              _RouteField(
                label: destinationLabel,
                onTap: onDestinationTap,
              ),
            ],
          ),
        ),
        SizedBox(width: width * 0.026),
        _SwapButton(onTap: onSwap),
      ],
    );
  }
}

class _RouteField extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RouteField({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = (width * 0.102).clamp(39.0, 44.0).toDouble();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(height / 2),
        child: Ink(
          width: double.infinity,
          height: height,
          padding: EdgeInsets.symmetric(horizontal: width * 0.050),
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
                fontSize: (width * 0.033).clamp(12.0, 13.8).toDouble(),
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SwapButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SwapButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final size = (width * 0.088).clamp(33.0, 38.0).toDouble();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: SizedBox(
              width: size * 0.60,
              height: size * 0.70,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: Icon(
                      LucideIcons.chevron_up,
                      size: size * 0.48,
                      color: Colors.black,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(
                      LucideIcons.chevron_down,
                      size: size * 0.48,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiPointSummary extends StatefulWidget {
  final String originLabel;
  final List<GoMateMapPlace> stops;
  final VoidCallback onTap;

  const _MultiPointSummary({
    required this.originLabel,
    required this.stops,
    required this.onTap,
  });

  @override
  State<_MultiPointSummary> createState() => _MultiPointSummaryState();
}

class _MultiPointSummaryState extends State<_MultiPointSummary> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            width * 0.036,
            width * 0.020,
            width * 0.020,
            width * 0.020,
          ),
          decoration: BoxDecoration(
            color: AppColors.grayBackground,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: widget.stops.length >= 3,
            thickness: 3,
            radius: const Radius.circular(999),
            child: ListView.builder(
              controller: _controller,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(right: width * 0.020),
              itemCount: widget.stops.length + 1,
              itemBuilder: (context, index) {
                final label = index == 0
                    ? widget.originLabel
                    : widget.stops[index - 1].name;
                final last = index == widget.stops.length;
                return _SummaryStopRow(
                  label: label,
                  showTrail: !last,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryStopRow extends StatelessWidget {
  final String label;
  final bool showTrail;

  const _SummaryStopRow({
    required this.label,
    required this.showTrail,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 18,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.grayText,
                ),
              ),
              if (showTrail)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    children: List.generate(
                      3,
                      (_) => Container(
                        width: 3,
                        height: 3,
                        margin: const EdgeInsets.symmetric(vertical: 1),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.grayText,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: width * 0.014),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: width * 0.018),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: (width * 0.031).clamp(11.5, 13.0).toDouble(),
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddStopButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddStopButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: width * 0.010),
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
                  LucideIcons.plus,
                  size: (width * 0.040).clamp(14.0, 17.0).toDouble(),
                  color: Colors.white,
                ),
              ),
              SizedBox(width: width * 0.020),
              Flexible(
                child: Text(
                  'Thêm điểm dừng',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: (width * 0.030).clamp(11.0, 12.5).toDouble(),
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w500,
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
