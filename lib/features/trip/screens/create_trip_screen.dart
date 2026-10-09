import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../../messages/data/message_repository.dart';
import '../models/trip_ui_models.dart';
import '../widgets/trip_shared_sheets.dart';

class CreateTripScreen extends StatefulWidget {
  final MessageRepository? messageRepository;

  const CreateTripScreen({
    super.key,
    this.messageRepository,
  });

  @override
  State<CreateTripScreen> createState() =>
      _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  late final MessageRepository _messageRepository;

  String _title = 'Lịch trình';
  bool _nameEdited = false;

  String _coverAsset = 'assets/images/home_dalat.jpg';

  /// Draft lời mời khi đang tạo trip.
  ///
  /// Chưa gửi notification ở thời điểm này.
  final Set<String> _pendingInviteIds = <String>{};

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();

    _messageRepository =
        widget.messageRepository ?? DemoMessageRepository.instance;
  }

  int get _days {
    if (_startDate == null || _endDate == null) {
      return 1;
    }

    return _endDate!.difference(_startDate!).inDays + 1;
  }

  Future<void> _editName() async {
    final value = await GoMateBottomSheet.show<String>(
      context: context,
      child: TripNameEditorContent(
        title: 'Chỉnh sửa tên lịch trình',
        initialValue: _title,
        hintText: 'Tên lịch trình...',
      ),
    );

    if (!mounted || value == null) return;

    setState(() {
      _title = value;
      _nameEdited =
          value.trim().isNotEmpty && value.trim() != 'Lịch trình';
    });
  }

  void _pickCover() {
    GoMateSnackBar.show(
      context,
      message: 'Chọn ảnh bìa sẽ được kết nối sau',
    );
  }

  Future<void> _addMembers() async {
    await GoMateBottomSheet.show<void>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      child: TripInviteMembersContent(
        contacts: _messageRepository.contacts,
        initialPendingInviteIds: _pendingInviteIds,
        acceptedMemberIds: <String>{
          _messageRepository.currentUserId,
        },
        onPendingChanged: (pending) {
          if (!mounted) return;

          setState(() {
            _pendingInviteIds
              ..clear()
              ..addAll(pending);
          });
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final result =
        await GoMateBottomSheet.show<TripDateRangeResult>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      child: TripDateRangeContent(
        initialStart: _startDate,
        initialEnd: _endDate,
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _startDate = result.startDate;
      _endDate = result.endDate;
    });
  }

  void _createTrip() {
    if (!_nameEdited) {
      GoMateSnackBar.show(
        context,
        message: 'Hãy đổi tên lịch trình trước khi tạo',
        icon: Icons.info_outline,
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      GoMateSnackBar.show(
        context,
        message: 'Hãy chọn ngày cho lịch trình trước khi tạo',
        icon: Icons.info_outline,
      );
      return;
    }

    final tripId =
        'trip_${DateTime.now().millisecondsSinceEpoch}';

    // QUAN TRỌNG:
    // Lời mời chưa được chấp nhận KHÔNG làm Trip trở thành group.
    //
    // Khi vừa tạo:
    // - accepted members = chỉ current user;
    // - isGroup = false;
    // - conversationId = null;
    // - pendingInviteIds = những người đã mời.
    //
    // Backend sau này:
    // - sau create mới dispatch notification;
    // - khi có người accept => add member;
    // - accepted member count > 1 => chuyển group + tạo group chat.
    final trip = TripUi(
      id: tripId,
      title: _title,
      days: _days,
      destination: 'Đang cập nhật',
      coverAsset: _coverAsset,
      isActive: false,
      isGroup: false,
      currentUserRole: TripAccessRole.personal,
      startDate: _startDate,
      endDate: _endDate,
      members: <TripMemberUi>[
        TripMemberUi(
          id: _messageRepository.currentUserId,
          name: _messageRepository.currentUserName,
          role: TripAccessRole.personal,
        ),
      ],
      pendingInviteIds: List<String>.unmodifiable(_pendingInviteIds),
      conversationId: null,
    );

    Navigator.of(context).pop(trip);
  }

  String _memberSubtitle() {
    if (_pendingInviteIds.isEmpty) {
      return '';
    }

    return '${_pendingInviteIds.length} lời mời đang chờ';
  }

  String _dateTitle() {
    if (_startDate == null || _endDate == null) {
      return 'Chọn ngày';
    }

    return '${_shortDate(_startDate!)} - ${_shortDate(_endDate!)}';
  }

  String _dateSubtitle() {
    if (_startDate == null || _endDate == null) {
      return '';
    }

    return '${_weekday(_startDate!)} - ${_weekday(_endDate!)}';
  }

  static String _shortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }

  static String _weekday(DateTime date) {
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

    return labels[date.weekday];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    double c(
      double value,
      double min,
      double max,
    ) {
      return value.clamp(min, max).toDouble();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                c(width * 0.075, 24, 30),
                c(width * 0.020, 6, 9),
                c(width * 0.075, 24, 30),
                c(width * 0.28, 100, 116),
              ),
              children: [
                _CreateHeader(
                  onBack: () => Navigator.of(context).pop(),
                ),

                SizedBox(
                  height: c(width * 0.035, 12, 15),
                ),

                Center(
                  child: InkWell(
                    onTap: _pickCover,
                    borderRadius: BorderRadius.circular(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        _coverAsset,
                        width: c(width * 0.20, 70, 78),
                        height: c(width * 0.20, 70, 78),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 75,
                          height: 75,
                          color: AppColors.grayBackground,
                          child: const Icon(
                            LucideIcons.image,
                            color: AppColors.grayText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  height: c(width * 0.025, 8, 11),
                ),

                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _title,
                        style: TextStyle(
                          fontSize: c(width * 0.043, 15, 17),
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(
                        width: c(width * 0.012, 4, 5),
                      ),
                      InkWell(
                        onTap: _editName,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: EdgeInsets.all(
                            c(width * 0.006, 2, 3),
                          ),
                          child: Icon(
                            LucideIcons.pencil,
                            size: c(width * 0.040, 14, 16),
                            color: AppColors.grayText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height: c(width * 0.040, 14, 17),
                ),

                _CreateMenuRow(
                  icon: LucideIcons.users_round,
                  title: 'Thêm thành viên',
                  subtitle: _memberSubtitle(),
                  onTap: _addMembers,
                ),

                _CreateMenuRow(
                  icon: LucideIcons.calendar,
                  title: _dateTitle(),
                  subtitle: _dateSubtitle(),
                  onTap: _pickDate,
                ),
              ],
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: c(width * 0.055, 18, 24),
              child: SafeArea(
                top: false,
                child: Center(
                  child: _CreateTripButton(
                    onTap: _createTrip,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _CreateHeader({
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final height =
        (width * 0.11).clamp(40.0, 44.0).toDouble();

    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'Tạo lịch trình',
            style: TextStyle(
              fontSize: (width * 0.043).clamp(15.0, 17.0).toDouble(),
              fontWeight: FontWeight.w800,
              color: AppColors.primaryText,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: onBack,
              customBorder: const CircleBorder(),
              child: SizedBox.square(
                dimension: height,
                child: Center(
                  child: Icon(
                    LucideIcons.chevron_left,
                    size: (width * 0.070).clamp(24.0, 28.0).toDouble(),
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateMenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CreateMenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final minHeight =
        (width * 0.145).clamp(52.0, 58.0).toDouble();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: minHeight,
        ),
        child: Row(
          children: [
            SizedBox(
              width: (width * 0.090).clamp(32.0, 38.0).toDouble(),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Icon(
                  icon,
                  size: (width * 0.062).clamp(22.0, 24.0).toDouble(),
                  color: Colors.black,
                ),
              ),
            ),
            SizedBox(width: width * 0.028),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize:
                          (width * 0.032).clamp(11.5, 12.5).toDouble(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    SizedBox(height: width * 0.004),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize:
                            (width * 0.027).clamp(9.5, 10.5).toDouble(),
                        color: AppColors.grayText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              LucideIcons.chevron_right,
              size: (width * 0.060).clamp(21.0, 24.0).toDouble(),
              color: AppColors.grayText,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateTripButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateTripButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final buttonWidth =
        (width * (160 / 375)).clamp(154.0, 166.0).toDouble();

    final height =
        (width * (45 / 375)).clamp(43.0, 47.0).toDouble();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: buttonWidth,
          height: height,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.elevatedShadow,
          ),
          child: Center(
            child: Text(
              'Tạo lịch trình',
              style: TextStyle(
                fontSize:
                    (width * (14 / 375)).clamp(13.0, 14.0).toDouble(),
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
