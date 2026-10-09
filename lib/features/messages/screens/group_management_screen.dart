import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../data/message_repository.dart';
import '../models/message_models.dart';
import '../widgets/message_widgets.dart';
import '../widgets/message_group_invite_content.dart';
import '../widgets/message_group_invite_content.dart';

class RoleAwareGroupMembersScreen extends StatefulWidget {
  final String conversationId;
  final MessageRepository repository;

  const RoleAwareGroupMembersScreen({
    super.key,
    required this.conversationId,
    required this.repository,
  });

  @override
  State<RoleAwareGroupMembersScreen> createState() =>
      _RoleAwareGroupMembersScreenState();
}

class _RoleAwareGroupMembersScreenState
    extends State<RoleAwareGroupMembersScreen> {
  bool _selectionMode = false;
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.repository.removeListener(_refresh);
    super.dispose();
  }

  MessageConversation? get _conversation =>
      widget.repository.conversation(widget.conversationId);

  bool _selectable(
      MessageParticipant participant,
      MessageGroupRole actorRole,
      ) {
    if (participant.id == widget.repository.currentUserId) return false;
    if (participant.role == MessageGroupRole.leader) return false;

    if (actorRole == MessageGroupRole.leader) return true;

    if (actorRole == MessageGroupRole.deputy) {
      return participant.role == MessageGroupRole.member;
    }

    return false;
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selected.clear();
    });
  }

  void _toggleParticipant(String id) {
    setState(() {
      if (!_selected.add(id)) {
        _selected.remove(id);
      }
    });
  }

  void _toggleAll(MessageConversation conversation, MessageGroupRole role) {
    final selectableIds = conversation.participants
        .where((participant) => _selectable(participant, role))
        .map((participant) => participant.id)
        .toSet();

    setState(() {
      if (_selected.containsAll(selectableIds) &&
          _selected.length == selectableIds.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(selectableIds);
      }
    });
  }

  Future<void> _openInvite() async {
    await GoMateBottomSheet.show<void>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      child: MessageGroupInviteContent(
        conversationId: widget.conversationId,
        repository: widget.repository,
      ),
    );
  }

  List<MessageParticipant> _selectedParticipants(
      MessageConversation conversation,
      ) {
    return conversation.participants
        .where((participant) => _selected.contains(participant.id))
        .toList(growable: false);
  }

  String? _roleActionLabel(MessageConversation conversation) {
    final actorRole = conversation.roleOf(widget.repository.currentUserId);
    if (actorRole != MessageGroupRole.leader || _selected.isEmpty) {
      return null;
    }

    final selected = _selectedParticipants(conversation);
    if (selected.length == 1 &&
        selected.first.role == MessageGroupRole.deputy) {
      return 'Hủy uỷ quyền';
    }

    if (selected.isNotEmpty &&
        selected.every((participant) =>
        participant.role == MessageGroupRole.member)) {
      return 'Uỷ quyền';
    }

    return null;
  }

  Future<void> _handleRoleAction(MessageConversation conversation) async {
    final selected = _selectedParticipants(conversation);
    if (selected.isEmpty) return;

    if (selected.length == 1 &&
        selected.first.role == MessageGroupRole.deputy) {
      final participant = selected.first;

      await GoMateBottomSheet.show<void>(
        context: context,
        child: MessageConfirmContent(
          title: 'Hủy uỷ quyền cho ${participant.displayName}',
          description:
          'Thành viên này sẽ trở lại quyền hạn của thành viên bình thường',
          onConfirm: () {
            widget.repository.revokeGroupDeputy(
              conversation.id,
              participant.id,
            );
            Navigator.of(context).pop();
          },
        ),
      );

      if (!mounted) return;
      _selected.clear();
      setState(() => _selectionMode = false);
      GoMateSnackBar.show(
        context,
        message: 'Đã hủy uỷ quyền cho ${participant.displayName}',
      );
      return;
    }

    if (!selected.every(
          (participant) => participant.role == MessageGroupRole.member,
    )) {
      return;
    }

    await GoMateBottomSheet.show<void>(
      context: context,
      child: MessageConfirmContent(
        title: 'Uỷ quyền cho (${selected.length}) thành viên',
        description:
        'Những thành viên được uỷ quyền sẽ được cấp quyền phó nhóm',
        onConfirm: () {
          widget.repository.promoteGroupMembers(
            conversation.id,
            selected.map((e) => e.id),
          );
          Navigator.of(context).pop();
        },
      ),
    );

    if (!mounted) return;
    _selected.clear();
    setState(() => _selectionMode = false);
    GoMateSnackBar.show(
      context,
      message: 'Đã uỷ quyền cho ${selected.length} thành viên',
    );
  }

  Future<void> _deleteSelected(MessageConversation conversation) async {
    if (_selected.isEmpty) return;
    final count = _selected.length;

    await GoMateBottomSheet.show<void>(
      context: context,
      child: MessageConfirmContent(
        title: 'Xoá ($count) thành viên',
        description:
        'Những thành viên bị xoá khỏi đoạn chat cũng đồng nghĩa với việc '
            'họ sẽ bị xoá khỏi lịch trình du lịch nhóm',
        onConfirm: () {
          widget.repository.removeGroupMembers(
            conversation.id,
            _selected,
          );
          Navigator.of(context).pop();
        },
      ),
    );

    if (!mounted) return;
    _selected.clear();
    setState(() => _selectionMode = false);
    GoMateSnackBar.show(
      context,
      message: 'Đã xoá $count thành viên khỏi nhóm',
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    if (conversation == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Nhóm không còn tồn tại')),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final role = conversation.roleOf(widget.repository.currentUserId);
    final canManage = role != MessageGroupRole.member;
    final selectable = conversation.participants
        .where((participant) => _selectable(participant, role))
        .toList(growable: false);
    final allSelected = selectable.isNotEmpty &&
        _selected.length == selectable.length &&
        _selected.containsAll(selectable.map((e) => e.id));
    final roleActionLabel = _roleActionLabel(conversation);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    width * 0.065,
                    width * 0.020,
                    width * 0.055,
                    0,
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          LucideIcons.chevron_left,
                          size: messageClamp(width * 0.070, 24, 28),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Thành viên',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: messageFont(width, 16),
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                      if (canManage) ...[
                        InkWell(
                          onTap: _openInvite,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: EdgeInsets.all(width * 0.010),
                            child: Icon(
                              LucideIcons.plus,
                              size: messageClamp(width * 0.064, 22, 25),
                            ),
                          ),
                        ),
                        SizedBox(width: width * 0.028),
                        InkWell(
                          onTap: _toggleSelectionMode,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: EdgeInsets.all(width * 0.010),
                            child: Icon(
                              LucideIcons.copy,
                              size: messageClamp(width * 0.064, 22, 25),
                              color: _selectionMode
                                  ? AppColors.primaryIcon
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ] else
                        SizedBox(
                          width: messageClamp(width * 0.070, 24, 28),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: width * 0.018),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.13),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: _descriptionLead(role)),
                        if (role != MessageGroupRole.member) ...[
                          const TextSpan(text: '\n'),
                          const TextSpan(
                            text:
                            'Xoá thành viên ra khỏi nhóm đồng nghĩa với việc họ sẽ bị xoá khỏi lịch trình du lịch.',
                            style: TextStyle(color: AppColors.primaryText),
                          ),
                        ],
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: messageFont(width, 10),
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: AppColors.grayText,
                    ),
                  ),
                ),
                // Normal mode bám đúng hình 1: không giữ khung "Chọn tất cả".
                // Khi bật quản lý, khu vực này mở ra giống hình 2.
                // AnimatedSize giúp chuyển trạng thái mượt, tránh nhảy layout đột ngột.
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: canManage && _selectionMode
                      ? Padding(
                          padding: EdgeInsets.only(
                            left: width * 0.065,
                            right: width * 0.055,
                            top: width * 0.012,
                            bottom: width * 0.006,
                          ),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              onTap: () => _toggleAll(conversation, role),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: width * 0.008,
                                  vertical: width * 0.006,
                                ),
                                child: Text(
                                  '${_selected.isEmpty ? '' : '(${_selected.length}) '}'
                                  '${allSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả'}',
                                  style: TextStyle(
                                    fontSize: messageFont(width, 10.5),
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : SizedBox(height: width * 0.018),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      canManage ? width * 0.055 : width * 0.085,
                      0,
                      width * 0.050,
                      _selectionMode ? 95 : 24,
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: conversation.participants.length,
                    itemBuilder: (context, index) {
                      final participant = conversation.participants[index];
                      final canSelect = _selectable(participant, role);
                      final selected = _selected.contains(participant.id);

                      return _GroupMemberRow(
                        participant: participant,
                        isCurrentUser:
                        participant.id == widget.repository.currentUserId,
                        reserveSelectionSpace: canManage,
                        selectionMode: _selectionMode && canManage,
                        selectable: canSelect,
                        selected: selected,
                        onTap: canSelect && _selectionMode
                            ? () => _toggleParticipant(participant.id)
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_selectionMode && _selected.isNotEmpty && canManage)
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (roleActionLabel != null) ...[
                        MessageGradientButton(
                          label: roleActionLabel,
                          onTap: () => _handleRoleAction(conversation),
                        ),
                        SizedBox(width: width * 0.075),
                      ],
                      InkWell(
                        onTap: () => _deleteSelected(conversation),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: messageClamp(width * 0.12, 44, 48),
                          height: messageClamp(width * 0.12, 44, 48),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            LucideIcons.trash,
                            size: messageClamp(width * 0.060, 21, 24),
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: width * 0.07),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _descriptionLead(MessageGroupRole role) {
    switch (role) {
      case MessageGroupRole.member:
        return 'Bạn không thể thêm người vào nhóm. Chỉ trưởng nhóm và phó nhóm mới có thể thêm và xoá thành viên ra khỏi đoạn chat.';
      case MessageGroupRole.deputy:
        return 'Bạn không thể xoá trưởng nhóm và các phó nhóm.';
      case MessageGroupRole.leader:
        return 'Bạn có thể uỷ quyền cho bất kì thành viên nào đang có mặt trong nhóm.';
    }
  }
}

class _GroupMemberRow extends StatelessWidget {
  final MessageParticipant participant;
  final bool isCurrentUser;
  final bool reserveSelectionSpace;
  final bool selectionMode;
  final bool selectable;
  final bool selected;
  final VoidCallback? onTap;

  const _GroupMemberRow({
    required this.participant,
    required this.isCurrentUser,
    required this.reserveSelectionSpace,
    required this.selectionMode,
    required this.selectable,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    // Tỷ lệ row được làm lớn/rõ hơn theo mockup, nhưng vẫn responsive.
    final rowMinHeight = messageClamp(width * 0.165, 60, 68);
    final avatarSize = messageClamp(width * 0.105, 39, 43);
    final selectionSlotWidth = messageClamp(width * 0.078, 28, 31);
    final selectionCircleSize = messageClamp(width * 0.052, 19, 21);
    final chevronSize = messageClamp(width * 0.067, 24, 27);
    final keySize = messageClamp(width * 0.040, 14, 16);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: rowMinHeight),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Normal mode: không chừa selection rail -> đúng hình 1.
              // Management mode: mở selection rail -> đúng hình 2.
              // Dùng animation để avatar/text trượt nhẹ thay vì nhảy tức thì.
              if (reserveSelectionSpace)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: selectionMode ? selectionSlotWidth : 0,
                  child: selectionMode && selectable
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: selectionCircleSize,
                            height: selectionCircleSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? const Color(0xCC0A43A8)
                                  : const Color(0xCCDADADA),
                              border: Border.all(
                                color: Colors.white,
                                width: 1,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

              MessageAvatar(
                size: avatarSize,
                asset: participant.avatarAsset,
              ),
              SizedBox(width: messageClamp(width * 0.032, 11, 13)),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            participant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: messageFont(width, 13.5),
                              height: 1.15,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        if (participant.role != MessageGroupRole.member) ...[
                          SizedBox(width: width * 0.010),
                          Icon(
                            LucideIcons.key,
                            size: keySize,
                            color: participant.role == MessageGroupRole.leader
                                ? AppColors.primaryIcon
                                : AppColors.grayText,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: messageClamp(width * 0.006, 2, 3)),
                    Text(
                      participant.nickname?.trim().isNotEmpty == true
                          ? participant.nickname!
                          : participant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: messageFont(width, 11),
                        height: 1.12,
                        color: AppColors.grayText,
                      ),
                    ),
                  ],
                ),
              ),

              if (participant.distanceLabel != null) ...[
                SizedBox(width: width * 0.015),
                Text(
                  participant.distanceLabel!,
                  style: TextStyle(
                    fontSize: messageFont(width, 10),
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFA6A6A6),
                  ),
                ),
              ],

              SizedBox(width: width * 0.015),

              // Quy ước mới: chỉ chính current user không có mũi tên.
              // Mọi thành viên còn lại đều giữ cùng một trailing slot để hàng
              // thẳng nhau, không phụ thuộc role member/deputy/leader.
              SizedBox(
                width: chevronSize,
                height: chevronSize,
                child: isCurrentUser
                    ? const SizedBox.shrink()
                    : Icon(
                  LucideIcons.chevron_right,
                  size: chevronSize,
                  color: AppColors.grayText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GroupItineraryPlaceholderScreen extends StatelessWidget {
  final MessageItinerary itinerary;
  final String conversationId;

  const GroupItineraryPlaceholderScreen({
    super.key,
    required this.itinerary,
    required this.conversationId,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(width * 0.065),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(
                    LucideIcons.chevron_left,
                    size: messageClamp(width * 0.070, 24, 28),
                  ),
                ),
              ),
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  itinerary.imageAsset,
                  width: messageClamp(width * 0.32, 115, 135),
                  height: messageClamp(width * 0.32, 115, 135),
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(height: width * 0.035),
              Text(
                itinerary.title,
                style: TextStyle(
                  fontSize: messageFont(width, 20),
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryText,
                ),
              ),
              SizedBox(height: width * 0.018),
              Text(
                '${itinerary.dateRange}\n${itinerary.summary}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: messageFont(width, 12),
                  height: 1.5,
                  color: AppColors.grayText,
                ),
              ),
              SizedBox(height: width * 0.040),
              Text(
                'Trang chi tiết lịch trình nhóm sẽ được nối vào đây khi module Lịch trình hoàn thiện.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: messageFont(width, 12),
                  height: 1.35,
                  color: AppColors.grayText,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
