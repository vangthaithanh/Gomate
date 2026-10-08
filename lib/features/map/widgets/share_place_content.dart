import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../home/data/post_interaction_repository.dart';
import '../../home/models/post_interaction_models.dart';

/// UI chia sẻ địa điểm dùng đúng interaction pattern của Share Post:
/// - user + group;
/// - multi-select;
/// - search realtime;
/// - chọn từ search => quay về grid, target selected được đẩy lên đầu;
/// - composer chỉ hiện khi có selection.
///
/// Backend share place chưa có contract riêng nên widget chỉ trả số target đã chọn.
class SharePlaceContent extends StatefulWidget {
  final String placeId;
  final String placeName;
  final PostInteractionRepository repository;

  const SharePlaceContent({
    super.key,
    required this.placeId,
    required this.placeName,
    required this.repository,
  });

  @override
  State<SharePlaceContent> createState() => _SharePlaceContentState();
}

class _SharePlaceContentState extends State<SharePlaceContent> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<ShareContact> _contacts = const <ShareContact>[];
  final Set<String> _selectedIds = <String>{};

  bool _loading = true;
  bool _searchMode = false;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _messageController.addListener(_refresh);
  }

  @override
  void dispose() {
    _messageController.removeListener(_refresh);
    _searchController.dispose();
    _messageController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
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

  void _toggle(ShareContact contact) {
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
    setState(() => _loading = true);

    final all = await widget.repository.getShareContacts();
    if (!mounted) return;

    setState(() {
      _contacts = _selectedFirst(all);
      _searchMode = false;
      _loading = false;
    });
  }

  void _enterSearch() {
    setState(() => _searchMode = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  Future<void> _search(String value) async {
    final token = ++_searchToken;
    setState(() => _loading = true);

    final result = await widget.repository.searchShareContacts(value);
    if (!mounted || token != _searchToken) return;

    setState(() {
      _contacts = result;
      _loading = false;
    });
  }

  Future<void> _cancelSearch() async {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() => _loading = true);

    final all = await widget.repository.getShareContacts();
    if (!mounted) return;

    setState(() {
      _contacts = _selectedFirst(all);
      _searchMode = false;
      _loading = false;
    });
  }

  void _send() {
    if (_selectedIds.isEmpty) return;
    HapticFeedback.selectionClick();

    // TODO(backend): thêm endpoint sharePlace(placeId, recipients, message).
    // Task này không thay đổi backend nên chỉ trả selection cho caller.
    Navigator.of(context).pop(_selectedIds.length);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final height = (size.height * 0.61).clamp(410.0, 540.0).toDouble();

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Column(
        children: [
          if (_searchMode)
            _SearchBar(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _search,
              onCancel: _cancelSearch,
            )
          else
            Padding(
              padding: EdgeInsets.fromLTRB(
                size.width * 0.055,
                0,
                size.width * 0.055,
                size.width * 0.025,
              ),
              child: InkWell(
                onTap: _enterSearch,
                borderRadius: BorderRadius.circular(
                  (size.width * 0.040).clamp(14.0, 17.0).toDouble(),
                ),
                child: Container(
                  height: (size.width * 0.095).clamp(35.0, 40.0).toDouble(),
                  padding: EdgeInsets.symmetric(horizontal: size.width * 0.030),
                  decoration: BoxDecoration(
                    color: AppColors.grayBackground,
                    borderRadius: BorderRadius.circular(
                      (size.width * 0.040).clamp(14.0, 17.0).toDouble(),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.search,
                        size: (size.width * 0.048).clamp(18.0, 21.0).toDouble(),
                        color: AppColors.grayText,
                      ),
                      SizedBox(width: size.width * 0.018),
                      Text(
                        'Tìm liên hệ hoặc nhóm',
                        style: TextStyle(
                          fontSize:
                              (size.width * 0.033).clamp(12.0, 13.5).toDouble(),
                          fontWeight: FontWeight.w500,
                          color: AppColors.grayText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : _searchMode
                    ? _SearchResults(
                        contacts: _contacts,
                        selectedIds: _selectedIds,
                        onTap: _selectFromSearch,
                      )
                    : _TargetGrid(
                        contacts: _contacts,
                        selectedIds: _selectedIds,
                        onTap: _toggle,
                      ),
          ),
          if (!_searchMode && _selectedIds.isNotEmpty)
            _Composer(
              controller: _messageController,
              onSend: _send,
            ),
        ],
      ),
    );
  }
}

class _TargetGrid extends StatelessWidget {
  final List<ShareContact> contacts;
  final Set<String> selectedIds;
  final ValueChanged<ShareContact> onTap;

  const _TargetGrid({
    required this.contacts,
    required this.selectedIds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        width * 0.055,
        width * 0.020,
        width * 0.055,
        width * 0.035,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.83,
      ),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return _GridTarget(
          contact: contact,
          selected: selectedIds.contains(contact.id),
          onTap: () => onTap(contact),
        );
      },
    );
  }
}

class _GridTarget extends StatelessWidget {
  final ShareContact contact;
  final bool selected;
  final VoidCallback onTap;

  const _GridTarget({
    required this.contact,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final avatarSize = (width * 0.17).clamp(58.0, 70.0).toDouble();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _TargetAvatar(contact: contact, size: avatarSize),
              if (selected)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 23,
                    height: 23,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryIcon,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      LucideIcons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: width * 0.020),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.012),
            child: Text(
              contact.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: (width * 0.029).clamp(10.5, 12.0).toDouble(),
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<ShareContact> contacts;
  final Set<String> selectedIds;
  final ValueChanged<ShareContact> onTap;

  const _SearchResults({
    required this.contacts,
    required this.selectedIds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        width * 0.055,
        width * 0.010,
        width * 0.055,
        width * 0.035,
      ),
      itemCount: contacts.length,
      separatorBuilder: (_, __) => SizedBox(height: width * 0.020),
      itemBuilder: (context, index) {
        final contact = contacts[index];
        final selected = selectedIds.contains(contact.id);
        return InkWell(
          onTap: () => onTap(contact),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: width * 0.010),
            child: Row(
              children: [
                _TargetAvatar(
                  contact: contact,
                  size: (width * 0.115).clamp(40.0, 47.0).toDouble(),
                ),
                SizedBox(width: width * 0.030),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: TextStyle(
                          fontSize:
                              (width * 0.034).clamp(12.5, 14.0).toDouble(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: width * 0.005),
                      Text(
                        contact.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize:
                              (width * 0.028).clamp(10.5, 11.8).toDouble(),
                          color: AppColors.grayText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryIcon,
                    ),
                    child: const Icon(
                      LucideIcons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TargetAvatar extends StatelessWidget {
  final ShareContact contact;
  final double size;

  const _TargetAvatar({
    required this.contact,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (contact.isGroup && contact.memberAvatarAssets.length >= 2) {
      final small = size * 0.68;
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: _AssetAvatar(
                asset: contact.memberAvatarAssets[0],
                size: small,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: _AssetAvatar(
                asset: contact.memberAvatarAssets[1],
                size: small,
              ),
            ),
          ],
        ),
      );
    }

    return _AssetAvatar(asset: contact.avatarAsset, size: size);
  }
}

class _AssetAvatar extends StatelessWidget {
  final String asset;
  final double size;

  const _AssetAvatar({
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
        color: AppColors.blue50,
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          LucideIcons.user_round,
          color: AppColors.grayText,
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onCancel;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        width * 0.055,
        0,
        width * 0.055,
        width * 0.025,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: (width * 0.095).clamp(35.0, 40.0).toDouble(),
              padding: EdgeInsets.symmetric(horizontal: width * 0.030),
              decoration: BoxDecoration(
                color: AppColors.grayBackground,
                borderRadius: BorderRadius.circular(
                  (width * 0.040).clamp(14.0, 17.0).toDouble(),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.search,
                    size: (width * 0.048).clamp(18.0, 21.0).toDouble(),
                    color: AppColors.grayText,
                  ),
                  SizedBox(width: width * 0.018),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      cursorColor: AppColors.primaryIcon,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: 'Tìm liên hệ hoặc nhóm',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: width * 0.030),
          InkWell(
            onTap: onCancel,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Huỷ',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        width * 0.055,
        width * 0.020,
        width * 0.055,
        width * 0.025,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: EdgeInsets.symmetric(horizontal: width * 0.035),
              decoration: BoxDecoration(
                color: AppColors.grayBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: TextField(
                controller: controller,
                maxLines: 3,
                minLines: 1,
                cursorColor: AppColors.primaryIcon,
                decoration: const InputDecoration(
                  hintText: 'Soạn tin nhắn',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          SizedBox(width: width * 0.025),
          InkWell(
            onTap: onSend,
            customBorder: const CircleBorder(),
            child: Container(
              width: (width * 0.105).clamp(38.0, 44.0).toDouble(),
              height: (width * 0.105).clamp(38.0, 44.0).toDouble(),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
              ),
              child: const Icon(
                LucideIcons.send,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
