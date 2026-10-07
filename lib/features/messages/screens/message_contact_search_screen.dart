import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/message_repository.dart';
import '../models/message_models.dart';
import '../widgets/message_widgets.dart';
import 'chat_screen.dart';

/// Màn tìm kiếm đích chat.
///
/// Tìm đồng thời:
/// - liên hệ cá nhân;
/// - nhóm chat mà current user đang tham gia.
///
/// Không tìm pending request ở đây vì pending có flow riêng.
class MessageContactSearchScreen extends StatefulWidget {
  final MessageRepository repository;

  const MessageContactSearchScreen({
    super.key,
    required this.repository,
  });

  @override
  State<MessageContactSearchScreen> createState() =>
      _MessageContactSearchScreenState();
}

class _MessageContactSearchScreenState
    extends State<MessageContactSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late List<_MessageSearchTarget> _results;

  @override
  void initState() {
    super.initState();
    _results = _buildResults('');

    widget.repository.addListener(_refreshFromRepository);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _refreshFromRepository() {
    if (!mounted) return;

    setState(() {
      _results = _buildResults(_controller.text);
    });
  }

  List<_MessageSearchTarget> _buildResults(String query) {
    final normalized = query.trim().toLowerCase();

    final contacts = widget.repository.contacts
        .where(
          (contact) =>
              normalized.isEmpty ||
              contact.name.toLowerCase().contains(normalized) ||
              contact.subtitle.toLowerCase().contains(normalized),
        )
        .map(_MessageSearchTarget.contact)
        .toList(growable: false);

    final groups = widget.repository.mainConversations
        .where((conversation) => conversation.isGroup)
        .where(
          (conversation) =>
              normalized.isEmpty ||
              conversation.title.toLowerCase().contains(normalized) ||
              conversation.participants.any(
                (participant) =>
                    participant.name.toLowerCase().contains(normalized) ||
                    (participant.nickname ?? '')
                        .toLowerCase()
                        .contains(normalized),
              ),
        )
        .map(_MessageSearchTarget.group)
        .toList(growable: false);

    // Liên hệ trước, nhóm chat sau.
    // Nếu sau này backend trả ranking thì chỉ cần thay repository,
    // UI không phải đổi.
    return <_MessageSearchTarget>[
      ...contacts,
      ...groups,
    ];
  }

  void _search(String value) {
    setState(() {
      _results = _buildResults(value);
    });
  }

  void _openTarget(_MessageSearchTarget target) {
    if (target.groupConversation != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MessageChatScreen(
            conversationId: target.groupConversation!.id,
            repository: widget.repository,
          ),
        ),
      );
      return;
    }

    final contact = target.contact!;
    final conversationId =
        widget.repository.openOrCreateDirectConversation(contact.id);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MessageChatScreen(
          conversationId: conversationId,
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.repository.removeListener(_refreshFromRepository);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

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
                width * 0.060,
                width * 0.020,
                width * 0.060,
                width * 0.020,
              ),
              child: MessageSearchField(
                controller: _controller,
                focusNode: _focusNode,
                hintText: 'Tìm liên hệ hoặc nhóm...',
                onChanged: _search,
                showCancel: true,
                onCancel: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        'Không tìm thấy liên hệ hoặc nhóm.',
                        style: TextStyle(
                          fontSize: messageFont(width, 12),
                          color: AppColors.grayText,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.065,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final target = _results[index];

                        return _MessageSearchTargetRow(
                          target: target,
                          onTap: () => _openTarget(target),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageSearchTarget {
  final MessageContact? contact;
  final MessageConversation? groupConversation;

  const _MessageSearchTarget._({
    this.contact,
    this.groupConversation,
  });

  factory _MessageSearchTarget.contact(MessageContact contact) {
    return _MessageSearchTarget._(
      contact: contact,
    );
  }

  factory _MessageSearchTarget.group(MessageConversation conversation) {
    return _MessageSearchTarget._(
      groupConversation: conversation,
    );
  }

  bool get isGroup => groupConversation != null;

  String get title =>
      groupConversation?.title ??
      contact?.name ??
      '';

  String get subtitle {
    final group = groupConversation;
    if (group != null) {
      return 'Nhóm chat · ${group.participants.length} thành viên';
    }

    return contact?.subtitle ?? '';
  }
}

class _MessageSearchTargetRow extends StatelessWidget {
  final _MessageSearchTarget target;
  final VoidCallback onTap;

  const _MessageSearchTargetRow({
    required this.target,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final avatarSize = messageClamp(width * 0.082, 30, 35);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: width * 0.018,
        ),
        child: Row(
          children: [
            if (target.isGroup)
              MessageGroupAvatar(
                conversation: target.groupConversation!,
                size: avatarSize,
              )
            else
              MessageAvatar(
                size: avatarSize,
                asset: target.contact?.avatarAsset,
              ),
            SizedBox(width: width * 0.030),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    target.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: messageFont(width, 12.5),
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: width * 0.005),
                  Text(
                    target.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: messageFont(width, 10.5),
                      color: AppColors.grayText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
