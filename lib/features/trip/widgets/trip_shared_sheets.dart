import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gomate_member_invite_content.dart';
import '../../messages/models/message_models.dart';
import '../models/trip_ui_models.dart';

double _tripClamp(
  double value,
  double min,
  double max,
) {
  return value.clamp(min, max).toDouble();
}
// ============================================================================
// INVITE MEMBERS
// ============================================================================

/// Adapter Trip -> popup mời thành viên dùng chung.
///
/// Create Trip:
/// - [initialPendingInviteIds] là draft pending.
/// - chưa gửi notification.
/// - accepted members bị loại khỏi candidate.
/// - pending nằm trên đầu và có thể huỷ.
///
/// Trip đã tồn tại nhưng chưa thành group vẫn có thể dùng cùng adapter.
/// Backend sau này quyết định thời điểm dispatch notification.
class TripInviteMembersContent extends StatefulWidget {
  final List<MessageContact> contacts;
  final Set<String> initialPendingInviteIds;
  final Set<String> acceptedMemberIds;
  final ValueChanged<Set<String>>? onPendingChanged;

  const TripInviteMembersContent({
    super.key,
    required this.contacts,
    this.initialPendingInviteIds = const <String>{},
    this.acceptedMemberIds = const <String>{},
    this.onPendingChanged,
  });

  @override
  State<TripInviteMembersContent> createState() =>
      _TripInviteMembersContentState();
}

class _TripInviteMembersContentState
    extends State<TripInviteMembersContent> {
  late final Set<String> _pending;

  @override
  void initState() {
    super.initState();
    _pending = <String>{...widget.initialPendingInviteIds};
  }

  void _emit() {
    widget.onPendingChanged?.call(
      Set<String>.unmodifiable(_pending),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = widget.contacts
        .map(
          (contact) => GoMateInviteContact(
            id: contact.id,
            name: contact.name,
            subtitle: contact.subtitle,
            avatarAsset: contact.avatarAsset,
          ),
        )
        .toList(growable: false);

    return GoMateMemberInviteContent(
      contacts: contacts,
      pendingInviteIds: _pending,
      excludedContactIds: widget.acceptedMemberIds,
      onAddInvites: (ids) {
        setState(() {
          _pending.addAll(ids);
        });

        _emit();
      },
      onCancelPending: (id) {
        setState(() {
          _pending.remove(id);
        });

        _emit();
      },
    );
  }
}

// ============================================================================
// DATE RANGE
// ============================================================================

class TripDateRangeContent extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;

  const TripDateRangeContent({
    super.key,
    this.initialStart,
    this.initialEnd,
  });

  @override
  State<TripDateRangeContent> createState() =>
      _TripDateRangeContentState();
}

class _TripDateRangeContentState
    extends State<TripDateRangeContent> {
  late DateTime _calendarMonth;

  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();

    _start = widget.initialStart;
    _end = widget.initialEnd;

    final base = _start ?? DateTime.now();

    _calendarMonth = DateTime(base.year, base.month);
  }

  String get _rangeHint {
    if (_start == null) {
      return 'Chọn ngày bắt đầu';
    }

    if (_end == null) {
      return 'Đã chọn ${_format(_start!)} • Chọn ngày kết thúc';
    }

    final days = _end!.difference(_start!).inDays + 1;

    return '${_format(_start!)} - ${_format(_end!)} • $days ngày';
  }

  void _select(DateTime date) {
    setState(() {
      if (_start == null || _end != null) {
        _start = date;
        _end = null;
        return;
      }

      if (date.isBefore(_start!)) {
        _start = date;
        _end = null;
        return;
      }

      _end = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final year = _calendarMonth.year;
    final month = _calendarMonth.month;

    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingDays = firstDay.weekday % 7;
    final previousMonthLastDay = DateTime(year, month, 0).day;
    final totalCells = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Chọn ngày',
            style: TextStyle(
              fontSize: _tripClamp(width * 0.042, 15, 17),
              fontWeight: FontWeight.w700,
            ),
          ),

          SizedBox(height: width * 0.018),

          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _calendarMonth = DateTime(year, month - 1);
                  });
                },
                icon: const Icon(LucideIcons.chevron_left),
              ),
              Expanded(
                child: Text(
                  'Tháng $month $year',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _tripClamp(width * 0.038, 13.5, 15),
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _calendarMonth = DateTime(year, month + 1);
                  });
                },
                icon: const Icon(LucideIcons.chevron_right),
              ),
            ],
          ),

          const Row(
            children: [
              _WeekLabel('CN'),
              _WeekLabel('T2'),
              _WeekLabel('T3'),
              _WeekLabel('T4'),
              _WeekLabel('T5'),
              _WeekLabel('T6'),
              _WeekLabel('T7'),
            ],
          ),

          SizedBox(height: width * 0.015),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final dayOffset = index - leadingDays + 1;

              late DateTime date;
              bool currentMonth = true;

              if (dayOffset <= 0) {
                date = DateTime(
                  year,
                  month - 1,
                  previousMonthLastDay + dayOffset,
                );
                currentMonth = false;
              } else if (dayOffset > daysInMonth) {
                date = DateTime(
                  year,
                  month + 1,
                  dayOffset - daysInMonth,
                );
                currentMonth = false;
              } else {
                date = DateTime(year, month, dayOffset);
              }

              return _dayCell(
                date,
                currentMonth: currentMonth,
              );
            },
          ),

          SizedBox(height: width * 0.020),

          Text(
            _rangeHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _tripClamp(width * 0.028, 10, 11),
              color: AppColors.grayText,
              fontWeight: FontWeight.w600,
            ),
          ),

          SizedBox(height: width * 0.025),

          SizedBox(
            width: _tripClamp(width * 0.43, 150, 170),
            height: _tripClamp(width * 0.12, 44, 48),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _start != null && _end != null
                    ? AppColors.primaryGradient
                    : null,
                color: _start == null || _end == null
                    ? AppColors.grayBorder
                    : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextButton(
                onPressed: _start != null && _end != null
                    ? () {
                        Navigator.of(context).pop(
                          TripDateRangeResult(
                            startDate: _start!,
                            endDate: _end!,
                          ),
                        );
                      }
                    : null,
                child: const Text(
                  'Hoàn tất',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCell(
    DateTime date, {
    required bool currentMonth,
  }) {
    final clean = DateTime(date.year, date.month, date.day);

    final isStart = _start != null && _same(clean, _start!);
    final isEnd = _end != null && _same(clean, _end!);

    final inRange = _start != null &&
        _end != null &&
        clean.isAfter(_start!) &&
        clean.isBefore(_end!);

    final selected = isStart || isEnd;

    return InkWell(
      onTap: currentMonth ? () => _select(clean) : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryIcon
              : inRange
                  ? AppColors.blue100
                  : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(isStart ? 20 : 0),
            right: Radius.circular(isEnd ? 20 : 0),
          ),
        ),
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? Colors.white
                : currentMonth
                    ? Colors.black
                    : AppColors.grayText.withOpacity(0.35),
          ),
        ),
      ),
    );
  }

  static bool _same(
    DateTime a,
    DateTime b,
  ) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  static String _format(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }
}

class _WeekLabel extends StatelessWidget {
  final String text;

  const _WeekLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.grayText,
        ),
      ),
    );
  }
}
