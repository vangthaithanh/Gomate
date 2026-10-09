import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../models/message_models.dart';
import '../../../core/widgets/gomate_search_field.dart';

double messageFont(double width, double baseAt375) {
  final value = baseAt375 * (width / 375);
  return value.clamp(baseAt375 * 0.92, baseAt375 * 1.10).toDouble();
}

double messageClamp(double value, double min, double max) {
  return value.clamp(min, max).toDouble();
}

class MessageAvatar extends StatelessWidget {
  final String? asset;
  final double size;
  final bool activeRing;

  const MessageAvatar({
    super.key,
    required this.size,
    this.asset,
    this.activeRing = false,
  });

  @override
  Widget build(BuildContext context) {
    final ring = activeRing ? messageClamp(size * 0.075, 2.5, 3.2) : 0.0;
    final gap = activeRing ? messageClamp(size * 0.055, 2, 2.8) : 0.0;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: activeRing ? AppColors.primaryGradient : null,
      ),
      child: Container(
        padding: EdgeInsets.all(gap),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x1A0A43A8),
            border: activeRing
                ? null
                : Border.all(
                    color: AppColors.grayBorder,
                    width: 1,
                  ),
          ),
          child: asset == null
              ? Icon(
                  LucideIcons.user_round,
                  color: Colors.white,
                  size: size * 0.55,
                )
              : Image.asset(
                  asset!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    LucideIcons.user_round,
                    color: Colors.white,
                    size: size * 0.55,
                  ),
                ),
        ),
      ),
    );
  }
}

class MessageGroupAvatar extends StatelessWidget {
  final MessageConversation conversation;
  final double size;

  const MessageGroupAvatar({
    super.key,
    required this.conversation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (conversation.coverAsset != null) {
      return MessageAvatar(
        size: size,
        asset: conversation.coverAsset,
      );
    }

    final members = conversation.participants
        .where((p) => p.id != 'me')
        .take(3)
        .toList(growable: false);
    final small = size * 0.68;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (members.isNotEmpty)
            Positioned(
              left: 0,
              top: 0,
              child: MessageAvatar(
                size: small,
                asset: members[0].avatarAsset,
              ),
            ),
          if (members.length > 1)
            Positioned(
              right: 0,
              bottom: 0,
              child: MessageAvatar(
                size: small,
                asset: members[1].avatarAsset,
              ),
            ),
        ],
      ),
    );
  }
}

class MessageConversationTile extends StatelessWidget {
  final MessageConversation conversation;
  final String currentUserId;
  final VoidCallback onTap;
  final bool activeRing;

  const MessageConversationTile({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
    this.activeRing = false,
  });

