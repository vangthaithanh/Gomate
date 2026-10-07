import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/message_repository.dart';
import '../widgets/message_widgets.dart';
import 'chat_screen.dart';
import 'message_contact_search_screen.dart';
import 'pending_messages_screen.dart';

class MessageScreen extends StatefulWidget {
  final MessageRepository? repository;

  const MessageScreen({
    super.key,
    this.repository,
  });

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  late final MessageRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DemoMessageRepository.instance;
    _repository.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _repository.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _openConversation(String id) async {
    _repository.markRead(id);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessageChatScreen(
          conversationId: id,
          repository: _repository,
        ),
      ),
    );
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessageContactSearchScreen(
          repository: _repository,
        ),
      ),
    );
  }

  Future<void> _openPending() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PendingMessagesScreen(
          repository: _repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final conversations = _repository.mainConversations;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(height: width * 0.010),
            Text(
              _repository.currentUserName,
              style: TextStyle(
                fontSize: messageFont(width, 26),
                fontWeight: FontWeight.w900,
                color: AppColors.primaryText,
              ),
            ),
            SizedBox(height: width * 0.040),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.060),
              child: MessageSearchField(
                hintText: 'Tìm liên hệ',
                readOnly: true,
                onTap: _openSearch,
              ),
            ),
            SizedBox(height: width * 0.050),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.075),
              child: Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: _openPending,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: width * 0.010,
                      vertical: width * 0.010,
                    ),
                    child: Text(
                      'Tin nhắn đang chờ',
                      style: TextStyle(
                        fontSize: messageFont(width, 12.8),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFA6A6A6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(
                  top: width * 0.016,
                  bottom: 110,
                ),
                physics: const BouncingScrollPhysics(),
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  return MessageConversationTile(
                    conversation: conversation,
                    currentUserId: _repository.currentUserId,
                    activeRing: conversation.id == 'direct_chi',
                    onTap: () => _openConversation(conversation.id),
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
