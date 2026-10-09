import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../../messages/data/message_repository.dart';
import '../../messages/models/message_models.dart';
import '../../messages/screens/chat_screen.dart';
import '../../messages/screens/group_management_screen.dart';
import '../../messages/widgets/message_widgets.dart';
import '../models/trip_ui_models.dart';
import '../widgets/trip_shared_sheets.dart';

class TripDetailScreen extends StatefulWidget {
  final TripUi trip;
  final MessageRepository? messageRepository;

  const TripDetailScreen({
    super.key,
    required this.trip,
    this.messageRepository,
  });

  @override
  State<TripDetailScreen> createState() =>
      _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late TripUi _trip;
  late final MessageRepository _messageRepository;

  @override
  void initState() {
    super.initState();

    _trip = widget.trip;
    _messageRepository =
        widget.messageRepository ?? DemoMessageRepository.instance;
  }

  Future<void> _editName() async {
    if (!_trip.canEditTrip) return;

    final value = await GoMateBottomSheet.show<String>(
      context: context,
      child: TripNameEditorContent(
        title: 'Chỉnh sửa tên lịch trình',
        initialValue: _trip.title,
        hintText: 'Tên lịch trình...',
      ),
    );

    if (!mounted || value == null) return;

    setState(() {
      _trip = _trip.copyWith(title: value);
    });

    final conversationId = _trip.conversationId;

    if (_trip.isGroup && conversationId != null) {
      _messageRepository.renameGroup(
        conversationId,
        value,
      );
    }
  }

