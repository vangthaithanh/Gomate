import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/trip_ui_models.dart';

class AddPlaceBottomSheet extends StatefulWidget {
  final int day;
  final TripPlaceUi? initialPlace;

  const AddPlaceBottomSheet({
    super.key,
    required this.day,
    this.initialPlace,
  });

  @override
  State<AddPlaceBottomSheet> createState() => _AddPlaceBottomSheetState();
}

class _AddPlaceBottomSheetState extends State<AddPlaceBottomSheet> {
  final TextEditingController _searchController = TextEditingController();

  int _tab = 0;
  String? _selectedPlace;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<String> _mapSuggestions = const [
    'Hồ Xuân Hương',
    'Quảng trường Lâm Viên',
    'Vườn hoa thành phố Đà Lạt',
    'Dinh Bảo Đại',
    'Đồi chè Cầu Đất',
  ];

  final List<String> _favorites = const [
    'Tiệm cà phê Túi Mơ To',
    'Ga Đà Lạt',
    'Chợ Đà Lạt',
  ];

  @override
  void initState() {
    super.initState();

    if (widget.initialPlace != null) {
      final item = widget.initialPlace!;
      _selectedPlace = item.name;
      _searchController.text = item.name;
      _startTime = _parseTime(item.startTime);
      _endTime = _parseTime(item.endTime);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;

    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _formatTime(TimeOfDay? value) {
    if (value == null) return '--:--';

    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.blue100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.initialPlace == null
                                ? 'Thêm địa điểm mới'
                                : 'Sửa địa điểm',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Ngày ${widget.day}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                _buildTabSelector(),

                const SizedBox(height: 18),

                if (_tab == 0) ...[
                  const Text(
                    'Tìm và chọn địa điểm',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 9),

                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'VD: Hồ Xuân Hương...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.blue50.withOpacity(0.45),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  _buildPlaceChoices(_mapSuggestions),
                ] else ...[
                  const Text(
                    'Địa điểm đã lưu',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildPlaceChoices(_favorites),
                ],

                const SizedBox(height: 20),

                const Text(
                  'Thời gian',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _timeBox(
                        label: 'Giờ bắt đầu',
                        value: _startTime,
                        onTap: () => _pickTime(true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _timeBox(
                        label: 'Giờ kết thúc',
                        value: _endTime,
                        onTap: () => _pickTime(false),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.blue500,
                      disabledBackgroundColor:
                          AppColors.blue100.withOpacity(0.55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: Text(
                      widget.initialPlace == null
                          ? 'Thêm địa điểm'
                          : 'Lưu thay đổi',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _canSubmit {
    return _selectedPlace != null &&
        _startTime != null &&
        _endTime != null;
  }

  Widget _buildTabSelector() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.blue50.withOpacity(0.50),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _tabButton(
            index: 0,
            icon: Icons.search_rounded,
            text: 'Tìm bản đồ',
          ),
          _tabButton(
            index: 1,
            icon: Icons.bookmark_border_rounded,
            text: 'Đã lưu',
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required int index,
    required IconData icon,
    required String text,
  }) {
    final active = _tab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: active
                    ? AppColors.blue500
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceChoices(List<String> source) {
    final query = _searchController.text.trim().toLowerCase();

    final items = _tab == 0 && query.isNotEmpty
        ? source
            .where((e) => e.toLowerCase().contains(query))
            .toList()
        : source;

    return Column(
      children: items.map((name) {
        final selected = _selectedPlace == name;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedPlace = name;
                _searchController.text = name;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.blue50
                    : const Color(0xFFF8FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? AppColors.blue300
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.place_outlined,
                      size: 20,
                      color: AppColors.blue500,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: AppColors.blue500,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _timeBox({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 7),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: AppColors.blue50.withOpacity(0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: AppColors.blue500,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(value),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: value == null
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start
          ? (_startTime ?? const TimeOfDay(hour: 8, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 9, minute: 30)),
    );

    if (picked == null) return;

    setState(() {
      if (start) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  void _submit() {
    Navigator.pop(
      context,
      TripPlaceUi(
        name: _selectedPlace!,
        startTime: _formatTime(_startTime),
        endTime: _formatTime(_endTime),
        day: widget.day,
      ),
    );
  }
}
