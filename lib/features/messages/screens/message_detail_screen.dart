import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../../home/widgets/report_reason_content.dart';
import '../../map/state/map_ui_session.dart';
import '../../trip/models/trip_ui_models.dart';
import '../../trip/screens/trip_detail_screen.dart';
import '../data/message_repository.dart';
import '../models/message_models.dart';
import '../widgets/message_widgets.dart';
import '../../../core/widgets/gomate_name_editor_content.dart';
import 'group_management_screen.dart';
import 'message_add_to_itinerary_screen.dart';
import 'message_support_screens.dart';

class MessageDetailScreen extends StatefulWidget {
  final String conversationId;
  final MessageRepository repository;

  const MessageDetailScreen({
    super.key,
    required this.conversationId,
    required this.repository,
  });

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  bool _showLinks = false;
  String? _pendingItineraryInviteId;

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

  MessageParticipant? _peer(MessageConversation conversation) {
    for (final participant in conversation.participants) {
      if (participant.id != widget.repository.currentUserId) {
        return participant;
      }
    }
    return null;
  }

  Future<void> _openSearch(MessageConversation conversation) async {
    final messageId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => MessageInChatSearchScreen(
          conversationId: conversation.id,
          repository: widget.repository,
        ),
      ),
    );

    if (!mounted || messageId == null) return;
    Navigator.of(context).pop(messageId);
  }

  Future<void> _report() async {
    final reason = await GoMateBottomSheet.show<ReportReason>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      child: const ReportReasonContent(),
    );

    if (!mounted || reason == null) return;

    GoMateSnackBar.show(
      context,
      message: 'Đã gửi báo cáo',
    );
  }

  Future<void> _block(MessageConversation conversation) async {
    final peer = _peer(conversation);

    final confirmed = await GoMateBottomSheet.show<bool>(
      context: context,
      child: _BlockContent(
        title: 'Chặn ${peer?.displayName ?? conversation.title}?',
        onConfirm: () {
          widget.repository.blockConversation(conversation.id);
          Navigator.of(context).pop(true);
        },
      ),
    );

    if (!mounted || confirmed != true) return;

    GoMateSnackBar.show(
      context,
      message: 'Đã chặn ${peer?.displayName ?? conversation.title}',
    );

    Navigator.of(context).pop();
  }

  void _unblock(MessageConversation conversation) {
    final peer = _peer(conversation);

    widget.repository.unblockConversation(conversation.id);

    if (!mounted) return;

    GoMateSnackBar.show(
      context,
      message: 'Đã bỏ chặn ${peer?.displayName ?? conversation.title}',
    );
  }

  Future<void> _leaveGroup(MessageConversation conversation) async {
    await GoMateBottomSheet.show<void>(
      context: context,
      child: MessageConfirmContent(
        title: 'Rời nhóm?',
        description:
            'Rời nhóm đồng nghĩa với việc bạn rời lịch trình du lịch\n'
            'Hành động này sẽ được thông báo đến tất cả các thành viên trong nhóm',
        onConfirm: () {
          widget.repository.leaveGroup(conversation.id);
          Navigator.of(context).pop();
        },
      ),
    );

    if (!mounted) return;

    GoMateSnackBar.show(
      context,
      message: 'Đã rời nhóm ${conversation.title}',
    );

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _deleteGroup(MessageConversation conversation) async {
    await GoMateBottomSheet.show<void>(
      context: context,
      child: MessageConfirmContent(
        title: 'Xoá nhóm?',
        description:
            'Xoá nhóm đồng nghĩa với việc xoá lịch trình du lịch của nhóm.\n'
            'Hành động này sẽ được thông báo đến tất cả các thành viên trong nhóm',
        onConfirm: () {
          widget.repository.deleteGroupAndItinerary(conversation.id);
          Navigator.of(context).pop();
        },
      ),
    );

    if (!mounted) return;

    GoMateSnackBar.show(
      context,
      message: 'Đã xoá nhóm và lịch trình ${conversation.title}',
    );

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _renameGroup(
      MessageConversation conversation,
      ) async {
    final value = await GoMateBottomSheet.show<String>(
      context: context,
      child: GoMateNameEditorContent(
        title: 'Chỉnh sửa tên nhóm',
        initialValue: conversation.title,
        hintText: 'Tên nhóm...',
      ),
    );

    if (!mounted || value == null) return;

    widget.repository.renameGroup(
      conversation.id,
      value,
    );
  }

  void _toggleMute(MessageConversation conversation) {
    widget.repository.toggleMute(conversation.id);
    final updated = widget.repository.conversation(conversation.id);

    GoMateSnackBar.show(
      context,
      message: updated?.isMuted == true
          ? 'Đã tắt thông báo đoạn chat'
          : 'Đã bật thông báo đoạn chat',
    );
  }

  TripAccessRole _toTripRole(
    MessageGroupRole role,
  ) {
    switch (role) {
      case MessageGroupRole.leader:
        return TripAccessRole.leader;

      case MessageGroupRole.deputy:
        return TripAccessRole.deputy;

      case MessageGroupRole.member:
        return TripAccessRole.member;
    }
  }

  void _openLinkedItinerary(
    MessageConversation conversation,
  ) {
    final itinerary =
        widget.repository.linkedGroupItinerary(
      conversation.id,
    );

    if (itinerary == null) {
      GoMateSnackBar.show(
        context,
        message: 'Không tìm thấy lịch trình của nhóm',
      );
      return;
    }

    TripUi? trip;

    // Ưu tiên object Trip đang dùng chung trong app.
    for (final item in GoMateMapUiSession.availableTrips) {
      if (item.id == itinerary.id) {
        trip = item;
        break;
      }
    }

    // Fallback UI-only trong lúc backend Trip/Message
    // chưa dùng chung DTO.
    trip ??= TripUi(
      id: itinerary.id,
      title: itinerary.title,
      days: 1,
      destination: itinerary.title,
      coverAsset: itinerary.imageAsset,
      isGroup: true,
      currentUserRole: _toTripRole(
        conversation.roleOf(
          widget.repository.currentUserId,
        ),
      ),
      members: conversation.participants
          .map(
            (member) => TripMemberUi(
              id: member.id,
              name: member.displayName,
              avatarAsset: member.avatarAsset ?? '',
              role: _toTripRole(
                member.role,
              ),
            ),
          )
          .toList(growable: false),
      conversationId: conversation.id,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(
          trip: trip!,
          messageRepository: widget.repository,
        ),
      ),
    );
  }

  Future<void> _openAddToItinerary(
    MessageConversation conversation,
  ) async {
    if (conversation.isGroup) return;

    if (conversation.isBlocked) {
      GoMateSnackBar.show(
        context,
        message: 'Bỏ chặn người dùng trước khi mời vào lịch trình',
      );
      return;
    }

    final peer = _peer(conversation);
    if (peer == null) return;

    final itinerary = await Navigator.of(context).push<MessageItinerary>(
      MaterialPageRoute<MessageItinerary>(
        builder: (_) => MessageAddToItineraryScreen(
          repository: widget.repository,
        ),
      ),
    );

    if (!mounted || itinerary == null) return;

    setState(() {
      _pendingItineraryInviteId = itinerary.id;
    });

    final confirmed = await GoMateBottomSheet.show<bool>(
      context: context,
      child: MessageConfirmContent(
        title: 'Mời ${peer.displayName} vào lịch trình\n${itinerary.title}',
        description:
            'Người này sẽ tham gia vào lịch trình khi xác nhận lời mời',
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );

    if (!mounted) return;

    setState(() {
      _pendingItineraryInviteId = null;
    });

    if (confirmed != true) return;

    widget.repository.invitePeerToItinerary(
      conversationId: conversation.id,
      itineraryId: itinerary.id,
    );

    GoMateSnackBar.show(
      context,
      message:
          'Đã gửi lời mời tham gia ${itinerary.title} cho ${peer.displayName}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    if (conversation == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Đoạn chat không còn tồn tại')),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final peer = _peer(conversation);
    final groupRole = conversation.isGroup
        ? conversation.roleOf(widget.repository.currentUserId)
        : MessageGroupRole.member;
    final title =
        conversation.isGroup ? conversation.title : (peer?.displayName ?? '');
    final avatarSize = messageClamp(width * 0.19, 66, 74);
    final canRenameGroup = conversation.isGroup &&
        (groupRole == MessageGroupRole.leader ||
            groupRole == MessageGroupRole.deputy);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            0,
            width * 0.030,
            0,
            width * 0.050,
          ),
          physics: const BouncingScrollPhysics(),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: width * 0.065,
              ),
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
            SizedBox(height: width * 0.030),
            Center(
              child: conversation.isGroup
                  ? MessageGroupAvatar(
                      conversation: conversation,
                      size: avatarSize,
                    )
                  : MessageAvatar(
                      size: avatarSize,
                      asset: peer?.avatarAsset,
                    ),
            ),
            SizedBox(height: width * 0.012),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: messageFont(width, 16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (canRenameGroup) ...[
                  SizedBox(width: width * 0.010),
                  InkWell(
                    onTap: () => _renameGroup(conversation),
                    child: Icon(
                      LucideIcons.pencil,
                      size: messageClamp(width * 0.045, 16, 19),
                      color: AppColors.grayText,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: width * 0.045),
            Row(
              children: [
                MessageDetailAction(
                  icon: conversation.isGroup
                      ? LucideIcons.users_round
                      : LucideIcons.user_round,
                  label:
                      conversation.isGroup ? 'Xem Thành Viên' : 'Trang cá nhân',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => conversation.isGroup
                            ? RoleAwareGroupMembersScreen(
                                conversationId: conversation.id,
                                repository: widget.repository,
                              )
                            : MessageProfilePlaceholderScreen(
                                participant: peer,
                              ),
                      ),
                    );
                  },
                ),
                MessageDetailAction(
                  icon: conversation.isMuted
                      ? LucideIcons.bell_off
                      : LucideIcons.bell,
                  label: conversation.isMuted ? 'Bật' : 'Tắt',
                  color: conversation.isMuted
                      ? AppColors.primaryText
                      : Colors.black,
                  onTap: () => _toggleMute(conversation),
                ),
                MessageDetailAction(
                  icon: LucideIcons.search,
                  label: 'Tìm kiếm',
                  onTap: () => _openSearch(conversation),
                ),
              ],
            ),
            SizedBox(height: width * 0.045),
            MessageDetailMenuRow(
              icon: LucideIcons.folder_pen,
              label: 'Đặt biệt danh',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MessageNicknameScreen(
                      conversationId: conversation.id,
                      repository: widget.repository,
                    ),
                  ),
                );
              },
            ),
            if (conversation.isGroup)
              MessageDetailMenuRow(
                icon: LucideIcons.calendar,
                label: 'Xem lịch trình',
                onTap: () => _openLinkedItinerary(conversation),
              )
            else
              MessageDetailMenuRow(
                icon: LucideIcons.users_round,
                label: 'Thêm vào lịch trình',
                trailing: _pendingItineraryInviteId == null
                    ? null
                    : Text(
                        '(1) Thêm',
                        style: TextStyle(
                          fontSize: messageFont(width, 10),
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
                onTap: () => _openAddToItinerary(conversation),
              ),
            MessageDetailMenuRow(
              icon: LucideIcons.message_square_warning,
              label: 'Báo cáo',
              onTap: _report,
            ),
            if (conversation.isGroup)
              MessageDetailMenuRow(
                icon: groupRole == MessageGroupRole.leader
                    ? LucideIcons.trash
                    : LucideIcons.log_out,
                label: groupRole == MessageGroupRole.leader
                    ? 'Xoá nhóm'
                    : 'Rời nhóm',
                color: AppColors.primaryText,
                onTap: () => groupRole == MessageGroupRole.leader
                    ? _deleteGroup(conversation)
                    : _leaveGroup(conversation),
              )
            else
              MessageDetailMenuRow(
                icon: LucideIcons.ban,
                label: conversation.isBlocked ? 'Bỏ chặn' : 'Chặn',
                color: AppColors.primaryText,
                onTap: () => conversation.isBlocked
                    ? _unblock(conversation)
                    : _block(conversation),
              ),
            SizedBox(height: width * 0.025),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MediaTabIcon(
                  icon: LucideIcons.images,
                  active: !_showLinks,
                  onTap: () => setState(() => _showLinks = false),
                ),
                _MediaTabIcon(
                  icon: LucideIcons.link,
                  active: _showLinks,
                  onTap: () => setState(() => _showLinks = true),
                ),
              ],
            ),
            SizedBox(height: width * 0.025),
                ],
              ),
            ),

            // Ảnh / video phải tràn ngang như mockup.
            // Không nhận horizontal padding của phần detail phía trên.
            if (_showLinks)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.065,
                ),
                child: _LinkList(
                  links: conversation.links,
                ),
              )
            else
              _MediaGrid(
                assets: conversation.mediaAssets,
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaTabIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _MediaTabIcon({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: EdgeInsets.all(width * 0.020),
        child: Icon(
          icon,
          size: messageClamp(width * 0.070, 25, 30),
          color: active ? Colors.black : AppColors.grayText,
        ),
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  final List<String> assets;

  const _MediaGrid({
    required this.assets,
  });

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) return const SizedBox(height: 40);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: assets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemBuilder: (context, index) {
        return Image.asset(
          assets[index],
          fit: BoxFit.cover,
        );
      },
    );
  }
}

