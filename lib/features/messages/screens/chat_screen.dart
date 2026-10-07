import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../data/message_repository.dart';
import '../models/message_models.dart';
import '../widgets/message_widgets.dart';
import 'message_detail_screen.dart';
import 'message_support_screens.dart';

class MessageChatScreen extends StatefulWidget {
  final String conversationId;
  final MessageRepository repository;
  /// Giữ lại để tương thích với call-site cũ. UI không dùng flag này làm nguồn
  /// sự thật nữa; trạng thái request luôn lấy từ conversation.isPending.
  final bool pendingMode;

  const MessageChatScreen({
    super.key,
    required this.conversationId,
    required this.repository,
    this.pendingMode = false,
  });

  @override
  State<MessageChatScreen> createState() => _MessageChatScreenState();
}

class _MessageChatScreenState extends State<MessageChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  String? _highlightedMessageId;

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_refresh);
    final current = widget.repository.conversation(widget.conversationId);
    if (current?.isPending != true) {
      widget.repository.markRead(widget.conversationId);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.repository.removeListener(_refresh);
    _scrollController.dispose();
    super.dispose();
  }

  MessageConversation? get _conversation =>
      widget.repository.conversation(widget.conversationId);

  MessageParticipant? _peer(MessageConversation conversation) {
    for (final p in conversation.participants) {
      if (p.id != widget.repository.currentUserId) return p;
    }
    return null;
  }

  Future<void> _openDetails() async {
    final conversation = _conversation;
    if (conversation == null) return;

    if (conversation.isPending) {
      final messageId = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => PendingMessageDetailScreen(
            conversationId: conversation.id,
            repository: widget.repository,
          ),
        ),
      );

      if (!mounted || messageId == null) return;
      _focusMessage(messageId);
      return;
    }

    final messageId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => MessageDetailScreen(
          conversationId: conversation.id,
          repository: widget.repository,
        ),
      ),
    );

    if (!mounted || messageId == null) return;
    _focusMessage(messageId);
  }

  void _focusMessage(String messageId) {
    setState(() => _highlightedMessageId = messageId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _messageKeys[messageId]?.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.35,
      );
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _acceptPending() {
    final conversation = _conversation;
    if (conversation == null || !conversation.isPending || conversation.isBlocked) {
      return;
    }

    widget.repository.acceptPending([widget.conversationId]);

    if (!mounted) return;

    // Không pop màn hình. Repository notifyListeners() làm screen rebuild ngay:
    // isPending=false => footer đổi từ request actions sang composer bình thường.
    GoMateSnackBar.show(
      context,
      message: 'Đã chấp nhận tin nhắn',
    );
  }

  void _unblockConversation(MessageConversation conversation) {
    final peer = _peer(conversation);

    widget.repository.unblockConversation(conversation.id);

    if (!mounted) return;

    GoMateSnackBar.show(
      context,
      message: 'Đã bỏ chặn ${peer?.displayName ?? conversation.title}',
    );
  }

  Future<void> _deletePending() async {
    await GoMateBottomSheet.show<void>(
      context: context,
      child: MessageConfirmContent(
        title: 'Xoá tin nhắn chờ?',
        description:
            'Bạn sẽ không thể chấp nhận tin nhắn của người này\n'
            'cho đến khi nhận được tin nhắn mới của họ',
        onConfirm: () {
          widget.repository.deletePending([widget.conversationId]);
          Navigator.of(context).pop();
        },
      ),
    );

    if (!mounted) return;
    GoMateSnackBar.show(context, message: 'Đã xoá tin nhắn chờ');
    Navigator.of(context).pop();
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              conversation: conversation,
              peer: peer,
              onBack: () => Navigator.of(context).pop(),
              onOpenDetail: _openDetails,
            ),
            Expanded(
              child: conversation.messages.isEmpty
                  ? const SizedBox.expand()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        width * 0.050,
                        width * 0.060,
                        width * 0.050,
                        width * 0.035,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: conversation.messages.length,
                      itemBuilder: (context, index) {
                        final message = conversation.messages[index];
                        final previous =
                            index > 0 ? conversation.messages[index - 1] : null;
                        final next = index + 1 < conversation.messages.length
                            ? conversation.messages[index + 1]
                            : null;

                        final firstInRun = previous == null ||
                            previous.senderId != message.senderId ||
                            message.dateLabel != null;
                        final lastInRun = next == null ||
                            next.senderId != message.senderId ||
                            next.dateLabel != null;
                        final isMine =
                            message.senderId == widget.repository.currentUserId;

                        MessageParticipant? sender;
                        for (final p in conversation.participants) {
                          if (p.id == message.senderId) {
                            sender = p;
                            break;
                          }
                        }

                        final key = _messageKeys.putIfAbsent(
                          message.id,
                          () => GlobalKey(),
                        );

                        return KeyedSubtree(
                          key: key,
                          child: Column(
                            children: [
                              if (message.dateLabel != null) ...[
                                Text(
                                  message.dateLabel!,
                                  style: TextStyle(
                                    fontSize: messageFont(width, 12),
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFA6A6A6),
                                  ),
                                ),
                                SizedBox(height: width * 0.045),
                              ],
                              MessageBubble(
                                message: message,
                                isMine: isMine,
                                firstInRun: firstInRun,
                                lastInRun: lastInRun,
                                avatarAsset: sender?.avatarAsset,
                                senderName: conversation.isGroup && !isMine
                                    ? sender?.displayName
                                    : null,
                                role: conversation.isGroup && !isMine
                                    ? sender?.role
                                    : null,
                                highlighted:
                                    _highlightedMessageId == message.id,
                              ),
                              SizedBox(
                                height: lastInRun
                                    ? width * 0.030
                                    : width * 0.006,
                              ),
                              if (index == conversation.messages.length - 1 &&
                                  isMine &&
                                  message.readByCurrentUser)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'Đã xem',
                                    style: TextStyle(
                                      fontSize: messageFont(width, 10),
                                      color: const Color(0xFFA6A6A6),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (conversation.isPending && conversation.isBlocked)
              _BlockedChatActions(
                peerName: peer?.displayName ?? conversation.title,
                onUnblock: () => _unblockConversation(conversation),
              )
            else if (conversation.isPending)
              _PendingChatActions(
                conversation: conversation,
                peer: peer,
                onAccept: _acceptPending,
                onDelete: _deletePending,
              )
            else if (!conversation.isGroup && conversation.isBlocked)
              _BlockedChatActions(
                peerName: peer?.displayName ?? conversation.title,
                onUnblock: () => _unblockConversation(conversation),
              )
            else
              MessageChatComposer(
                onSend: (text) {
                  widget.repository.sendText(
                    conversationId: conversation.id,
                    text: text,
                  );
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _scrollToBottom(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final MessageConversation conversation;
  final MessageParticipant? peer;
  final VoidCallback onBack;
  final VoidCallback onOpenDetail;

  const _ChatHeader({
    required this.conversation,
    required this.peer,
    required this.onBack,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final avatarSize = messageClamp(width * 0.095, 34, 38);

    return Container(
      padding: EdgeInsets.fromLTRB(
        width * 0.055,
        width * 0.020,
        width * 0.055,
        width * 0.018,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: AppColors.elevatedShadow,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            child: Icon(
              LucideIcons.chevron_left,
              size: messageClamp(width * 0.070, 24, 28),
            ),
          ),
          SizedBox(width: width * 0.025),
          InkWell(
            onTap: onOpenDetail,
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
          SizedBox(width: width * 0.025),
          Expanded(
            child: InkWell(
              onTap: onOpenDetail,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.isGroup
                        ? conversation.title
                        : (peer?.displayName ?? conversation.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: messageFont(width, 13),
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: width * 0.004),
                  Text(
                    (!conversation.isGroup && conversation.isBlocked)
                        ? 'Đã chặn'
                        : conversation.activityLabel,
                    style: TextStyle(
                      fontSize: messageFont(width, 10),
                      color: AppColors.grayText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Icon(
            LucideIcons.phone,
            size: messageClamp(width * 0.065, 22, 25),
            color: (!conversation.isGroup && conversation.isBlocked)
                ? AppColors.grayText
                : Colors.black,
          ),
          SizedBox(width: width * 0.055),
          Icon(
            LucideIcons.video,
            size: messageClamp(width * 0.065, 22, 25),
            color: (!conversation.isGroup && conversation.isBlocked)
                ? AppColors.grayText
                : Colors.black,
          ),
        ],
      ),
    );
  }
}

class _BlockedChatActions extends StatelessWidget {
  final String peerName;
  final VoidCallback onUnblock;

  const _BlockedChatActions({
    required this.peerName,
    required this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        width * 0.060,
        width * 0.028,
        width * 0.060,
        width * 0.025,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.grayBorder,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Bạn đã chặn $peerName',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: messageFont(width, 12),
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          SizedBox(height: width * 0.010),
          Text(
            'Bạn không thể gửi tin nhắn hoặc gọi cho người này '
            'cho đến khi bỏ chặn.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: messageFont(width, 10),
              height: 1.3,
              color: AppColors.grayText,
            ),
          ),
          SizedBox(height: width * 0.026),
          MessageGradientButton(
            label: 'Bỏ chặn',
            onTap: onUnblock,
          ),
        ],
      ),
    );
  }
}

class _PendingChatActions extends StatelessWidget {
  final MessageConversation conversation;
  final MessageParticipant? peer;
  final VoidCallback onAccept;
  final VoidCallback onDelete;

  const _PendingChatActions({
    required this.conversation,
    required this.peer,
    required this.onAccept,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        width * 0.080,
        width * 0.035,
        width * 0.060,
        width * 0.025,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.grayBorder),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Chấp nhận tin nhắn đang chờ của\n'
            '${peer?.displayName ?? conversation.title}?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: messageFont(width, 10),
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          SizedBox(height: width * 0.010),
          Text(
            'Nếu bạn chấp nhận, họ có thể gọi cho bạn, xem được trạng thái hoạt động '
            'và thời điểm bạn đọc tin nhắn',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: messageFont(width, 9),
              height: 1.3,
              color: AppColors.grayText,
            ),
          ),
          SizedBox(height: width * 0.030),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              MessageGradientButton(
                label: 'Xác nhận',
                onTap: onAccept,
              ),
              SizedBox(width: width * 0.080),
              InkWell(
                onTap: onDelete,
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
                    color: Colors.white,
                    size: messageClamp(width * 0.060, 21, 24),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
