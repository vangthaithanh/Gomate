import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../../messages/data/message_repository.dart';
import '../../messages/models/message_models.dart';
import '../../messages/screens/chat_screen.dart';
import '../../messages/screens/group_management_screen.dart';
import '../../messages/widgets/message_widgets.dart';
import '../../map/state/map_ui_session.dart';
import '../../map/services/location_service.dart';
import '../data/trip_repository.dart';
import '../location/trip_location_publishing_service.dart';
import '../models/trip_ui_models.dart';
import '../widgets/trip_shared_sheets.dart';
import '../../../core/widgets/gomate_name_editor_content.dart';

class TripDetailScreen extends StatefulWidget {
  final TripUi trip;
  final MessageRepository? messageRepository;
  final RealTripRepository? tripRepository;

  const TripDetailScreen({
    super.key,
    required this.trip,
    this.messageRepository,
    this.tripRepository,
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with WidgetsBindingObserver {
  late TripUi _trip;
  late final MessageRepository _messageRepository;
  late final RealTripRepository _tripRepository;
  final GoMateLocationService _locationService = GoMateLocationService();
  bool _leaving = false;

  @override
  void initState() {
    super.initState();

    _trip = widget.trip;
    _messageRepository =
        widget.messageRepository ?? RealDirectMessageRepository.instance;
    _tripRepository = widget.tripRepository ?? RealTripRepository.instance;
    WidgetsBinding.instance.addObserver(this);
    GoMateMapUiSession.revision.addListener(_onSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        TripLocationPublishingService.instance.enterTripDetail(_trip.id);
        unawaited(_refreshTrip());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_refreshTrip());
    }
  }

  @override
  void dispose() {
    TripLocationPublishingService.instance.leaveTripDetail(_trip.id);
    GoMateMapUiSession.revision.removeListener(_onSessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onSessionChanged() {
    final latest = GoMateMapUiSession.tripById(_trip.id);
    if (mounted && latest != null && !identical(latest, _trip)) {
      setState(() => _trip = latest);
    }
  }

  Future<void> _refreshTrip() async {
    try {
      final latest = await _tripRepository.detail(_trip.id);
      if (!mounted || _leaving) return;
      GoMateMapUiSession.updateTrip(latest);
      setState(() {
        _trip = GoMateMapUiSession.tripById(latest.id) ?? latest;
      });
    } catch (error) {
      if (mounted &&
          error is ApiException &&
          (error.status == 403 || error.status == 404)) {
        _messageRepository.forgetTripMembership(_trip.id);
        GoMateMapUiSession.removeTrip(_trip.id);
        Navigator.of(
          context,
        ).pop(TripDetailResult(trip: _trip, removeFromList: true));
      }
      // Detail refresh is best-effort after returning from chat.
    }
  }

  Future<void> _editName() async {
    if (!_trip.canEditTrip) return;

    final value = await GoMateBottomSheet.show<String>(
      context: context,
      child: GoMateNameEditorContent(
        title: 'Chỉnh sửa tên lịch trình',
        initialValue: _trip.title,
        hintText: 'Tên lịch trình...',
      ),
    );

    if (!mounted || value == null) return;

    try {
      final updated = await _tripRepository.update(_trip.id, title: value);
      if (!mounted) return;
      setState(() {
        _trip = updated.copyWith(isActive: _trip.isActive);
      });

      GoMateMapUiSession.updateTrip(_trip);
      await _messageRepository.refresh();
    } catch (error) {
      if (!mounted) return;
      GoMateSnackBar.show(
        context,
        message: error.toString(),
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _editDate() async {
    if (!_trip.canEditTrip) return;

    try {
      final clock = await _tripRepository.planningContext(_trip.timezone);
      if (!mounted) return;
      final result = await GoMateBottomSheet.show<TripDateRangeResult>(
        context: context,
        size: GoMateBottomSheetSize.expanded,
        child: TripDateRangeContent(
          initialStart: _trip.startDate,
          initialEnd: _trip.endDate,
          minimumDate: clock.today,
          currentDate: () => clock.today,
        ),
      );

      if (!mounted || result == null) return;

      try {
        final updated = await _tripRepository.update(
          _trip.id,
          startDate: result.startDate,
          endDate: result.endDate,
        );
        if (!mounted) return;
        setState(() {
          _trip = updated.copyWith(isActive: _trip.isActive);
        });
        GoMateMapUiSession.updateTrip(_trip);
      } catch (error) {
        if (!mounted) return;
        GoMateSnackBar.show(
          context,
          message: error.toString(),
          icon: Icons.error_outline,
        );
      }
    } catch (error) {
      if (mounted) {
        GoMateSnackBar.show(
          context,
          message: error.toString(),
          icon: Icons.error_outline,
        );
      }
    }
  }

  Future<void> _openChat() async {
    final conversationId = _trip.conversationId;

    if (!_trip.hasChat || conversationId == null) {
      return;
    }

    await _messageRepository.refresh();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessageChatScreen(
          conversationId: conversationId,
          repository: _messageRepository,
        ),
      ),
    );

    await _messageRepository.refresh();
    await _refreshTrip();
  }

  Future<void> _openMembers() async {
    final conversationId = _trip.conversationId;

    if (_trip.hasChat && conversationId != null) {
      await _messageRepository.refresh();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RoleAwareGroupMembersScreen(
            conversationId: conversationId,
            repository: _messageRepository,
          ),
        ),
      );
      await _refreshTrip();
      return;
    }

    // PERSONAL remains personal while invitations are pending. Acceptance on
    // the server creates the membership and linked group conversation.
    final updated = await Navigator.of(context).push<TripUi>(
      MaterialPageRoute(
        builder: (_) => TripDraftMembersScreen(
          repository: _messageRepository,
          tripRepository: _tripRepository,
          trip: _trip,
          members: _trip.members,
        ),
      ),
    );

    if (!mounted || updated == null) return;

    setState(() {
      _trip = updated.copyWith(isActive: _trip.isActive);
    });
    GoMateMapUiSession.updateTrip(_trip);
    await _messageRepository.refresh();
  }

  void _openPlaceFlow() {
    // Cả "Thêm địa điểm" và "Xem lộ trình" đều mở Map
    // đúng lịch trình và bung lộ trình ngày.
    //
    // Quan trọng với luồng Message -> TripDetail:
    // MessageDetail là một route nằm trên MainShell. Nếu chỉ pop TripDetail
    // thì người dùng vẫn bị giữ ở MessageDetail, nên Map phía dưới không hiện.
    // Vì vậy request tab Map trước rồi đóng toàn bộ các route detail về MainShell.
    GoMateMapUiSession.updateTrip(_trip);

    GoMateMapUiSession.requestOpenTripOnMap(
      _trip,
      day: 1,
      expandDayRoute: true,
    );

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openActions() async {
    final result = await GoMateBottomSheet.show<_TripDetailAction>(
      context: context,
      contentPadding: EdgeInsets.zero,
      child: _TripActionContent(trip: _trip),
    );

    if (!mounted || result == null) return;

    switch (result) {
      case _TripDetailAction.pin:
        await _pin();
        break;

      case _TripDetailAction.unpin:
        await _unpin();
        break;

      case _TripDetailAction.delete:
        await _confirmDelete();
        break;

      case _TripDetailAction.leave:
        await _confirmLeave();
        break;
    }
  }

  Future<void> _pin() async {
    if (_leaving) return;
    final selectionId = GoMateMapUiSession.displayedTrip?.id;
    final permission = await _locationService.ensureAlwaysForPinnedTrip();
    if (!mounted) return;

    if (permission.state != GoMateLocationState.ready) {
      await _handlePinPermissionBlock(permission.state);
      return;
    }

    try {
      final pinned = await _tripRepository.pin(_trip.id);
      GoMateMapUiSession.pinTrip(
        pinned,
        selectOnMap: GoMateMapUiSession.displayedTrip?.id == selectionId,
      );
      if (!mounted) return;
      setState(() {
        _trip = pinned;
      });
      GoMateMapUiSession.updateTrip(_trip);
      GoMateSnackBar.show(context, message: 'Đã ghim lịch trình');
    } catch (error) {
      if (!mounted) return;
      GoMateSnackBar.show(
        context,
        message: error.toString(),
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _unpin() async {
    try {
      await _tripRepository.unpin(_trip.id);
      if (!mounted) return;
      setState(() {
        _trip = _trip.copyWith(isActive: false);
      });
      GoMateMapUiSession.updateTrip(_trip);
      GoMateMapUiSession.clearPinnedTrip(tripId: _trip.id);
      GoMateSnackBar.show(context, message: 'Đã bỏ ghim lịch trình');
    } catch (error) {
      if (!mounted) return;
      GoMateSnackBar.show(
        context,
        message: error.toString(),
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _handlePinPermissionBlock(GoMateLocationState state) async {
    switch (state) {
      case GoMateLocationState.serviceOff:
        GoMateSnackBar.show(
          context,
          message: 'Hãy bật dịch vụ vị trí trước khi ghim lịch trình.',
          icon: Icons.location_off_outlined,
        );
        await _locationService.openLocationSettings();
        break;
      case GoMateLocationState.whileInUseOnly:
        GoMateSnackBar.show(
          context,
          message: 'Ghim lịch trình cần quyền vị trí Luôn cho phép.',
          icon: Icons.location_on_outlined,
        );
        await _locationService.openAppSettings();
        break;
      case GoMateLocationState.permissionDeniedForever:
        GoMateSnackBar.show(
          context,
          message:
              'Quyền vị trí đã bị chặn. Hãy bật Luôn cho phép trong Settings.',
          icon: Icons.location_off_outlined,
        );
        await _locationService.openAppSettings();
        break;
      case GoMateLocationState.permissionDenied:
        GoMateSnackBar.show(
          context,
          message: 'GoMate cần quyền vị trí Luôn cho phép để ghim lịch trình.',
          icon: Icons.location_off_outlined,
        );
        break;
      case GoMateLocationState.ready:
        break;
    }
  }

  Future<void> _confirmDelete() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    bool didConfirm = false;
    try {
      final confirmed = await GoMateBottomSheet.show<bool>(
        context: context,
        child: MessageConfirmContent(
          title: 'Xoá lịch trình?',
          description:
              'Lịch trình sẽ ngừng hoạt động và được gỡ khỏi danh sách. Lịch sử được giữ lại.',
          onConfirm: () {
            if (didConfirm) return;
            didConfirm = true;
            Navigator.of(context).pop(true);
          },
        ),
      );

      if (!mounted || confirmed != true) return;

      await _tripRepository.delete(_trip.id);
      _messageRepository.forgetTripMembership(_trip.id);
      GoMateMapUiSession.removeTrip(_trip.id);
      await _messageRepository.refresh();

      if (!mounted) return;
      GoMateSnackBar.show(context, message: 'Đã xoá lịch trình');

      Navigator.of(
        context,
      ).pop(TripDetailResult(trip: _trip, removeFromList: true));
    } catch (error) {
      if (!mounted) return;
      GoMateSnackBar.show(
        context,
        message: error.toString(),
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  Future<void> _confirmLeave() async {
    if (_leaving || !_trip.canLeaveTrip) return;
    setState(() => _leaving = true);
    bool didConfirm = false;
    try {
      final confirmed = await GoMateBottomSheet.show<bool>(
        context: context,
        child: MessageConfirmContent(
          title: 'Rời lịch trình?',
          description:
              'Rời lịch trình cũng đồng nghĩa với việc bạn rời đoạn chat nhóm.',
          onConfirm: () {
            if (didConfirm) return;
            didConfirm = true;
            Navigator.of(context).pop(true);
          },
        ),
      );

      if (!mounted || confirmed != true) return;

      await _tripRepository.leave(_trip.id);
      _messageRepository.forgetTripMembership(_trip.id);
      GoMateMapUiSession.removeTrip(_trip.id);
      await _messageRepository.refresh();
      if (!mounted) return;
      GoMateSnackBar.show(context, message: 'Đã rời lịch trình');
      Navigator.of(
        context,
      ).pop(TripDetailResult(trip: _trip, removeFromList: true));
    } catch (error) {
      if (mounted) {
        GoMateSnackBar.show(
          context,
          message: 'Không thể rời lịch trình: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  void _close() {
    GoMateMapUiSession.updateTrip(_trip);

    Navigator.of(context).pop(TripDetailResult(trip: _trip));
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
                onMore: _leaving ? null : _openActions,
              ),

              SizedBox(height: (width * 0.010).clamp(3.0, 5.0).toDouble()),

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

              SizedBox(height: (width * 0.020).clamp(7.0, 9.0).toDouble()),

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
                          fontSize: (width * 0.043)
                              .clamp(15.0, 17.0)
                              .toDouble(),
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
                          size: (width * 0.040).clamp(14.0, 16.0).toDouble(),
                          color: AppColors.grayText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: (width * 0.045).clamp(16.0, 19.0).toDouble()),

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
                title: _trip.canEditTrip ? 'Thêm địa điểm' : 'Xem lộ trình',
                onTap: _openPlaceFlow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Despite the legacy name, this screen manages an already persisted Trip.
class TripDraftMembersScreen extends StatefulWidget {
  final MessageRepository repository;
  final RealTripRepository tripRepository;
  final TripUi trip;
  final List<TripMemberUi> members;

  const TripDraftMembersScreen({
    super.key,
    required this.repository,
    required this.tripRepository,
    required this.trip,
    required this.members,
  });

  @override
  State<TripDraftMembersScreen> createState() => _TripDraftMembersScreenState();
}

class _TripDraftMembersScreenState extends State<TripDraftMembersScreen> {
  late TripUi _trip;
  bool _submitting = false;
  String? _cancellingId;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    GoMateMapUiSession.revision.addListener(_onTripChanged);
  }

  void _onTripChanged() {
    final latest = GoMateMapUiSession.tripById(_trip.id);
    if (mounted && latest != null && !identical(latest, _trip)) {
      setState(() => _trip = latest);
    }
  }

  @override
  void dispose() {
    GoMateMapUiSession.revision.removeListener(_onTripChanged);
    super.dispose();
  }

  Set<String> get _acceptedIds {
    return _trip.members
        .where((member) => member.id.trim().isNotEmpty)
        .map((member) => member.id)
        .toSet();
  }

  MessageContact? _findContact(String id) {
    for (final invitee in _trip.pendingInvitees) {
      if (invitee.id == id) {
        return MessageContact(
          id: id,
          name: invitee.name,
          subtitle: '',
          avatarAsset: invitee.avatarAsset,
        );
      }
    }
    for (final contact in widget.repository.contacts) {
      if (contact.id == id) return contact;
    }
    return null;
  }

  Future<void> _invite() async {
    if (_submitting || !_trip.canEditTrip) return;
    await GoMateBottomSheet.show<void>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      child: TripInviteMembersContent(
        contacts: widget.repository.contacts,
        initialPendingInviteIds: _trip.pendingInviteIds.toSet(),
        acceptedMemberIds: _acceptedIds,
        searchContacts: widget.tripRepository.searchMemberCandidates,
        onSendInvites: _sendInvitations,
      ),
    );
  }

  Future<void> _sendInvitations(Set<String> ids) async {
    if (_submitting) throw StateError('Đang gửi lời mời.');
    setState(() {
      _submitting = true;
    });
    try {
      final updated = await widget.tripRepository.addMembers(_trip.id, ids);
      if (!mounted) return;
      setState(() => _trip = updated.copyWith(isActive: _trip.isActive));
      GoMateMapUiSession.updateTrip(_trip);
      GoMateSnackBar.show(
        context,
        message: 'Đã gửi ${ids.length} lời mời tham gia lịch trình',
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _close() {
    if (_submitting) return;
    Navigator.of(context).pop(_trip);
  }

  Future<void> _cancelInvitation(String contactId) async {
    if (_submitting) return;
    final invitee = _trip.pendingInvitees
        .where((person) => person.id == contactId)
        .firstOrNull;
    final invitationId = invitee?.invitationId;
    if (invitationId == null || invitationId.isEmpty) {
      GoMateSnackBar.show(context, message: 'Không tìm thấy lời mời đang chờ.');
      return;
    }
    setState(() {
      _submitting = true;
      _cancellingId = contactId;
    });
    try {
      final updated = await widget.tripRepository.cancelInvitation(
        _trip.id,
        invitationId,
      );
      if (!mounted) return;
      setState(() => _trip = updated.copyWith(isActive: _trip.isActive));
      GoMateMapUiSession.updateTrip(_trip);
      GoMateSnackBar.show(context, message: 'Đã hủy lời mời');
    } catch (error) {
      if (mounted) {
        GoMateSnackBar.show(context, message: 'Không thể hủy lời mời: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _cancellingId = null;
        });
      }
    }
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
                          fontSize: (width * 0.043)
                              .clamp(15.0, 17.0)
                              .toDouble(),
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
                            dimension: (width * 0.10)
                                .clamp(36.0, 42.0)
                                .toDouble(),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_trip.canEditTrip)
                              InkWell(
                                onTap: _submitting ? null : _invite,
                                customBorder: const CircleBorder(),
                                child: SizedBox.square(
                                  dimension: (width * 0.10)
                                      .clamp(36.0, 42.0)
                                      .toDouble(),
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
                          ],
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
                    for (final member in _trip.members)
                      _DraftMemberRow(
                        name: member.name,
                        subtitle: member.subtitle,
                        avatarAsset: member.avatarAsset,
                        trailingText:
                            member.id == widget.repository.currentUserId
                            ? 'Bạn'
                            : '',
                      ),

                    if (_trip.pendingInviteIds.isNotEmpty) ...[
                      SizedBox(
                        height: (width * 0.035).clamp(12.0, 15.0).toDouble(),
                      ),
                      Text(
                        'Lời mời đang chờ',
                        style: TextStyle(
                          fontSize: (width * 0.030)
                              .clamp(11.0, 12.0)
                              .toDouble(),
                          fontWeight: FontWeight.w700,
                          color: AppColors.grayText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final id in _trip.pendingInviteIds)
                        if (_findContact(id) case final contact?)
                          _DraftMemberRow(
                            name: contact.name,
                            subtitle: contact.subtitle,
                            avatarAsset: contact.avatarAsset ?? '',
                            trailingText: '',
                            trailingAction: _trip.canEditTrip
                                ? SizedBox(
                                    width: 100,
                                    child: TextButton(
                                      key: ValueKey('cancel-invite-$id'),
                                      onPressed: _submitting
                                          ? null
                                          : () => _cancelInvitation(id),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.primaryText,
                                        minimumSize: const Size(0, 32),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: _cancellingId == id
                                          ? const SizedBox.square(
                                              dimension: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'Huỷ lời mời',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                    ),
                                  )
                                : null,
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
  final Widget? trailingAction;

  const _DraftMemberRow({
    required this.name,
    required this.subtitle,
    required this.avatarAsset,
    required this.trailingText,
    this.trailingAction,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final avatar = (width * 0.095).clamp(34.0, 40.0).toDouble();
    final avatarValue = avatarAsset.trim();
    final isNetworkAvatar =
        avatarValue.startsWith('http://') || avatarValue.startsWith('https://');

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
            child: avatarValue.isEmpty
                ? Icon(
                    LucideIcons.user_round,
                    size: avatar * 0.55,
                    color: Colors.white,
                  )
                : isNetworkAvatar
                ? Image.network(
                    avatarValue,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      LucideIcons.user_round,
                      size: avatar * 0.55,
                      color: Colors.white,
                    ),
                  )
                : Image.asset(
                    avatarValue,
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
                    fontSize: (width * 0.032).clamp(11.5, 12.5).toDouble(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.trim().isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: (width * 0.027).clamp(9.5, 10.5).toDouble(),
                      color: AppColors.grayText,
                    ),
                  ),
              ],
            ),
          ),
          if (trailingAction != null)
            trailingAction!
          else if (trailingText.isNotEmpty)
            Text(
              trailingText,
              style: TextStyle(
                fontSize: (width * 0.026).clamp(9.5, 10.5).toDouble(),
                fontWeight: FontWeight.w600,
                color: AppColors.grayText,
              ),
            ),
        ],
      ),
    );
  }
}

enum _TripDetailAction { pin, unpin, delete, leave }

class _TripActionContent extends StatelessWidget {
  final TripUi trip;

  const _TripActionContent({required this.trip});

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
            icon: trip.isActive ? LucideIcons.pin_off : LucideIcons.pin,
            label: trip.isActive ? 'Bỏ ghim lịch trình' : 'Ghim lịch trình',
            onTap: () => Navigator.of(context).pop(
              trip.isActive ? _TripDetailAction.unpin : _TripDetailAction.pin,
            ),
          ),

          const Divider(color: AppColors.grayBorder),

          if (trip.canDeleteTrip)
            _ActionRow(
              icon: LucideIcons.trash,
              label: 'Xoá lịch trình',
              color: AppColors.primaryText,
              onTap: () => Navigator.of(context).pop(_TripDetailAction.delete),
            )
          else if (trip.canLeaveTrip)
            _ActionRow(
              icon: LucideIcons.log_out,
              label: 'Rời lịch trình',
              color: AppColors.primaryText,
              onTap: () => Navigator.of(context).pop(_TripDetailAction.leave),
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
            SizedBox(width: (width * 0.045).clamp(15.0, 18.0).toDouble()),
            Text(
              label,
              style: TextStyle(
                fontSize: (width * 0.032).clamp(11.5, 12.5).toDouble(),
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
  final VoidCallback? onMore;

  const _DetailHeader({required this.onBack, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final height = (width * 0.11).clamp(40.0, 44.0).toDouble();

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
                  size: (width * 0.070).clamp(24.0, 28.0).toDouble(),
                ),
              ),
            ),
          ),
          const Spacer(),
          if (onMore != null)
            InkWell(
              onTap: onMore,
              customBorder: const CircleBorder(),
              child: SizedBox.square(
                dimension: height,
                child: Center(
                  child: Icon(
                    LucideIcons.ellipsis_vertical,
                    size: (width * 0.060).clamp(21.0, 24.0).toDouble(),
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

    final minHeight = (width * 0.145).clamp(52.0, 58.0).toDouble();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Row(
          children: [
            SizedBox(
              width: (width * 0.090).clamp(32.0, 38.0).toDouble(),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Icon(
                  icon,
                  size: (width * 0.062).clamp(22.0, 24.0).toDouble(),
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
                      fontSize: (width * 0.032).clamp(11.5, 12.5).toDouble(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    SizedBox(height: width * 0.004),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: (width * 0.027).clamp(9.5, 10.5).toDouble(),
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
                size: (width * 0.060).clamp(21.0, 24.0).toDouble(),
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
                      size: (width * 0.070).clamp(24.0, 28.0).toDouble(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: (width * 0.043).clamp(15.0, 17.0).toDouble(),
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  SizedBox(width: (width * 0.070).clamp(24.0, 28.0).toDouble()),
                ],
              ),
            ),
            const Spacer(),
            Icon(
              canEdit ? LucideIcons.plus : Icons.route_outlined,
              size: 42,
              color: AppColors.grayText,
            ),
            const SizedBox(height: 12),
            Text(
              canEdit
                  ? 'Trang thêm địa điểm sẽ phát triển ở bước sau'
                  : 'Trang xem lộ trình sẽ phát triển ở bước sau',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grayText),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