  MessageParticipant? _otherParticipant() {
    for (final participant in conversation.participants) {
      if (participant.id != currentUserId) return participant;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final avatarSize = messageClamp(width * 0.112, 40, 46);
    final unread = conversation.unreadCount > 0;
    final isMine = conversation.lastSenderId == currentUserId;
    final peer = _otherParticipant();

    final title = conversation.isGroup
        ? conversation.title
        : (peer?.displayName ?? conversation.title);

    String preview;
    if (conversation.lastMessageText.isEmpty) {
      preview = '';
    } else if (isMine && conversation.lastMessageTime.isNotEmpty) {
      preview = 'Đã gửi ${conversation.lastMessageTime}';
    } else if (unread) {
      preview = conversation.unreadCount > 5
          ? '5+ tin nhắn mới'
          : '${conversation.unreadCount} tin nhắn mới';
    } else {
      preview = conversation.lastMessageText;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: width * 0.075,
            vertical: messageClamp(width * 0.024, 8, 11),
          ),
          child: Row(
            children: [
              if (conversation.isGroup)
                MessageGroupAvatar(
                  conversation: conversation,
                  size: avatarSize,
                )
              else
                MessageAvatar(
                  size: avatarSize,
                  asset: peer?.avatarAsset,
                  activeRing: activeRing,
                ),
              SizedBox(width: messageClamp(width * 0.030, 11, 14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: messageFont(width, 14.5),
                        height: 1.18,
                        color: Colors.black,
                        fontWeight:
                            unread ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    if (preview.isNotEmpty) ...[
                      SizedBox(height: messageClamp(width * 0.007, 2, 3)),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: messageFont(width, 12.8),
                                height: 1.18,
                                color: unread
                                    ? Colors.black
                                    : AppColors.grayText,
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (!isMine &&
                              conversation.lastMessageTime.isNotEmpty) ...[
                            SizedBox(width: width * 0.018),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.grayBorder,
                              ),
                            ),
                            SizedBox(width: width * 0.018),
                            Text(
                              conversation.lastMessageTime,
                              style: TextStyle(
                                fontSize: messageFont(width, 10.8),
                                color: const Color(0xFFA6A6A6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (unread) ...[
                SizedBox(width: width * 0.020),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryIcon,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MessageSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;
  final bool showCancel;
  final bool readOnly;

  const MessageSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Tìm...',
    this.onChanged,
    this.onTap,
    this.onCancel,
    this.showCancel = false,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return GoMateSearchField(
      controller: controller,
      focusNode: focusNode,
      hintText: hintText,
      onChanged: onChanged,
      onTap: onTap,
      onCancel: onCancel,
      showCancel: showCancel,
      readOnly: readOnly,
    );
  }
}

class MessageGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double? width;

  const MessageGradientButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: width ?? messageClamp(screenWidth * 0.43, 150, 170),
          height: messageClamp(screenWidth * 0.125, 44, 50),
          decoration: BoxDecoration(
            gradient: onTap == null ? null : AppColors.primaryGradient,
            color: onTap == null ? AppColors.grayBorder : null,
            borderRadius: BorderRadius.circular(20),
            boxShadow: onTap == null ? null : AppColors.elevatedShadow,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: messageFont(screenWidth, 14),
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

class MessageConfirmContent extends StatelessWidget {
  final String title;
  final String description;
  final String confirmLabel;
  final VoidCallback onConfirm;

  const MessageConfirmContent({
    super.key,
    required this.title,
    required this.description,
    required this.onConfirm,
    this.confirmLabel = 'Xác nhận',
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
              color: Colors.black,
            ),
          ),
          SizedBox(height: width * 0.025),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: messageFont(width, 10),
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: AppColors.grayText,
            ),
          ),
          SizedBox(height: width * 0.035),
          MessageGradientButton(
            label: confirmLabel,
            onTap: onConfirm,
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final MessageItem message;
  final bool isMine;
  final bool firstInRun;
  final bool lastInRun;
  final String? avatarAsset;
  final String? senderName;
  final MessageGroupRole? role;
  final bool highlighted;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.firstInRun,
    required this.lastInRun,
    this.avatarAsset,
    this.senderName,
    this.role,
    this.highlighted = false,
  });

  BorderRadius _radius() {
    const large = Radius.circular(18);
    const small = Radius.circular(4);

    if (isMine) {
      return BorderRadius.only(
        topLeft: large,
        bottomLeft: large,
        topRight: firstInRun ? large : small,
        bottomRight: lastInRun ? large : small,
      );
    }

    return BorderRadius.only(
      topRight: large,
      bottomRight: large,
      topLeft: firstInRun ? large : small,
      bottomLeft: lastInRun ? large : small,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxBubble = messageClamp(width * 0.72, 230, 320);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxBubble),
      padding: EdgeInsets.symmetric(
        horizontal: messageClamp(width * 0.043, 14, 17),
        vertical: messageClamp(width * 0.021, 7, 9),
      ),
      decoration: BoxDecoration(
        color: isMine
            ? const Color(0x330A43A8)
            : const Color(0xFFE9E9EB),
        borderRadius: _radius(),
        border: highlighted
            ? Border.all(
                color: AppColors.primaryIcon,
                width: 2,
              )
            : null,
      ),
      child: Text(
        message.text,
        style: TextStyle(
          fontSize: messageFont(width, 14),
          height: 1.4,
          fontWeight: FontWeight.w500,
          color: Colors.black,
        ),
      ),
    );

    if (isMine) {
      return Align(
        alignment: Alignment.centerRight,
        child: bubble,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: messageClamp(width * 0.095, 34, 38),
          child: lastInRun
              ? MessageAvatar(
                  size: messageClamp(width * 0.078, 28, 32),
                  asset: avatarAsset,
                )
              : null,
        ),
        SizedBox(width: width * 0.012),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (firstInRun && senderName != null)
                Padding(
                  padding: EdgeInsets.only(
                    left: width * 0.012,
                    bottom: width * 0.007,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        senderName!,
                        style: TextStyle(
                          fontSize: messageFont(width, 10),
                          color: AppColors.grayText,
                        ),
                      ),
                      if (role == MessageGroupRole.leader ||
                          role == MessageGroupRole.deputy) ...[
                        SizedBox(width: width * 0.008),
                        Icon(
                          LucideIcons.key,
                          size: messageClamp(width * 0.032, 11, 13),
                          color: role == MessageGroupRole.leader
                              ? AppColors.primaryIcon
                              : AppColors.grayText,
                        ),
                      ],
                    ],
                  ),
                ),
              bubble,
            ],
          ),
        ),
      ],
    );
  }
}

