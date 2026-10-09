import 'package:flutter/material.dart';

import '../../../core/widgets/gomate_member_invite_content.dart';
import '../../../core/widgets/snackbar.dart';
import '../data/message_repository.dart';
import '../models/message_models.dart';

/// Adapter Messenger -> popup mời thành viên dùng chung.
///
/// Quy ước:
/// - leader + deputy đều được mời thêm thành viên.
/// - leader + deputy đều được huỷ pending invite.
/// - accepted members không xuất hiện trong popup.
/// - pending luôn nằm trên đầu.
/// - UI thật nằm ở GoMateMemberInviteContent, không duplicate tại Messenger.
class MessageGroupInviteContent extends StatefulWidget {
  final String conversationId;
  final MessageRepository repository;

  const MessageGroupInviteContent({
    super.key,
    required this.conversationId,
    required this.repository,
  });

  @override
  State<MessageGroupInviteContent> createState() =>
      _MessageGroupInviteContentState();
}

class _MessageGroupInviteContentState
    extends State<MessageGroupInviteContent> {
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

  @override
  Widget build(BuildContext context) {
    final conversation =
        widget.repository.conversation(widget.conversationId);

    if (conversation == null || !conversation.isGroup) {
      return const SizedBox.shrink();
    }

    final role =
        conversation.roleOf(widget.repository.currentUserId);

    final canManageInvite =
        role == MessageGroupRole.leader ||
        role == MessageGroupRole.deputy;

    if (!canManageInvite) {
      return const SizedBox.shrink();
    }

    final acceptedIds = conversation.participants
        .map((participant) => participant.id)
        .toSet();

    final pendingIds = widget.repository
        .pendingGroupInvites(widget.conversationId)
        .map((invite) => invite.contactId)
        .toSet();

    final contacts = widget.repository.contacts
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
      pendingInviteIds: pendingIds,
      excludedContactIds: acceptedIds,

      // Đồng bộ leader/deputy:
      // ai có quyền mời thì cũng có quyền huỷ pending invite.
      canCancelPending: true,

      onAddInvites: (ids) {
        if (ids.isEmpty) return;

        widget.repository.inviteGroupMembers(
          widget.conversationId,
          ids,
        );

        if (!mounted) return;

        GoMateSnackBar.show(
          context,
          message: 'Đã gửi ${ids.length} lời mời vào nhóm',
        );
      },

      onCancelPending: (contactId) {
        MessageContact? contact;

        for (final item in widget.repository.contacts) {
          if (item.id == contactId) {
            contact = item;
            break;
          }
        }

        widget.repository.cancelGroupInvite(
          widget.conversationId,
          contactId,
        );

        if (!mounted) return;

        GoMateSnackBar.show(
          context,
          message: contact == null
              ? 'Đã huỷ lời mời'
              : 'Đã huỷ lời mời ${contact.name}',
        );
      },
    );
  }
}
