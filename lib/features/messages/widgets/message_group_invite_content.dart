import 'package:flutter/material.dart';

import '../../../core/widgets/gomate_member_invite_content.dart';
import '../../../core/widgets/snackbar.dart';
import '../data/message_repository.dart';
import '../models/message_models.dart';

/// Adapter Messenger -> popup mời thành viên dùng chung.
///
/// Quy ước:
/// - Chỉ leader được mời thêm thành viên.
/// - accepted members không xuất hiện trong popup.
/// - pending cũng bị ẩn; hủy tại danh sách chờ bên ngoài.
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

class _MessageGroupInviteContentState extends State<MessageGroupInviteContent> {
  Set<String> _serverPending = const {};
  bool _loadingPending = true;
  String? _pendingError;
  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_refresh);
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() {
      _loadingPending = true;
      _pendingError = null;
    });
    try {
      final pending = await widget.repository.fetchPendingGroupInvites(widget.conversationId);
      if (!mounted) return;
      setState(() => _serverPending = pending.map((person) => person.contactId).toSet());
    } catch (error) {
      if (mounted) setState(() => _pendingError = 'Không tải được lời mời đang chờ: $error');
    } finally {
      if (mounted) setState(() => _loadingPending = false);
    }
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
    final conversation = widget.repository.conversation(widget.conversationId);

    if (conversation == null || !conversation.isGroup) {
      return const SizedBox.shrink();
    }

    final role = conversation.roleOf(widget.repository.currentUserId);

    final canManageInvite = role == MessageGroupRole.leader;

    if (!canManageInvite) {
      return const SizedBox.shrink();
    }
    if (_loadingPending) return const LinearProgressIndicator(minHeight: 2);
    if (_pendingError != null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_pendingError!),
        TextButton(onPressed: _loadPending, child: const Text('Thử lại')),
      ]);
    }

    final acceptedIds = conversation.participants
        .map((participant) => participant.id)
        .toSet();

    final pendingIds = widget.repository
        .pendingGroupInvites(widget.conversationId)
        .map((invite) => invite.contactId)
        .toSet();
    pendingIds.addAll(_serverPending);

    final contacts =
        widget.repository.contacts
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
      showPendingInvites: false,
      excludedContactIds: acceptedIds,

      // A successful Add hides the invitee; cancellation stays outside this popup.
      onAddInvites: (ids) async {
        if (ids.isEmpty) return;

        await widget.repository.inviteGroupMembers(widget.conversationId, ids);
        await _loadPending();

        if (!context.mounted) return;

        GoMateSnackBar.show(
          context,
          message: 'Đã gửi ${ids.length} lời mời tham gia lịch trình',
        );
      },

      onSearchContacts: (query) async {
        final results = await widget.repository.fetchContactSuggestions(query);
        return results
            .map(
              (contact) => GoMateInviteContact(
                id: contact.id,
                name: contact.name,
                subtitle: contact.subtitle,
                avatarAsset: contact.avatarAsset,
              ),
            )
            .toList(growable: false);
      },
    );
  }
}
