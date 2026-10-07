import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../data/message_repository.dart';
import '../models/message_models.dart';
import '../widgets/message_widgets.dart';
import 'chat_screen.dart';

class PendingMessagesScreen extends StatefulWidget {
  static const routeName = '/messages/pending';

  final MessageRepository repository;

  const PendingMessagesScreen({
    super.key,
    required this.repository,
  });

  @override
  State<PendingMessagesScreen> createState() => _PendingMessagesScreenState();
}

class _PendingMessagesScreenState extends State<PendingMessagesScreen> {
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

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selected.clear();
    });
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  void _toggleAll() {
    final items = widget.repository.pendingConversations;
    setState(() {
      if (_selected.length == items.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(items.map((e) => e.id));
      }
    });
  }

  void _acceptSelected() {
    if (_selected.isEmpty) return;
    widget.repository.acceptPending(_selected);
    Navigator.of(context).pop();
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final count = _selected.length;

    await GoMateBottomSheet.show<void>(
      context: context,
      child: MessageConfirmContent(
        title: 'Xoá ($count) tin nhắn chờ?',
        description:
            'Bạn sẽ không thể chấp nhận tin nhắn của những người này\n'
            'cho đến khi nhận được tin nhắn mới của họ',
        onConfirm: () {
          widget.repository.deletePending(_selected);
          Navigator.of(context).pop();
        },
      ),
    );

    if (!mounted) return;

    setState(() {
      _selected.clear();
      _selectionMode = false;
    });

    GoMateSnackBar.show(
      context,
      message: 'Đã xoá $count tin nhắn chờ',
    );
  }

  Future<void> _openPending(String id) async {
    // Chat tự đọc trạng thái isPending trực tiếp từ repository.
    // Khi chấp nhận trong chat, màn chat giữ nguyên và chuyển sang chat thường.
    // Khi Back về đây, request đã chấp nhận sẽ tự biến khỏi danh sách.
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MessageChatScreen(
          conversationId: id,
          repository: widget.repository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final items = widget.repository.pendingConversations;
    final allSelected = items.isNotEmpty && _selected.length == items.length;

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
                          'Tin nhắn đang chờ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: messageFont(width, 16),
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: items.isEmpty ? null : _toggleSelectionMode,
                        child: Icon(
                          LucideIcons.copy,
                          size: messageClamp(width * 0.064, 22, 25),
                          color: items.isEmpty
                              ? AppColors.grayBorder
                              : (_selectionMode
                                  ? AppColors.primaryIcon
                                  : AppColors.grayText),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: width * 0.018),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.17),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text:
                              'Mở đoạn chat để xem thêm thông tin về người đang nhắn tin cho bạn. '
                              'Chỉ khi bạn chấp nhận thì họ mới biết bạn đã xem.\n',
                        ),
                        const TextSpan(
                          text: 'Quyết định ai có thể nhắn tin cho bạn',
                          style: TextStyle(color: AppColors.primaryText),
                        ),
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
                if (_selectionMode)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      width * 0.07,
                      width * 0.018,
                      width * 0.055,
                      width * 0.006,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: _toggleAll,
                        child: Text(
                          '${_selected.isEmpty ? '' : '(${_selected.length}) '}'
                          '${allSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả'}',
                          style: TextStyle(
                            fontSize: messageFont(width, 10),
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: items.isEmpty
                      ? _PendingEmptyState(width: width)
                      : ListView.builder(
                          padding: EdgeInsets.only(
                            top: width * 0.020,
                            bottom: _selectionMode ? 100 : 24,
                          ),
                          physics: const BouncingScrollPhysics(),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _PendingRow(
                              conversation: item,
                              currentUserId: widget.repository.currentUserId,
                              selectionMode: _selectionMode,
                              selected: _selected.contains(item.id),
                              onTap: () {
                                if (_selectionMode) {
                                  _toggle(item.id);
                                } else {
                                  _openPending(item.id);
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
            if (_selectionMode && _selected.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      MessageGradientButton(
                        label: 'Chấp nhận (${_selected.length})',
                        onTap: _acceptSelected,
                      ),
                      SizedBox(width: width * 0.08),
                      InkWell(
                        onTap: _deleteSelected,
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
}

class _PendingEmptyState extends StatelessWidget {
  final double width;

  const _PendingEmptyState({
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: width * 0.20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.message_circle,
              size: messageClamp(width * 0.14, 48, 58),
              color: AppColors.grayBorder,
            ),
            SizedBox(height: width * 0.030),
            Text(
              'Không có tin nhắn chờ nào',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: messageFont(width, 13),
                fontWeight: FontWeight.w600,
                color: AppColors.grayText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  final MessageConversation conversation;
  final String currentUserId;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;

  const _PendingRow({
    required this.conversation,
    required this.currentUserId,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final other = conversation.participants.firstWhere(
      (p) => p.id != currentUserId,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: width * 0.075,
          vertical: width * 0.020,
        ),
        child: Row(
          children: [
            if (selectionMode) ...[
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? const Color(0xCC0A43A8)
                      : const Color(0xCCDADADA),
                  border: Border.all(color: Colors.white),
                ),
              ),
              SizedBox(width: width * 0.035),
            ],
            MessageAvatar(
              size: messageClamp(width * 0.095, 34, 38),
              asset: other.avatarAsset,
            ),
            SizedBox(width: width * 0.028),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    other.displayName,
                    style: TextStyle(
                      fontSize: messageFont(width, 13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: width * 0.006),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.isBlocked
                              ? 'Đã chặn'
                              : conversation.lastMessageText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: messageFont(width, 12),
                            fontWeight: FontWeight.w600,
                             color: conversation.isBlocked
                                 ? AppColors.primaryText
                                 : Colors.black,
                          ),
                        ),
                      ),
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
                          fontSize: messageFont(width, 10),
                          color: const Color(0xFFA6A6A6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: width * 0.025),
            if (!conversation.isBlocked)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryIcon,
                ),
              )
            else
              Icon(
                LucideIcons.ban,
                size: messageClamp(width * 0.050, 18, 20),
                color: AppColors.grayText,
              ),
          ],
        ),
      ),
    );
  }
}