class _LinkList extends StatelessWidget {
  final List<String> links;

  const _LinkList({
    required this.links,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (links.isEmpty) return const SizedBox(height: 40);

    return Column(
      children: [
        for (final link in links) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: width * 0.040,
              vertical: width * 0.040,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: AppColors.elevatedShadow,
            ),
            child: Text(
              link,
              style: TextStyle(
                fontSize: messageFont(width, 12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: width * 0.032),
        ],
      ],
    );
  }
}

class _BlockContent extends StatelessWidget {
  final String title;
  final VoidCallback onConfirm;

  const _BlockContent({
    required this.title,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: messageFont(width, 16),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: width * 0.025),
          Text(
            'Bạn sẽ chặn tất cả tương tác đối với người dùng này. '
            'Bạn có thể bỏ chặn bất cứ lúc nào',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: messageFont(width, 10),
              color: AppColors.grayText,
              height: 1.3,
            ),
          ),
          SizedBox(height: width * 0.030),
          _BlockPoint(
            icon: LucideIcons.ban,
            text:
                'Họ sẽ không thể nhắn tin hay tìm được trang cá nhân hoặc các nội dung của bạn',
          ),
          const Divider(color: AppColors.grayBorder),
          _BlockPoint(
            icon: LucideIcons.bell_off,
            text: 'Họ sẽ không được thông báo là bạn đã chặn',
          ),
          SizedBox(height: width * 0.030),
          MessageGradientButton(
            label: 'Xác nhận',
            onTap: onConfirm,
          ),
        ],
      ),
    );
  }
}

class _BlockPoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BlockPoint({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: width * 0.020),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.grayText,
            size: messageClamp(width * 0.060, 21, 24),
          ),
          SizedBox(width: width * 0.035),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: messageFont(width, 10),
                color: AppColors.grayText,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
