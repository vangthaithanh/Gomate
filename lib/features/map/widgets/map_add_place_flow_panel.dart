import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../trip/models/trip_ui_models.dart';

enum GoMateMapAddPlaceStep {
  day,
  startTime,
  endTime,
}

class GoMateMapAddPlaceFlowPanel extends StatefulWidget {
  final TripUi trip;
  final GoMateMapAddPlaceStep step;

  final int selectedDay;
  final String? selectedTime;

  final ValueChanged<int> onDayChanged;
  final ValueChanged<String> onTimeChanged;

  final VoidCallback onContinue;
  final VoidCallback onSkip;

  const GoMateMapAddPlaceFlowPanel({
    super.key,
    required this.trip,
    required this.step,
    required this.selectedDay,
    required this.selectedTime,
    required this.onDayChanged,
    required this.onTimeChanged,
    required this.onContinue,
    required this.onSkip,
  });

  @override
  State<GoMateMapAddPlaceFlowPanel> createState() =>
      _GoMateMapAddPlaceFlowPanelState();
}

class _GoMateMapAddPlaceFlowPanelState
    extends State<GoMateMapAddPlaceFlowPanel> {
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  late int _hour;
  late int _minute;

  int get _safeDay =>
      widget.selectedDay.clamp(1, widget.trip.days).toInt();

  @override
  void initState() {
    super.initState();

    _dayController = FixedExtentScrollController(
      initialItem: _safeDay - 1,
    );

    final parsed = _parseTime(widget.selectedTime);
    _hour = parsed.$1;
    _minute = parsed.$2;

    _hourController = FixedExtentScrollController(
      initialItem: _hour,
    );

    _minuteController = FixedExtentScrollController(
      initialItem: _minute ~/ 5,
    );

  }

  @override
  void didUpdateWidget(
    covariant GoMateMapAddPlaceFlowPanel oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.step != widget.step) {
      final parsed = _parseTime(widget.selectedTime);
      _hour = parsed.$1;
      _minute = parsed.$2;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (widget.step == GoMateMapAddPlaceStep.day) {
          _dayController.jumpToItem(_safeDay - 1);
        } else {
          _hourController.jumpToItem(_hour);
          _minuteController.jumpToItem(_minute ~/ 5);
          // Không tự emit 00:00 khi user chưa thao tác.
          // selectedTime chỉ đổi khi người dùng thực sự cuộn wheel.
        }
      });
    }
  }

  (int, int) _parseTime(String? value) {
    final raw = value?.trim() ?? '';
    final parts = raw.split(':');

    if (parts.length != 2) {
      return (0, 0);
    }

    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;

    final normalizedMinute =
        ((m / 5).round() * 5).clamp(0, 55).toInt();

    return (
      h.clamp(0, 23).toInt(),
      normalizedMinute,
    );
  }

  String _formatTime() {
    return '${_hour.toString().padLeft(2, '0')}:'
        '${_minute.toString().padLeft(2, '0')}';
  }

  void _emitTime() {
    widget.onTimeChanged(_formatTime());
  }

  DateTime? _dayDate(int day) {
    final start = widget.trip.startDate;
    if (start == null) return null;

    return start.add(
      Duration(days: day - 1),
    );
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
  void dispose() {
    _dayController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    final panelHeight = widget.step == GoMateMapAddPlaceStep.day
        ? (width * 0.43).clamp(154.0, 176.0).toDouble()
        : (width * 0.52).clamp(186.0, 215.0).toDouble();

    return Container(
      height: panelHeight + safeBottom,
      padding: EdgeInsets.fromLTRB(
        (width * 0.065).clamp(22.0, 27.0).toDouble(),
        (width * 0.022).clamp(8.0, 10.0).toDouble(),
        (width * 0.065).clamp(22.0, 27.0).toDouble(),
        safeBottom + (width * 0.025).clamp(9.0, 11.0).toDouble(),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(
            (width * 0.055).clamp(18.0, 22.0).toDouble(),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: (width * 0.12).clamp(42.0, 48.0).toDouble(),
            height: 3,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          SizedBox(height: width * 0.018),
          if (widget.step == GoMateMapAddPlaceStep.day)
            Expanded(child: _buildDayStep(width))
          else
            Expanded(child: _buildTimeStep(width)),
          SizedBox(height: width * 0.010),
          _ContinueButton(
            label: 'Tiếp tục',
            onTap: widget.onContinue,
          ),
        ],
      ),
    );
  }

  Widget _buildDayStep(double width) {
    return Row(
      children: [
        Expanded(
          child: CupertinoPicker(
            scrollController: _dayController,
            itemExtent: (width * 0.105).clamp(38.0, 43.0).toDouble(),
            magnification: 1.05,
            squeeze: 1.0,
            useMagnifier: true,
            selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
              background: Color(0x12DADADA),
            ),
            onSelectedItemChanged: (index) {
              widget.onDayChanged(index + 1);
            },
            children: List.generate(
              widget.trip.days,
              (index) {
                final day = index + 1;
                final date = _dayDate(day);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Ngày $day',
                      style: TextStyle(
                        fontSize:
                            (width * 0.034).clamp(12.0, 13.5).toDouble(),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: width * 0.025),
                    Text(
                      _dateLabel(date),
                      style: TextStyle(
                        fontSize:
                            (width * 0.033).clamp(12.0, 13.0).toDouble(),
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    if (date != null) ...[
                      SizedBox(width: width * 0.018),
                      Text(
                        _weekdayLabel(date),
                        style: TextStyle(
                          fontSize:
                              (width * 0.025).clamp(9.0, 10.5).toDouble(),
                          fontWeight: FontWeight.w600,
                          color: AppColors.grayText,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeStep(double width) {
    final title = widget.step == GoMateMapAddPlaceStep.startTime
        ? 'Giờ bắt đầu'
        : 'Giờ kết thúc';

    return Column(
      children: [
        SizedBox(
          height: (width * 0.060).clamp(21.0, 25.0).toDouble(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize:
                      (width * 0.040).clamp(14.5, 16.5).toDouble(),
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: widget.onSkip,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(
                      'Bỏ qua',
                      style: TextStyle(
                        fontSize:
                            (width * 0.029).clamp(10.5, 12.0).toDouble(),
                        fontWeight: FontWeight.w700,
                        color: AppColors.grayText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: (width * 0.18).clamp(64.0, 76.0).toDouble(),
                child: CupertinoPicker(
                  scrollController: _hourController,
                  itemExtent:
                      (width * 0.09).clamp(32.0, 38.0).toDouble(),
                  magnification: 1.10,
                  squeeze: 1.0,
                  useMagnifier: true,
                  selectionOverlay:
                      const CupertinoPickerDefaultSelectionOverlay(
                    background: Color(0x12DADADA),
                  ),
                  onSelectedItemChanged: (value) {
                    _hour = value;
                    _emitTime();
                  },
                  children: List.generate(
                    24,
                    (index) => Center(
                      child: Text(
                        index.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize:
                              (width * 0.042).clamp(15.0, 17.0).toDouble(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal:
                      (width * 0.025).clamp(8.0, 10.0).toDouble(),
                ),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize:
                        (width * 0.042).clamp(15.0, 17.0).toDouble(),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: (width * 0.18).clamp(64.0, 76.0).toDouble(),
                child: CupertinoPicker(
                  scrollController: _minuteController,
                  itemExtent:
                      (width * 0.09).clamp(32.0, 38.0).toDouble(),
                  magnification: 1.10,
                  squeeze: 1.0,
                  useMagnifier: true,
                  selectionOverlay:
                      const CupertinoPickerDefaultSelectionOverlay(
                    background: Color(0x12DADADA),
                  ),
                  onSelectedItemChanged: (value) {
                    _minute = value * 5;
                    _emitTime();
                  },
                  children: List.generate(
                    12,
                    (index) => Center(
                      child: Text(
                        (index * 5).toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize:
                              (width * 0.042).clamp(15.0, 17.0).toDouble(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContinueButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ContinueButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final buttonWidth =
        (width * 0.40).clamp(145.0, 164.0).toDouble();
    final height =
        (width * 0.080).clamp(29.0, 34.0).toDouble();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(height / 2),
        child: Ink(
          width: buttonWidth,
          height: height,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize:
                    (width * 0.029).clamp(10.5, 12.0).toDouble(),
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