  Future<void> _editDate() async {
    if (!_trip.canEditTrip) return;

    final result =
        await GoMateBottomSheet.show<TripDateRangeResult>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      child: TripDateRangeContent(
        initialStart: _trip.startDate,
        initialEnd: _trip.endDate,
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _trip = _trip.copyWith(
        startDate: result.startDate,
        endDate: result.endDate,
        days: result.days,
      );
    });
  }

  void _openChat() {
    final conversationId = _trip.conversationId;

    if (!_trip.hasChat || conversationId == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessageChatScreen(
          conversationId: conversationId,
          repository: _messageRepository,
        ),
      ),
    );
  }

  Future<void> _openMembers() async {
    final conversationId = _trip.conversationId;

    if (_trip.hasChat && conversationId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoleAwareGroupMembersScreen(
            conversationId: conversationId,
            repository: _messageRepository,
          ),
        ),
      );
      return;
    }

    // Trip vẫn là cá nhân: quản lý lời mời cục bộ trong module Trip.
    final pending = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => TripDraftMembersScreen(
          repository: _messageRepository,
          members: _trip.members,
          pendingInviteIds: _trip.pendingInviteIds.toSet(),
        ),
      ),
    );

    if (!mounted || pending == null) return;

    setState(() {
      _trip = _trip.copyWith(
        pendingInviteIds: List<String>.unmodifiable(pending),
      );
    });
  }

  void _openPlaceFlow() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripRoutePlaceholderScreen(
          title: _trip.canEditTrip
              ? 'Thêm địa điểm'
              : 'Xem lộ trình',
          canEdit: _trip.canEditTrip,
        ),
      ),
    );
  }

  Future<void> _openActions() async {
    final result =
        await GoMateBottomSheet.show<_TripDetailAction>(
      context: context,
      contentPadding: EdgeInsets.zero,
      child: _TripActionContent(
        trip: _trip,
      ),
    );

    if (!mounted || result == null) return;

    switch (result) {
      case _TripDetailAction.pin:
        setState(() {
          _trip = _trip.copyWith(isActive: true);
        });

        GoMateSnackBar.show(
          context,
          message: 'Đã ghim lịch trình',
        );
        break;

      case _TripDetailAction.unpin:
        setState(() {
          _trip = _trip.copyWith(isActive: false);
        });

        GoMateSnackBar.show(
          context,
          message: 'Đã bỏ ghim lịch trình',
        );
        break;

      case _TripDetailAction.delete:
        await _confirmDelete();
        break;

      case _TripDetailAction.leave:
        await _confirmLeave();
        break;
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await GoMateBottomSheet.show<bool>(
      context: context,
      child: MessageConfirmContent(
        title: 'Xoá lịch trình?',
        description: _trip.isGroup
            ? 'Xoá lịch trình nhóm đồng nghĩa với việc xoá đoạn chat nhóm. '
                'Hành động này không thể hoàn tác.'
            : 'Lịch trình này sẽ bị xoá vĩnh viễn. '
                'Hành động này không thể hoàn tác.',
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );

    if (!mounted || confirmed != true) return;

    final conversationId = _trip.conversationId;

    if (_trip.isGroup && conversationId != null) {
      _messageRepository.deleteGroupAndItinerary(
        conversationId,
      );
    }

    GoMateSnackBar.show(
      context,
      message: 'Đã xoá lịch trình',
    );

    Navigator.of(context).pop(
      TripDetailResult(
        trip: _trip,
        removeFromList: true,
      ),
    );
  }

  Future<void> _confirmLeave() async {
    final confirmed = await GoMateBottomSheet.show<bool>(
      context: context,
      child: MessageConfirmContent(
        title: 'Rời lịch trình?',
        description:
            'Rời lịch trình cũng đồng nghĩa với việc bạn rời đoạn chat nhóm.',
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );

    if (!mounted || confirmed != true) return;

    final conversationId = _trip.conversationId;

    if (conversationId != null) {
      _messageRepository.leaveGroup(
        conversationId,
      );
    }

    GoMateSnackBar.show(
      context,
      message: 'Đã rời lịch trình',
    );

    Navigator.of(context).pop(
      TripDetailResult(
        trip: _trip,
        removeFromList: true,
      ),
    );
  }

  void _close() {
    Navigator.of(context).pop(
      TripDetailResult(trip: _trip),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final memberSubtitle = _trip.pendingInviteIds.isEmpty
        ? '${_trip.memberCount} thành viên'
        : '${_trip.memberCount} thành viên • '
            '${_trip.pendingInviteIds.length} lời mời';

    return WillPopScope(
      onWillPop: () async {
        _close();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              (width * 0.075).clamp(24.0, 30.0).toDouble(),
              (width * 0.020).clamp(6.0, 9.0).toDouble(),
              (width * 0.075).clamp(24.0, 30.0).toDouble(),
              (width * 0.080).clamp(26.0, 34.0).toDouble(),
            ),
            children: [
              _DetailHeader(
                onBack: _close,
                onMore: _openActions,
              ),

              SizedBox(
                height: (width * 0.010).clamp(3.0, 5.0).toDouble(),
              ),

              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    _trip.coverAsset,
                    width: (width * 0.20).clamp(70.0, 78.0).toDouble(),
                    height: (width * 0.20).clamp(70.0, 78.0).toDouble(),
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

              SizedBox(
                height: (width * 0.020).clamp(7.0, 9.0).toDouble(),
              ),

              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _trip.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize:
                              (width * 0.043).clamp(15.0, 17.0).toDouble(),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_trip.canEditTrip) ...[
                      SizedBox(width: width * 0.012),
                      InkWell(
                        onTap: _editName,
                        child: Icon(
                          LucideIcons.pencil,
                          size:
                              (width * 0.040).clamp(14.0, 16.0).toDouble(),
                          color: AppColors.grayText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(
                height: (width * 0.045).clamp(16.0, 19.0).toDouble(),
              ),

              // Tin nhắn chỉ xuất hiện khi đã thật sự là group
              // VÀ đã có linked group chat.
              if (_trip.hasChat)
                _DetailRow(
                  icon: LucideIcons.message_circle,
                  title: 'Tin nhắn',
                  onTap: _openChat,
                ),

              // Thành viên luôn hiển thị:
              // personal = 1 accepted member + pending invites;
              // group = mở RoleAwareGroupMembersScreen.
              _DetailRow(
                icon: LucideIcons.users_round,
                title: 'Thành viên',
                subtitle: memberSubtitle,
                onTap: _openMembers,
              ),

              _DetailRow(
                icon: LucideIcons.calendar,
                title: _trip.dateRangeLabel,
                subtitle: _trip.weekdayRangeLabel,
                showChevron: _trip.canEditTrip,
                onTap: _trip.canEditTrip ? _editDate : null,
              ),

              _DetailRow(
                icon: _trip.canEditTrip
                    ? LucideIcons.plus
                    : Icons.route_outlined,
                title: _trip.canEditTrip
                    ? 'Thêm địa điểm'
                    : 'Xem lộ trình',
                onTap: _openPlaceFlow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TripDraftMembersScreen extends StatefulWidget {
  final MessageRepository repository;
  final List<TripMemberUi> members;
  final Set<String> pendingInviteIds;

  const TripDraftMembersScreen({
    super.key,
    required this.repository,
    required this.members,
    required this.pendingInviteIds,
  });

  @override
  State<TripDraftMembersScreen> createState() =>
      _TripDraftMembersScreenState();
}

class _TripDraftMembersScreenState
    extends State<TripDraftMembersScreen> {
  late final Set<String> _pending;

  @override
  void initState() {
    super.initState();
    _pending = <String>{...widget.pendingInviteIds};
  }

  Set<String> get _acceptedIds {
    return widget.members
        .where((member) => member.id.trim().isNotEmpty)
        .map((member) => member.id)
        .toSet();
  }

  MessageContact? _findContact(String id) {
    for (final contact in widget.repository.contacts) {
      if (contact.id == id) return contact;
    }
    return null;
  }

  Future<void> _invite() async {
    await GoMateBottomSheet.show<void>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      child: TripInviteMembersContent(
        contacts: widget.repository.contacts,
        initialPendingInviteIds: _pending,
        acceptedMemberIds: _acceptedIds,
        onPendingChanged: (value) {
          if (!mounted) return;

          setState(() {
            _pending
              ..clear()
              ..addAll(value);
          });
        },
      ),
    );
  }

  void _close() {
    Navigator.of(context).pop(
      Set<String>.unmodifiable(_pending),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return WillPopScope(
      onWillPop: () async {
        _close();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  (width * 0.060).clamp(20.0, 24.0).toDouble(),
                  6,
                  (width * 0.060).clamp(20.0, 24.0).toDouble(),
                  6,
                ),
                child: SizedBox(
                  height: (width * 0.115).clamp(42.0, 48.0).toDouble(),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        'Thành viên',
                        style: TextStyle(
                          fontSize:
                              (width * 0.043).clamp(15.0, 17.0).toDouble(),
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryText,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: _close,
                          customBorder: const CircleBorder(),
                          child: SizedBox.square(
                            dimension:
                                (width * 0.10).clamp(36.0, 42.0).toDouble(),
                            child: Center(
                              child: Icon(
                                LucideIcons.chevron_left,
                                size: (width * 0.068)
                                    .clamp(24.0, 27.0)
                                    .toDouble(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: _invite,
                          customBorder: const CircleBorder(),
                          child: SizedBox.square(
                            dimension:
                                (width * 0.10).clamp(36.0, 42.0).toDouble(),
                            child: Center(
                              child: Icon(
                                LucideIcons.plus,
                                size: (width * 0.065)
                                    .clamp(23.0, 26.0)
                                    .toDouble(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    (width * 0.080).clamp(26.0, 32.0).toDouble(),
                    8,
                    (width * 0.080).clamp(26.0, 32.0).toDouble(),
                    28,
                  ),
                  children: [
                    for (final member in widget.members)
                      _DraftMemberRow(
                        name: member.name,
                        subtitle: member.subtitle,
                        avatarAsset: member.avatarAsset,
                        trailingText: member.id ==
                                widget.repository.currentUserId
                            ? 'Bạn'
                            : '',
                      ),

                    if (_pending.isNotEmpty) ...[
                      SizedBox(
                        height:
                            (width * 0.035).clamp(12.0, 15.0).toDouble(),
                      ),
                      Text(
                        'Lời mời đang chờ',
                        style: TextStyle(
                          fontSize:
                              (width * 0.030).clamp(11.0, 12.0).toDouble(),
                          fontWeight: FontWeight.w700,
                          color: AppColors.grayText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final id in _pending)
                        if (_findContact(id) case final contact?)
                          _DraftMemberRow(
                            name: contact.name,
                            subtitle: contact.subtitle,
                            avatarAsset: contact.avatarAsset ?? '',
                            trailingText: 'Đang chờ',
                          ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftMemberRow extends StatelessWidget {
  final String name;
  final String subtitle;
  final String avatarAsset;
  final String trailingText;

  const _DraftMemberRow({
    required this.name,
    required this.subtitle,
    required this.avatarAsset,
    required this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final avatar = (width * 0.095).clamp(34.0, 40.0).toDouble();

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: (width * 0.018).clamp(6.0, 8.0).toDouble(),
      ),
      child: Row(
        children: [
          Container(
            width: avatar,
            height: avatar,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x1A0A43A8),
              border: Border.all(color: AppColors.grayBorder),
            ),
            child: avatarAsset.trim().isEmpty
                ? Icon(
                    LucideIcons.user_round,
                    size: avatar * 0.55,
                    color: Colors.white,
                  )
                : Image.asset(
                    avatarAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      LucideIcons.user_round,
                      size: avatar * 0.55,
                      color: Colors.white,
                    ),
                  ),
          ),
          SizedBox(width: width * 0.030),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: (width * 0.032)
                        .clamp(11.5, 12.5)
                        .toDouble(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.trim().isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: (width * 0.027)
                          .clamp(9.5, 10.5)
                          .toDouble(),
                      color: AppColors.grayText,
                    ),
                  ),
              ],
            ),
          ),
          if (trailingText.isNotEmpty)
            Text(
              trailingText,
              style: TextStyle(
                fontSize:
                    (width * 0.026).clamp(9.5, 10.5).toDouble(),
                fontWeight: FontWeight.w600,
                color: trailingText == 'Đang chờ'
                    ? AppColors.primaryText
                    : AppColors.grayText,
              ),
            ),
        ],
      ),
    );
  }
}

enum _TripDetailAction {
  pin,
  unpin,
  delete,
  leave,
}

class _TripActionContent extends StatelessWidget {
  final TripUi trip;

  const _TripActionContent({
    required this.trip,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        (width * 0.075).clamp(24.0, 30.0).toDouble(),
        0,
        (width * 0.075).clamp(24.0, 30.0).toDouble(),
        (width * 0.050).clamp(18.0, 22.0).toDouble(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionRow(
            icon: trip.isActive
                ? LucideIcons.pin_off
                : LucideIcons.pin,
            label: trip.isActive
                ? 'Bỏ ghim lịch trình'
                : 'Ghim lịch trình',
            onTap: () => Navigator.of(context).pop(
              trip.isActive
                  ? _TripDetailAction.unpin
                  : _TripDetailAction.pin,
            ),
          ),

          const Divider(
            color: AppColors.grayBorder,
          ),

          if (trip.canDeleteTrip)
            _ActionRow(
              icon: LucideIcons.trash,
              label: 'Xoá lịch trình',
              color: AppColors.primaryText,
              onTap: () => Navigator.of(context).pop(
                _TripDetailAction.delete,
              ),
            )
          else if (trip.canLeaveTrip)
            _ActionRow(
              icon: LucideIcons.log_out,
              label: 'Rời lịch trình',
              color: AppColors.primaryText,
              onTap: () => Navigator.of(context).pop(
                _TripDetailAction.leave,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: (width * 0.13).clamp(48.0, 54.0).toDouble(),
        child: Row(
          children: [
            Icon(
              icon,
              size: (width * 0.060).clamp(21.0, 24.0).toDouble(),
              color: color,
            ),
            SizedBox(
              width: (width * 0.045).clamp(15.0, 18.0).toDouble(),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize:
                    (width * 0.032).clamp(11.5, 12.5).toDouble(),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onMore;

  const _DetailHeader({
    required this.onBack,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final height =
        (width * 0.11).clamp(40.0, 44.0).toDouble();

    return SizedBox(
      height: height,
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: height,
              child: Center(
                child: Icon(
                  LucideIcons.chevron_left,
                  size:
                      (width * 0.070).clamp(24.0, 28.0).toDouble(),
                ),
              ),
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: onMore,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: height,
              child: Center(
                child: Icon(
                  LucideIcons.ellipsis_vertical,
                  size:
                      (width * 0.060).clamp(21.0, 24.0).toDouble(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle = '',
    this.showChevron = true,
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
              width:
                  (width * 0.090).clamp(32.0, 38.0).toDouble(),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Icon(
                  icon,
                  size:
                      (width * 0.062).clamp(22.0, 24.0).toDouble(),
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
            if (showChevron)
              Icon(
                LucideIcons.chevron_right,
                size:
                    (width * 0.060).clamp(21.0, 24.0).toDouble(),
                color: AppColors.grayText,
              ),
          ],
        ),
      ),
    );
  }
}

class TripRoutePlaceholderScreen extends StatelessWidget {
  final String title;
  final bool canEdit;

  const TripRoutePlaceholderScreen({
    super.key,
    required this.title,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                (width * 0.065).clamp(22.0, 26.0).toDouble(),
                8,
                (width * 0.065).clamp(22.0, 26.0).toDouble(),
                12,
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(
                      LucideIcons.chevron_left,
                      size:
                          (width * 0.070).clamp(24.0, 28.0).toDouble(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize:
                            (width * 0.043).clamp(15.0, 17.0).toDouble(),
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  SizedBox(
                    width:
                        (width * 0.070).clamp(24.0, 28.0).toDouble(),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Icon(
              canEdit
                  ? LucideIcons.plus
                  : Icons.route_outlined,
              size: 42,
              color: AppColors.grayText,
            ),
            const SizedBox(height: 12),
            Text(
              canEdit
                  ? 'Trang thêm địa điểm sẽ phát triển ở bước sau'
                  : 'Trang xem lộ trình sẽ phát triển ở bước sau',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.grayText,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
