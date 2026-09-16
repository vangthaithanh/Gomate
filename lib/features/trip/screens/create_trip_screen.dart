import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../models/trip_ui_models.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  int _days = 1;
  bool _dateRangeCompleted = false;

  DateTime _calendarMonth =
  DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _selectedPreferences = [];
  final List<String> _preferences = const [
    'Thiên nhiên',
    'Ẩm thực',
    'Check-in',
    'Văn hóa',
    'Local',
    'Gần nhau',
    'Tiết kiệm',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 19,
          ),
        ),
        title: const Text(
          'Tạo lịch trình',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('THÔNG TIN CƠ BẢN'),
            const SizedBox(height: 10),

            _field(
              controller: _nameController,
              hint: 'Tên chuyến đi',
              icon: Icons.edit_outlined,
            ),

            const SizedBox(height: 10),

            _field(
              controller: _destinationController,
              hint: 'Điểm đến chính, VD: Đà Lạt',
              icon: Icons.place_outlined,
            ),

            const SizedBox(height: 12),

            _coverPicker(),

            const SizedBox(height: 24),

            _label('THỜI GIAN'),
            const SizedBox(height: 10),

            const Text(
              'Chọn ngày bắt đầu và ngày kết thúc cho chuyến đi.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 14),

            _calendarRangePicker(),

            const SizedBox(height: 24),

            _label('NGÂN SÁCH'),
            const SizedBox(height: 10),

            TextField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                hintText: 'Nhập số tiền',
                prefixIcon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.textSecondary,
                ),
                suffixText: 'VND',
                filled: true,
                fillColor: AppColors.blue50.withOpacity(0.38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 24),

            _label('ƯU TIÊN GỢI Ý'),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _preferences.map(
                    (item) {
                  final selected =
                  _selectedPreferences.contains(item);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedPreferences.remove(item);
                        } else {
                          _selectedPreferences.add(item);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.blue500
                            : AppColors.blue50,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                },
              ).toList(),
            ),

            const SizedBox(height: 26),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.blue50.withOpacity(0.50),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 20,
                    color: AppColors.blue500,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sau khi tạo chuyến đi, bạn có thể thêm địa điểm thủ công. '
                          'Mỗi địa điểm đã chọn sẽ tạo ngữ cảnh để AI gợi ý điểm tiếp theo, '
                          'hoặc bạn có thể để AI hoàn thiện và sắp xếp lịch trình.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _createTrip,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: AppColors.blue500,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(27),
                  ),
                ),
                child: const Text(
                  'Tạo lịch trình',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 1,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.blue50.withOpacity(0.38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _coverPicker() {
    return Container(
      width: double.infinity,
      height: 118,
      decoration: BoxDecoration(
        color: AppColors.blue50.withOpacity(0.38),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            color: AppColors.blue300,
          ),
          SizedBox(height: 8),
          Text(
            'Thêm ảnh bìa',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendarRangePicker() {
    if (_dateRangeCompleted &&
        _startDate != null &&
        _endDate != null) {
      return _completedDateRangeCard();
    }

    final year = _calendarMonth.year;
    final month = _calendarMonth.month;

    final firstDay = DateTime(year, month, 1);
    final daysInMonth =
        DateTime(year, month + 1, 0).day;

    final leadingDays = firstDay.weekday % 7;
    final previousMonthLastDay =
        DateTime(year, month, 0).day;

    final totalCells =
        ((leadingDays + daysInMonth + 6) ~/ 7) * 7;

    final monthNames = const [
      'Tháng 1',
      'Tháng 2',
      'Tháng 3',
      'Tháng 4',
      'Tháng 5',
      'Tháng 6',
      'Tháng 7',
      'Tháng 8',
      'Tháng 9',
      'Tháng 10',
      'Tháng 11',
      'Tháng 12',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        12,
        14,
        12,
        16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.blue100.withOpacity(0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _calendarMonth = DateTime(
                      year,
                      month - 1,
                    );
                  });
                },
                icon: const Icon(
                  Icons.chevron_left_rounded,
                ),
              ),

              Expanded(
                child: Text(
                  '${monthNames[month - 1]} $year',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              IconButton(
                onPressed: () {
                  setState(() {
                    _calendarMonth = DateTime(
                      year,
                      month + 1,
                    );
                  });
                },
                icon: const Icon(
                  Icons.chevron_right_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

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

          const SizedBox(height: 8),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.08,
            ),
            itemBuilder: (context, index) {
              final dayOffset =
                  index - leadingDays + 1;

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
                date = DateTime(
                  year,
                  month,
                  dayOffset,
                );
              }

              return _calendarDay(
                date,
                currentMonth: currentMonth,
              );
            },
          ),

          const SizedBox(height: 12),

          if (_startDate == null)
            const Text(
              'Chọn ngày bắt đầu',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            )
          else if (_endDate == null)
            Text(
              'Bắt đầu ${_formatDate(_startDate!)} • Chọn ngày kết thúc',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            )
          else
            Text(
              '${_formatDate(_startDate!)} → ${_formatDate(_endDate!)} • $_days ngày',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _startDate != null &&
                  _endDate != null
                  ? _completeDateRange
                  : null,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.blue500,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.blue100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Hoàn tất',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _completedDateRangeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blue50.withOpacity(0.42),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.blue500,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ngày đã chọn',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDate(_startDate!)} → ${_formatDate(_endDate!)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blue500,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$_days ngày',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _dateRangeCompleted = false;
                });
              },
              icon: const Icon(
                Icons.edit_calendar_outlined,
                size: 18,
              ),
              label: const Text(
                'Chỉnh sửa ngày',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.blue500,
                side: const BorderSide(
                  color: AppColors.blue100,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _completeDateRange() {
    if (_startDate == null ||
        _endDate == null) {
      return;
    }

    setState(() {
      _days =
          _endDate!.difference(_startDate!).inDays + 1;
      _dateRangeCompleted = true;
    });
  }

  Widget _calendarDay(
      DateTime date, {
        required bool currentMonth,
      }) {
    final cleanDate =
    DateTime(date.year, date.month, date.day);

    final isStart =
        _startDate != null &&
            _isSameDate(cleanDate, _startDate!);

    final isEnd =
        _endDate != null &&
            _isSameDate(cleanDate, _endDate!);

    final inRange =
        _startDate != null &&
            _endDate != null &&
            cleanDate.isAfter(_startDate!) &&
            cleanDate.isBefore(_endDate!);

    final selected = isStart || isEnd;

    return InkWell(
      onTap: currentMonth
          ? () => _selectDate(cleanDate)
          : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.blue500
              : inRange
              ? AppColors.blue100
              : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(
              isStart ? 20 : 0,
            ),
            right: Radius.circular(
              isEnd ? 20 : 0,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected
                ? FontWeight.w800
                : FontWeight.w600,
            color: selected
                ? Colors.white
                : currentMonth
                ? AppColors.textPrimary
                : AppColors.textSecondary
                .withOpacity(0.35),
          ),
        ),
      ),
    );
  }

  void _selectDate(DateTime date) {
    setState(() {
      // Chưa có ngày đầu hoặc đã chọn đủ một khoảng:
      // bắt đầu khoảng mới.
      if (_startDate == null || _endDate != null) {
        _startDate = date;
        _endDate = null;
        _days = 1;
        _dateRangeCompleted = false;
        return;
      }

      // Nếu bấm ngày trước ngày đầu, đổi ngày đó thành ngày đầu mới.
      if (date.isBefore(_startDate!)) {
        _startDate = date;
        _endDate = null;
        _days = 1;
        return;
      }

      _endDate = date;

      _days =
          _endDate!.difference(_startDate!).inDays + 1;
    });
  }

  bool _isSameDate(
      DateTime a,
      DateTime b,
      ) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  void _createTrip() {
    final title = _nameController.text.trim();
    final destination = _destinationController.text.trim();

    if (title.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Hãy nhập tên chuyến đi và điểm đến chính.',
          ),
        ),
      );
      return;
    }

    if (_startDate == null ||
        _endDate == null ||
        !_dateRangeCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Hãy chọn ngày bắt đầu, ngày kết thúc và bấm Hoàn tất.',
          ),
        ),
      );
      return;
    }

    final trip = TripUi(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      days: _days,
      destination: destination,
      coverAsset: 'assets/images/home_dalat.jpg',
      isActive: true,
      isGroup: true,
    );

    Navigator.pop(context, trip);
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
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
