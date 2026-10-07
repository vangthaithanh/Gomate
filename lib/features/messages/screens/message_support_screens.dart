import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../../home/widgets/report_reason_content.dart';
import '../data/message_repository.dart';
import '../models/message_models.dart';
import '../widgets/message_widgets.dart';

class MessageInChatSearchScreen extends StatefulWidget {
  final String conversationId;
  final MessageRepository repository;

  const MessageInChatSearchScreen({
    super.key,
    required this.conversationId,
    required this.repository,
  });

  @override
  State<MessageInChatSearchScreen> createState() =>
      _MessageInChatSearchScreenState();
}

class _MessageInChatSearchScreenState extends State<MessageInChatSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<MessageSearchResult> _results = const <MessageSearchResult>[];

  void _search(String value) {
    setState(() {
      _results = widget.repository.searchMessages(
        widget.conversationId,
        value,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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
                width * 0.065,
                width * 0.020,
                width * 0.055,
                width * 0.030,
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
                  SizedBox(width: width * 0.045),
                  Expanded(
                    child: MessageSearchField(
                      controller: _controller,
                      hintText: 'Tìm trong đoạn chat',
                      onChanged: _search,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: width * 0.13),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[index];
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(result.messageId),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: width * 0.020),
                      child: Row(
                        children: [
                          const MessageAvatar(size: 30),
                          SizedBox(width: width * 0.025),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  result.senderName,
                                  style: TextStyle(
                                    fontSize: messageFont(width, 11),
                                  ),
                                ),
                                SizedBox(height: width * 0.004),
                                Text(
                                  result.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: messageFont(width, 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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

class MessageNicknameScreen extends StatefulWidget {
  final String conversationId;
  final MessageRepository repository;

  const MessageNicknameScreen({
    super.key,
    required this.conversationId,
    required this.repository,
  });

  @override
  State<MessageNicknameScreen> createState() => _MessageNicknameScreenState();
}

class _MessageNicknameScreenState extends State<MessageNicknameScreen> {
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

  Future<void> _edit(MessageParticipant participant) async {
    await GoMateBottomSheet.show<void>(
      context: context,
      child: _NicknameEditorSheet(
        conversationId: widget.conversationId,
        participant: participant,
        repository: widget.repository,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversation = widget.repository.conversation(widget.conversationId);
    if (conversation == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final width = MediaQuery.sizeOf(context).width;
    final participants = conversation.participants
        .where((p) => p.id != widget.repository.currentUserId)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                width * 0.065,
                width * 0.020,
                width * 0.065,
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
                      'Biệt danh',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: messageFont(width, 16),
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  SizedBox(width: messageClamp(width * 0.070, 24, 28)),
                ],
              ),
            ),
            SizedBox(height: width * 0.020),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.18),
              child: Text.rich(
                const TextSpan(
                  children: [
                    TextSpan(text: 'Biệt danh chỉ hiển thị trong đoạn chat này.\n'),
                    TextSpan(
                      text:
                          'Bạn có thể chỉnh sửa biệt danh của những người thuộc đoạn chat này.',
                      style: TextStyle(color: AppColors.primaryText),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: messageFont(width, 10),
                  height: 1.3,
                  color: AppColors.grayText,
                ),
              ),
            ),
            SizedBox(height: width * 0.025),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: width * 0.080),
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  final participant = participants[index];
                  return InkWell(
                    onTap: () => _edit(participant),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: width * 0.020),
                      child: Row(
                        children: [
                          MessageAvatar(
                            size: 35,
                            asset: participant.avatarAsset,
                          ),
                          SizedBox(width: width * 0.030),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  participant.name,
                                  style: TextStyle(
                                    fontSize: messageFont(width, 13),
                                  ),
                                ),
                                if (participant.nickname != null)
                                  Text(
                                    participant.nickname!,
                                    style: TextStyle(
                                      fontSize: messageFont(width, 12),
                                      color: AppColors.grayText,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Icon(
                            LucideIcons.chevron_right,
                            color: AppColors.grayText,
                          ),
                        ],
                      ),
                    ),
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


class _NicknameEditorSheet extends StatefulWidget {
  final String conversationId;
  final MessageParticipant participant;
  final MessageRepository repository;

  const _NicknameEditorSheet({
    required this.conversationId,
    required this.participant,
    required this.repository,
  });

  @override
  State<_NicknameEditorSheet> createState() => _NicknameEditorSheetState();
}

class _NicknameEditorSheetState extends State<_NicknameEditorSheet> {
  late final TextEditingController _controller;
  late final String _existingNickname;

  @override
  void initState() {
    super.initState();

    _existingNickname = widget.participant.nickname?.trim() ?? '';
    _controller = TextEditingController(
      text: _existingNickname,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    setState(() {});
  }

  void _submit() {
    final current = _controller.text.trim();

    final unchanged =
        _existingNickname.isNotEmpty && current == _existingNickname;

    if (unchanged) {
      widget.repository.setNickname(
        conversationId: widget.conversationId,
        participantId: widget.participant.id,
        nickname: null,
      );
    } else {
      widget.repository.setNickname(
        conversationId: widget.conversationId,
        participantId: widget.participant.id,
        nickname: current,
      );
    }

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final current = _controller.text.trim();

    final unchanged =
        _existingNickname.isNotEmpty && current == _existingNickname;

    final actionLabel = unchanged ? 'Xoá' : 'Lưu';

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Chỉnh sửa biệt danh',
            style: TextStyle(
              fontSize: messageFont(width, 16),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mọi người trong đoạn chat đều nhìn thấy biệt danh này',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: messageFont(width, 10),
              color: AppColors.grayText,
            ),
          ),
          const SizedBox(height: 16),
          MessageAvatar(
            size: 40,
            asset: widget.participant.avatarAsset,
          ),
          const SizedBox(height: 18),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
            ),
            decoration: BoxDecoration(
              color: AppColors.grayBackground,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onChanged: _onTextChanged,
                    cursorColor: AppColors.primaryIcon,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Biệt danh...',
                      isDense: true,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _submit,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageItineraryPickerScreen extends StatefulWidget {
  final String conversationId;
  final MessageRepository repository;

  const MessageItineraryPickerScreen({
    super.key,
    required this.conversationId,
    required this.repository,
  });

  @override
  State<MessageItineraryPickerScreen> createState() =>
      _MessageItineraryPickerScreenState();
}

class _MessageItineraryPickerScreenState
    extends State<MessageItineraryPickerScreen> {
  final TextEditingController _controller = TextEditingController();
  late List<MessageItinerary> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.repository.itineraries;
  }

  void _search(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
      _items = q.isEmpty
          ? widget.repository.itineraries
          : widget.repository.itineraries
              .where((item) => item.title.toLowerCase().contains(q))
              .toList(growable: false);
    });
  }

  Future<void> _select(MessageItinerary itinerary) async {
    await GoMateBottomSheet.show<void>(
      context: context,
      child: MessageConfirmContent(
        title: 'Thêm vào lịch trình?',
        description:
            'Đoạn chat sẽ được thêm vào lịch trình "${itinerary.title}".',
        onConfirm: () {
          widget.repository.attachItinerary(
            conversationId: widget.conversationId,
            itineraryId: itinerary.id,
          );
          Navigator.of(context).pop();
        },
      ),
    );

    if (!mounted) return;
    GoMateSnackBar.show(
      context,
      message: 'Đã thêm vào lịch trình ${itinerary.title}',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
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
                width * 0.065,
                width * 0.020,
                width * 0.055,
                width * 0.030,
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
                  SizedBox(width: width * 0.045),
                  Expanded(
                    child: MessageSearchField(
                      controller: _controller,
                      hintText: 'Tìm lịch trình...',
                      onChanged: _search,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.085,
                  vertical: width * 0.020,
                ),
                itemCount: _items.length,
                separatorBuilder: (_, __) => SizedBox(height: width * 0.075),
                itemBuilder: (context, index) => MessageItineraryCard(
                  itinerary: _items[index],
                  onTap: () => _select(_items[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConversationItinerariesScreen extends StatelessWidget {
  final String conversationId;
  final MessageRepository repository;

  const ConversationItinerariesScreen({
    super.key,
    required this.conversationId,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final conversation = repository.conversation(conversationId);
    final ids = conversation?.itineraryIds ?? const <String>[];
    final items = repository.itineraries
        .where((item) => ids.contains(item.id))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _SimpleHeader(title: 'Lịch trình'),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'Chưa có lịch trình',
                        style: TextStyle(
                          fontSize: messageFont(width, 12),
                          color: AppColors.grayText,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: width * 0.085),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          SizedBox(height: width * 0.060),
                      itemBuilder: (context, index) => MessageItineraryCard(
                        itinerary: items[index],
                        onTap: () {},
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageProfilePlaceholderScreen extends StatelessWidget {
  final MessageParticipant? participant;

  const MessageProfilePlaceholderScreen({
    super.key,
    required this.participant,
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
              MessageAvatar(size: 80, asset: participant?.avatarAsset),
              const SizedBox(height: 16),
              Text(
                participant?.displayName ?? 'Người dùng',
                style: TextStyle(
                  fontSize: messageFont(width, 18),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Trang cá nhân sẽ được kết nối khi module Profile hoàn thiện.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: messageFont(width, 12),
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

class MessageGroupMembersScreen extends StatelessWidget {
  final String conversationId;
  final MessageRepository repository;

  const MessageGroupMembersScreen({
    super.key,
    required this.conversationId,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final conversation = repository.conversation(conversationId);
    final participants =
        conversation?.participants ?? const <MessageParticipant>[];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const _SimpleHeader(title: 'Thành viên'),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: width * 0.075),
                itemCount: participants.length,
                itemBuilder: (context, index) {
                  final participant = participants[index];
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: width * 0.018),
                    child: Row(
                      children: [
                        MessageAvatar(
                          size: 38,
                          asset: participant.avatarAsset,
                        ),
                        SizedBox(width: width * 0.030),
                        Expanded(
                          child: Text(
                            participant.displayName,
                            style: TextStyle(
                              fontSize: messageFont(width, 13),
                            ),
                          ),
                        ),
                        if (participant.role != MessageGroupRole.member)
                          Row(
                            children: [
                              Icon(
                                LucideIcons.key,
                                size: 16,
                                color:
                                    participant.role == MessageGroupRole.leader
                                        ? AppColors.primaryIcon
                                        : AppColors.grayText,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                participant.role == MessageGroupRole.leader
                                    ? 'Nhóm trưởng'
                                    : 'Nhóm phó',
                                style: TextStyle(
                                  fontSize: messageFont(width, 10),
                                  color: AppColors.grayText,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
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

class PendingMessageDetailScreen extends StatelessWidget {
  final String conversationId;
  final MessageRepository repository;

  const PendingMessageDetailScreen({
    super.key,
    required this.conversationId,
    required this.repository,
  });

  Future<void> _report(BuildContext context) async {
    final reason = await GoMateBottomSheet.show<ReportReason>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      child: const ReportReasonContent(),
    );

    if (!context.mounted || reason == null) return;
    GoMateSnackBar.show(context, message: 'Đã gửi báo cáo');
  }

  Future<void> _block(
    BuildContext context,
    MessageConversation conversation,
    MessageParticipant? peer,
  ) async {
    final confirmed = await GoMateBottomSheet.show<bool>(
      context: context,
      child: MessageConfirmContent(
        title: 'Chặn ${peer?.displayName ?? conversation.title}?',
        description:
            'Bạn sẽ chặn tất cả tương tác đối với người dùng này. '
            'Họ sẽ không được thông báo là bạn đã chặn.',
        onConfirm: () {
          repository.blockConversation(conversation.id);
          Navigator.of(context).pop(true);
        },
      ),
    );

    if (!context.mounted || confirmed != true) return;

    GoMateSnackBar.show(
      context,
      message: 'Đã chặn ${peer?.displayName ?? conversation.title}',
    );

    // Chỉ đóng trang chi tiết. Quay lại đúng request chat đang mở.
    // Request vẫn isPending=true, chat sẽ rebuild thành trạng thái "Bỏ chặn".
    Navigator.of(context).pop();
  }

  void _unblock(
    BuildContext context,
    MessageConversation conversation,
    MessageParticipant? peer,
  ) {
    repository.unblockConversation(conversation.id);

    GoMateSnackBar.show(
      context,
      message: 'Đã bỏ chặn ${peer?.displayName ?? conversation.title}',
    );

    // Quay về request chat để người dùng tiếp tục chọn Chấp nhận/Xoá.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final conversation = repository.conversation(conversationId);
    if (conversation == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final width = MediaQuery.sizeOf(context).width;
    MessageParticipant? peer;
    for (final p in conversation.participants) {
      if (p.id != repository.currentUserId) {
        peer = p;
        break;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            width * 0.065,
            width * 0.030,
            width * 0.065,
            width * 0.050,
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
              SizedBox(height: width * 0.050),
              MessageAvatar(size: 70, asset: peer?.avatarAsset),
              SizedBox(height: width * 0.015),
              Text(
                peer?.displayName ?? conversation.title,
                style: TextStyle(
                  fontSize: messageFont(width, 16),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: width * 0.045),
              Row(
                children: [
                  MessageDetailAction(
                    icon: LucideIcons.user_round,
                    label: 'Trang cá nhân',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MessageProfilePlaceholderScreen(
                            participant: peer,
                          ),
                        ),
                      );
                    },
                  ),
                  MessageDetailAction(
                    icon: LucideIcons.search,
                    label: 'Tìm kiếm',
                    onTap: () async {
                      final messageId = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (_) => MessageInChatSearchScreen(
                            conversationId: conversation.id,
                            repository: repository,
                          ),
                        ),
                      );
                      if (!context.mounted || messageId == null) return;
                      Navigator.of(context).pop(messageId);
                    },
                  ),
                ],
              ),
              SizedBox(height: width * 0.040),
              MessageDetailMenuRow(
                icon: LucideIcons.message_square_warning,
                label: 'Báo cáo',
                onTap: () => _report(context),
              ),
              MessageDetailMenuRow(
                icon: LucideIcons.ban,
                label: conversation.isBlocked ? 'Bỏ chặn' : 'Chặn',
                color: AppColors.primaryText,
                onTap: () => conversation.isBlocked
                    ? _unblock(context, conversation, peer)
                    : _block(context, conversation, peer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleHeader extends StatelessWidget {
  final String title;
  const _SimpleHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        width * 0.065,
        width * 0.020,
        width * 0.065,
        width * 0.030,
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
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: messageFont(width, 16),
                fontWeight: FontWeight.w800,
                color: AppColors.primaryText,
              ),
            ),
          ),
          SizedBox(width: messageClamp(width * 0.070, 24, 28)),
        ],
      ),
    );
  }
}