class MessageChatComposer extends StatefulWidget {
  final ValueChanged<String> onSend;

  const MessageChatComposer({
    super.key,
    required this.onSend,
  });

  @override
  State<MessageChatComposer> createState() => _MessageChatComposerState();
}

class _MessageChatComposerState extends State<MessageChatComposer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hasText = _controller.text.trim().isNotEmpty;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          width * 0.053,
          width * 0.018,
          width * 0.053,
          width * 0.020,
        ),
        child: Container(
          constraints: BoxConstraints(
            minHeight: messageClamp(width * 0.093, 34, 38),
          ),
          padding: EdgeInsets.symmetric(horizontal: width * 0.025),
          decoration: BoxDecoration(
            color: AppColors.grayBackground,
            borderRadius: BorderRadius.circular(
              messageClamp(width * 0.040, 14, 16),
            ),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.camera,
                size: messageClamp(width * 0.050, 18, 21),
                color: AppColors.grayText,
              ),
              SizedBox(width: width * 0.025),
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  cursorColor: AppColors.primaryIcon,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: TextStyle(
                    fontSize: messageFont(width, 13),
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Nhắn tin...',
                    hintStyle: TextStyle(
                      fontSize: messageFont(width, 13),
                      color: AppColors.grayText,
                    ),
                  ),
                ),
              ),
              if (!hasText) ...[
                Icon(
                  LucideIcons.mic,
                  size: messageClamp(width * 0.050, 18, 21),
                  color: AppColors.grayText,
                ),
                SizedBox(width: width * 0.022),
                Icon(
                  LucideIcons.circle_ellipsis,
                  size: messageClamp(width * 0.050, 18, 21),
                  color: AppColors.grayText,
                ),
                SizedBox(width: width * 0.022),
                Icon(
                  LucideIcons.image,
                  size: messageClamp(width * 0.050, 18, 21),
                  color: AppColors.grayText,
                ),
              ] else
                InkWell(
                  onTap: _send,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: messageClamp(width * 0.075, 28, 32),
                    height: messageClamp(width * 0.075, 28, 32),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.arrow_up,
                      size: messageClamp(width * 0.045, 16, 19),
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageDetailAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const MessageDetailAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: messageClamp(width * 0.058, 20, 24),
              color: color,
            ),
            SizedBox(height: width * 0.010),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: messageFont(width, 10),
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageDetailMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool showChevron;
  final Widget? trailing;

  const MessageDetailMenuRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.black,
    this.showChevron = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: messageClamp(width * 0.030, 10, 13),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: messageClamp(width * 0.060, 21, 24),
              color: color,
            ),
            SizedBox(width: width * 0.040),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: messageFont(width, 12),
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            if (trailing != null)
              trailing!
            else if (showChevron)
              Icon(
                LucideIcons.chevron_right,
                size: messageClamp(width * 0.060, 21, 24),
                color: AppColors.grayText,
              ),
          ],
        ),
      ),
    );
  }
}
