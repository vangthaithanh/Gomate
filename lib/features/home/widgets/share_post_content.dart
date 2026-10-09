import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../data/post_interaction_repository.dart';
import '../models/post_interaction_models.dart';
import '../../../core/widgets/gomate_search_field.dart';

class SharePostContent extends StatefulWidget {
  final String postId;
  final PostInteractionRepository repository;

  const SharePostContent({
    super.key,
    required this.postId,
    required this.repository,
  });

  @override
  State<SharePostContent> createState() => _SharePostContentState();
}

class _SharePostContentState extends State<SharePostContent> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<ShareContact> _contacts = const <ShareContact>[];
  bool _loading = true;
  bool _searchMode = false;
  bool _sending = false;
  int _searchToken = 0;

  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _messageController.addListener(_refresh);
  }

  List<ShareContact> _selectedFirst(List<ShareContact> source) {
    final selected = <ShareContact>[];
    final rest = <ShareContact>[];

    for (final contact in source) {
      if (_selectedIds.contains(contact.id)) {
        selected.add(contact);
      } else {
        rest.add(contact);
      }
    }

    return <ShareContact>[...selected, ...rest];
  }

  Future<void> _loadContacts() async {
    final contacts = await widget.repository.getShareContacts();
    if (!mounted) return;

    setState(() {
      _contacts = _selectedFirst(contacts);
      _loading = false;
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _toggleGridTarget(ShareContact contact) {
    HapticFeedback.selectionClick();

    setState(() {
      if (!_selectedIds.add(contact.id)) {
        _selectedIds.remove(contact.id);
      }
      _contacts = _selectedFirst(_contacts);
    });
  }

  Future<void> _selectFromSearch(ShareContact contact) async {
    HapticFeedback.selectionClick();

    if (_selectedIds.contains(contact.id)) {
      _selectedIds.remove(contact.id);
    } else {
      _selectedIds.add(contact.id);
    }

    _searchController.clear();
    _searchFocusNode.unfocus();

    setState(() {
      _loading = true;
    });

    final allContacts = await widget.repository.getShareContacts();
    if (!mounted) return;

    setState(() {
      // Trở về trang grid ngay sau khi chọn ở Search.
      // Target vừa chọn nằm trong nhóm selected nên tự được đẩy lên đầu.
      _contacts = _selectedFirst(allContacts);
      _searchMode = false;
      _loading = false;
    });
  }

  void _enterSearch() {
    setState(() {
      _searchMode = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  Future<void> _onSearchChanged(String value) async {
    final token = ++_searchToken;

    setState(() {
      _loading = true;
    });

    final results = await widget.repository.searchShareContacts(value);
    if (!mounted || token != _searchToken) return;

    setState(() {
      _contacts = results;
      _loading = false;
    });
  }

  Future<void> _cancelSearch() async {
    _searchController.clear();
    _searchFocusNode.unfocus();

    final contacts = await widget.repository.getShareContacts();
    if (!mounted) return;

    setState(() {
      _contacts = _selectedFirst(contacts);
      _searchMode = false;
      _loading = false;
    });
  }

  Future<void> _send() async {
    if (_selectedIds.isEmpty || _sending) return;

    HapticFeedback.selectionClick();

    setState(() {
      _sending = true;
    });

    await widget.repository.sharePost(
      postId: widget.postId,
      recipientIds: _selectedIds,
      message: _messageController.text.trim().isEmpty
          ? null
          : _messageController.text.trim(),
    );

    if (!mounted) return;

    final count = _selectedIds.length;
    Navigator.of(context).pop(count);
  }

  @override
  void dispose() {
    _messageController.removeListener(_refresh);
    _searchController.dispose();
    _messageController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final height = (screen.height * 0.61).clamp(410.0, 540.0).toDouble();

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Column(
        children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                screen.width * 0.055,
                0,
                screen.width * 0.055,
                screen.width * 0.025,
              ),
              child: _searchMode
                  ? GoMateSearchField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                hintText: 'Tìm liên hệ hoặc nhóm',
                onChanged: _onSearchChanged,
                showCancel: true,
                onCancel: _cancelSearch,
              )
                  : GoMateSearchField(
                hintText: 'Tìm liên hệ hoặc nhóm',
                readOnly: true,
                onTap: _enterSearch,
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : _contacts.isEmpty
                    ? Center(
                        child: Text(
                          'Không tìm thấy liên hệ hoặc nhóm.',
                          style: TextStyle(
                            fontSize: _font(screen.width, 12),
                            color: AppColors.grayText,
                          ),
                        ),
                      )
                    : _searchMode
                        ? ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              screen.width * 0.055,
                              screen.width * 0.020,
                              screen.width * 0.055,
                              screen.width * 0.030,
                            ),
                            itemCount: _contacts.length,
                            itemBuilder: (context, index) {
                              final contact = _contacts[index];

                              return _ShareSearchRow(
                                contact: contact,
                                selected: _selectedIds.contains(contact.id),
                                onTap: () => _selectFromSearch(contact),
                              );
                            },
                          )
                        : GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              screen.width * 0.055,
                              screen.width * 0.025,
                              screen.width * 0.055,
                              screen.width * 0.025,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.90,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 12,
                            ),
                            itemCount: _contacts.length,
                            itemBuilder: (context, index) {
                              final contact = _contacts[index];

                              return _ShareContactGridItem(
                                contact: contact,
                                selected: _selectedIds.contains(contact.id),
                                onTap: () => _toggleGridTarget(contact),
                              );
                            },
                          ),
          ),
          if (_selectedIds.isNotEmpty)
            _ShareMessageComposer(
              controller: _messageController,
              sending: _sending,
              selectedCount: _selectedIds.length,
              onSend: _send,
            ),
        ],
      ),
    );
  }
}

