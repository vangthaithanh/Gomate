import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../theme/app_colors.dart';
import 'gomate_search_field.dart';

/// DTO UI dùng chung cho popup mời thành viên.
///
/// Cố tình không phụ thuộc MessageContact/Trip model để:
/// - Trip dùng được.
/// - Messenger dùng được.
/// - Không tạo dependency chéo giữa features.
class GoMateInviteContact {
  final String id;
  final String name;
  final String subtitle;
  final String? avatarAsset;

  const GoMateInviteContact({
    required this.id,
    required this.name,
    required this.subtitle,
    this.avatarAsset,
  });
}

/// Popup mời thành viên dùng chung cho Trip + Messenger.
///
/// Business/UI contract:
/// - Người đã accepted nằm trong [excludedContactIds] và không xuất hiện.
/// - Người đang pending luôn nằm trên đầu.
/// - Pending có thể hiện "Huỷ lời mời" hoặc "Đã mời" tùy quyền.
/// - Người mới chọn hiển thị chip ở trên.
/// - Nút "(n) Thêm" nằm bên phải khu vực selected.
/// - Sau khi bấm Thêm, selected chuyển ngay sang pending ở UI.
/// - Search áp dụng cho cả pending + candidate.
///
/// Backend behavior do caller quyết định:
/// - Create Trip: chỉ lưu draft pending, chưa gửi notification.
/// - Messenger/group đã tồn tại: tạo pending invite ngay; backend sau này
///   gửi notification ngay.
class GoMateMemberInviteContent extends StatefulWidget {
  final List<GoMateInviteContact> contacts;

  final Set<String> pendingInviteIds;
  final Set<String> excludedContactIds;

  final bool canCancelPending;
  final String pendingDisabledLabel;

  final FutureOr<void> Function(Set<String> contactIds) onAddInvites;
  final FutureOr<void> Function(String contactId)? onCancelPending;

  final String title;
  final String searchHint;

  const GoMateMemberInviteContent({
    super.key,
    required this.contacts,
    required this.pendingInviteIds,
    required this.excludedContactIds,
    required this.onAddInvites,
    this.onCancelPending,
    this.canCancelPending = true,
    this.pendingDisabledLabel = 'Đã mời',
    this.title = 'Mời thêm thành viên',
    this.searchHint = 'Tìm kiếm ....',
  });

  @override
  State<GoMateMemberInviteContent> createState() =>
      _GoMateMemberInviteContentState();
}