class _ShareContactGridItem extends StatelessWidget {
  final ShareContact contact;
  final bool selected;
  final VoidCallback onTap;

  const _ShareContactGridItem({
    required this.contact,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final avatar = (width * 0.145).clamp(52.0, 62.0).toDouble();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _ShareTargetAvatar(
                contact: contact,
                size: avatar,
              ),
              if (selected)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: avatar * 0.34,
                    height: avatar * 0.34,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryIcon,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.check,
                      size: avatar * 0.20,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: width * 0.012),
          Text(
            contact.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: _font(width, 10.5),
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareSearchRow extends StatelessWidget {
  final ShareContact contact;
  final bool selected;
  final VoidCallback onTap;

  const _ShareSearchRow({
    required this.contact,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final avatar = (width * 0.090).clamp(33.0, 38.0).toDouble();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: width * 0.020),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _ShareTargetAvatar(
                  contact: contact,
                  size: avatar,
                ),
                if (selected)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: avatar * 0.38,
                      height: avatar * 0.38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryIcon,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        LucideIcons.check,
                        size: avatar * 0.22,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: width * 0.030),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: TextStyle(
                      fontSize: _font(width, 12.5),
                      fontWeight: FontWeight.w500,
                      color: AppColors.black,
                    ),
                  ),
                  SizedBox(height: width * 0.006),
                  Text(
                    contact.subtitle,
                    style: TextStyle(
                      fontSize: _font(width, 10.5),
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

class _ShareMessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final int selectedCount;
  final VoidCallback onSend;

  const _ShareMessageComposer({
    required this.controller,
    required this.sending,
    required this.selectedCount,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(
        width * 0.055,
        width * 0.018,
        width * 0.055,
        width * 0.025,
      ),
      child: Container(
        constraints: BoxConstraints(
          minHeight: (width * 0.095).clamp(35.0, 40.0).toDouble(),
        ),
        padding: EdgeInsets.only(
          left: width * 0.030,
          right: width * 0.012,
        ),
        decoration: BoxDecoration(
          color: AppColors.grayBackground,
          borderRadius: BorderRadius.circular(
            (width * 0.040).clamp(14.0, 17.0).toDouble(),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                cursorColor: AppColors.primaryIcon,
                style: TextStyle(
                  fontSize: _font(width, 11.5),
                  color: AppColors.black,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Soạn tin nhắn',
                  hintStyle: TextStyle(
                    fontSize: _font(width, 11),
                    color: AppColors.grayText,
                  ),
                ),
              ),
            ),
            SizedBox(width: width * 0.018),
            InkWell(
              onTap: sending ? null : onSend,
              customBorder: const CircleBorder(),
              child: Container(
                width: (width * 0.066).clamp(24.0, 28.0).toDouble(),
                height: (width * 0.066).clamp(24.0, 28.0).toDouble(),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                alignment: Alignment.center,
                child: sending
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.7,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        LucideIcons.send,
                        size: (width * 0.034).clamp(13.0, 15.0).toDouble(),
                        color: Colors.white,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareTargetAvatar extends StatelessWidget {
  final ShareContact contact;
  final double size;

  const _ShareTargetAvatar({
    required this.contact,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (!contact.isGroup || contact.memberAvatarAssets.length < 2) {
      return _SingleShareAvatar(
        asset: contact.avatarAsset,
        size: size,
      );
    }

    final small = size * 0.68;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: _SingleShareAvatar(
              asset: contact.memberAvatarAssets[0],
              size: small,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _SingleShareAvatar(
              asset: contact.memberAvatarAssets[1],
              size: small,
            ),
          ),
        ],
      ),
    );
  }
}

class _SingleShareAvatar extends StatelessWidget {
  final String asset;
  final double size;

  const _SingleShareAvatar({
    required this.asset,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE7EBF3),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(
            LucideIcons.user,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

double _font(double width, double baseAt375) {
  final value = baseAt375 * (width / 375);
  return value.clamp(baseAt375 * 0.92, baseAt375 * 1.10).toDouble();
}