class _GoMateMemberInviteContentState
    extends State<GoMateMemberInviteContent> {
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedNew = <String>{};
  late Set<String> _optimisticPending;

  @override
  void initState() {
    super.initState();
    _optimisticPending = <String>{...widget.pendingInviteIds};
  }

  @override
  void didUpdateWidget(
    covariant GoMateMemberInviteContent oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    // Đồng bộ source-of-truth bên ngoài nhưng vẫn giữ UI phản hồi tức thì.
    if (!_sameSet(oldWidget.pendingInviteIds, widget.pendingInviteIds)) {
      _optimisticPending = <String>{...widget.pendingInviteIds};
      _selectedNew.removeWhere(_optimisticPending.contains);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesQuery(GoMateInviteContact contact) {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) return true;

    return contact.name.toLowerCase().contains(query) ||
        contact.subtitle.toLowerCase().contains(query);
  }

  List<GoMateInviteContact> get _pendingContacts {
    return widget.contacts
        .where(
          (contact) =>
              _optimisticPending.contains(contact.id) &&
              !widget.excludedContactIds.contains(contact.id) &&
              _matchesQuery(contact),
        )
        .toList(growable: false);
  }

  List<GoMateInviteContact> get _candidateContacts {
    return widget.contacts
        .where(
          (contact) =>
              !widget.excludedContactIds.contains(contact.id) &&
              !_optimisticPending.contains(contact.id) &&
              _matchesQuery(contact),
        )
        .toList(growable: false);
  }

  List<GoMateInviteContact> get _selectedContacts {
    final byId = <String, GoMateInviteContact>{
      for (final contact in widget.contacts) contact.id: contact,
    };

    return _selectedNew
        .map((id) => byId[id])
        .whereType<GoMateInviteContact>()
        .toList(growable: false);
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedNew.contains(id)) {
        _selectedNew.remove(id);
      } else {
        _selectedNew.add(id);
      }
    });
  }

  Future<void> _commitSelected() async {
    if (_selectedNew.isEmpty) return;

    final ids = <String>{..._selectedNew};

    setState(() {
      _optimisticPending.addAll(ids);
      _selectedNew.clear();
    });

    await widget.onAddInvites(ids);
  }

  Future<void> _cancelPending(String id) async {
    if (!widget.canCancelPending || widget.onCancelPending == null) {
      return;
    }

    setState(() {
      _optimisticPending.remove(id);
    });

    await widget.onCancelPending!(id);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    final selectedContacts = _selectedContacts;
    final pendingContacts = _pendingContacts;
    final candidates = _candidateContacts;

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: _c(width * 0.042, 15, 17),
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),

          SizedBox(height: width * 0.025),

          GoMateSearchField(
            controller: _searchController,
            hintText: widget.searchHint,
            onChanged: (_) => setState(() {}),
          ),

          if (selectedContacts.isNotEmpty) ...[
            SizedBox(height: width * 0.020),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    height: _c(width * 0.19, 66, 76),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: selectedContacts.length,
                      separatorBuilder: (_, __) =>
                          SizedBox(width: width * 0.025),
                      itemBuilder: (context, index) {
                        final contact = selectedContacts[index];

                        return _SelectedContact(
                          contact: contact,
                          onRemove: () => _toggleSelected(contact.id),
                        );
                      },
                    ),
                  ),
                ),

                SizedBox(width: width * 0.020),

                InkWell(
                  onTap: _commitSelected,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      width * 0.010,
                      width * 0.010,
                      width * 0.004,
                      width * 0.010,
                    ),
                    child: Text(
                      '(${selectedContacts.length}) Thêm',
                      style: TextStyle(
                        fontSize: _c(width * 0.028, 10, 11.5),
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          SizedBox(height: width * 0.012),

          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.42,
            ),
            child: ListView(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              children: [
                // Pending luôn ở đầu danh sách.
                for (final contact in pendingContacts)
                  _InviteRow(
                    contact: contact,
                    selected: false,
                    isPending: true,
                    canCancelPending: widget.canCancelPending,
                    pendingDisabledLabel: widget.pendingDisabledLabel,
                    onTap: null,
                    onCancelPending: widget.canCancelPending
                        ? () => _cancelPending(contact.id)
                        : null,
                  ),

                for (final contact in candidates)
                  _InviteRow(
                    contact: contact,
                    selected: _selectedNew.contains(contact.id),
                    isPending: false,
                    canCancelPending: false,
                    pendingDisabledLabel: widget.pendingDisabledLabel,
                    onTap: () => _toggleSelected(contact.id),
                    onCancelPending: null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static bool _sameSet(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  static double _c(
    double value,
    double min,
    double max,
  ) {
    return value.clamp(min, max).toDouble();
  }
}

class _SelectedContact extends StatelessWidget {
  final GoMateInviteContact contact;
  final VoidCallback onRemove;

  const _SelectedContact({
    required this.contact,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final avatar = _GoMateMemberInviteContentState._c(
      width * 0.105,
      38,
      44,
    );

    return SizedBox(
      width: avatar + 14,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _InviteAvatar(
                contact: contact,
                size: avatar,
              ),
              Positioned(
                right: -2,
                top: -2,
                child: InkWell(
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 17,
                    height: 17,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryIcon,
                    ),
                    child: const Icon(
                      LucideIcons.x,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            contact.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _GoMateMemberInviteContentState._c(
                width * 0.026,
                9.5,
                10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteRow extends StatelessWidget {
  final GoMateInviteContact contact;
  final bool selected;
  final bool isPending;
  final bool canCancelPending;
  final String pendingDisabledLabel;
  final VoidCallback? onTap;
  final VoidCallback? onCancelPending;

  const _InviteRow({
    required this.contact,
    required this.selected,
    required this.isPending,
    required this.canCancelPending,
    required this.pendingDisabledLabel,
    required this.onTap,
    required this.onCancelPending,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: _GoMateMemberInviteContentState._c(
            width * 0.016,
            6,
            7,
          ),
        ),
        child: Row(
          children: [
            _InviteAvatar(
              contact: contact,
              size: _GoMateMemberInviteContentState._c(
                width * 0.090,
                32,
                38,
              ),
            ),

            SizedBox(width: width * 0.028),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: TextStyle(
                      fontSize: _GoMateMemberInviteContentState._c(
                        width * 0.031,
                        11,
                        12.5,
                      ),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    contact.subtitle,
                    style: TextStyle(
                      fontSize: _GoMateMemberInviteContentState._c(
                        width * 0.026,
                        9.5,
                        10.5,
                      ),
                      color: AppColors.grayText,
                    ),
                  ),
                ],
              ),
            ),

            if (isPending)
              InkWell(
                onTap: onCancelPending,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.010,
                    vertical: width * 0.010,
                  ),
                  child: Text(
                    canCancelPending
                        ? 'Huỷ lời mời'
                        : pendingDisabledLabel,
                    style: TextStyle(
                      fontSize: _GoMateMemberInviteContentState._c(
                        width * 0.026,
                        9.5,
                        10.5,
                      ),
                      fontWeight: FontWeight.w600,
                      color: canCancelPending
                          ? AppColors.primaryText
                          : AppColors.grayText,
                    ),
                  ),
                ),
              )
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppColors.primaryIcon
                      : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? AppColors.primaryIcon
                        : AppColors.grayBorder,
                  ),
                ),
                child: selected
                    ? const Icon(
                        LucideIcons.check,
                        size: 13,
                        color: Colors.white,
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _InviteAvatar extends StatelessWidget {
  final GoMateInviteContact contact;
  final double size;

  const _InviteAvatar({
    required this.contact,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final asset = contact.avatarAsset;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x1A0A43A8),
        border: Border.all(
          color: AppColors.grayBorder,
        ),
      ),
      child: asset == null || asset.trim().isEmpty
          ? Icon(
              LucideIcons.user_round,
              size: size * 0.55,
              color: Colors.white,
            )
          : Image.asset(
              asset,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                LucideIcons.user_round,
                size: size * 0.55,
                color: Colors.white,
              ),
            ),
    );
  }
}
