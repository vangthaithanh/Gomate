import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/gomate_search_field.dart';
import '../../../core/widgets/snackbar.dart';
import '../../search/data/search_repository.dart';
import '../../search/models/search_models.dart';
import '../widgets/profile_ui_widgets.dart';
import '../ui_preview/profile_ui_preview.dart';
import 'public_profile_screen.dart';

/// Followers/friends view. Backend-provided rows are used when preview=false.
/// TODO(BACKEND-PROFILE-UI-PREVIEW): remove preview-only rows and flag.
class ProfilePeopleScreen extends StatefulWidget {
  final String nickname;
  final String? userId;
  final int initialTab;
  final int followersCount;
  final int friendsCount;
  final List<SearchUserItem> followers;
  final List<SearchUserItem> friends;
  final bool usePreviewPeople;

  const ProfilePeopleScreen({
    super.key,
    required this.nickname,
    this.userId,
    this.initialTab = 0,
    this.followersCount = 0,
    this.friendsCount = 0,
    this.followers = const [],
    this.friends = const [],
    this.usePreviewPeople = false,
  });

  @override
  State<ProfilePeopleScreen> createState() => _ProfilePeopleScreenState();
}

class _ProfilePeopleScreenState extends State<ProfilePeopleScreen> {
  late int _tab;
  final _searchController = TextEditingController();
  final _repository = SearchRepository();
  final _relationChanges = <String, SearchUserRelation>{};
  final _busy = <String>{};
  String _query = '';
  List<SearchUserItem> _actualFollowers = const [];
  List<SearchUserItem> _actualFriends = const [];
  bool _loading = false;
  String? _error;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_preview) return;
    final id =
        widget.userId ??
        (AuthService.instance.user?['userId'] ??
                AuthService.instance.user?['id'])
            ?.toString();
    if (id == null || ProfileUiPreview.isPreviewId(id)) return;
    final version = ++_loadVersion;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Future<List<SearchUserItem>> all(bool friends) async {
        final items = <SearchUserItem>[];
        var page = 0;
        while (true) {
          final result = await _repository.profilePeople(
            userId: id,
            friends: friends,
            page: page++,
          );
          items.addAll(result.items);
          if (result.items.isEmpty || items.length >= result.total)
            return items;
        }
      }

      final lists = await Future.wait([all(false), all(true)]);
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _actualFollowers = lists[0];
        _actualFriends = lists[1];
        _relationChanges.clear();
      });
    } catch (_) {
      if (mounted && version == _loadVersion)
        setState(() => _error = 'Không tải được danh sách người dùng.');
    } finally {
      if (mounted && version == _loadVersion) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _preview => ProfileUiPreview.enabled && widget.usePreviewPeople;

  List<SearchUserItem> get _followers => _preview
      ? ProfileUiPreview.followerRows
      : widget.userId == null
      ? widget.followers
      : _actualFollowers;

  List<SearchUserItem> get _friends => _preview
      ? ProfileUiPreview.friendRows
      : widget.userId == null
      ? widget.friends
      : _actualFriends;

  List<SearchUserItem> get _visible {
    final source = _tab == 0 ? _followers : _friends;
    final q = _query.trim().toLowerCase();
    return source
        .where(
          (item) =>
              q.isEmpty ||
              item.name.toLowerCase().contains(q) ||
              item.subtitle.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  bool _isFollowing(SearchUserRelation relation) =>
      relation == SearchUserRelation.friend ||
      relation == SearchUserRelation.following;

  Future<void> _changeFollow(SearchUserItem user) async {
    if (_preview && ProfileUiPreview.isPreviewId(user.id)) {
      // TODO(BACKEND): chỉ đổi trạng thái UI, tuyệt đối KHÔNG gọi API bằng ID mẫu.
      final current = _relationChanges[user.id] ?? user.relation;
      setState(
        () => _relationChanges[user.id] = _isFollowing(current)
            ? SearchUserRelation.none
            : SearchUserRelation.following,
      );
      return;
    }
    if (ProfileUiPreview.isPreviewId(user.id)) {
      // A mock ID must never be submitted to a real follow endpoint.
      GoMateSnackBar.show(context, message: 'Đây là người dùng mẫu.');
      return;
    }
    if (!_busy.add(user.id)) return;
    setState(() {});
    try {
      final current = _relationChanges[user.id] ?? user.relation;
      final next =
          _isFollowing(current) || current == SearchUserRelation.pending
          ? await _repository.unfollowUser(user.id)
          : await _repository.followUser(user.id);
      if (!mounted) return;
      setState(() => _relationChanges[user.id] = next);
      await AuthService.instance.loadProfile().catchError((_) {});
      await _load();
      if (mounted)
        GoMateSnackBar.show(
          context,
          message: next == SearchUserRelation.pending
              ? 'Đã gửi yêu cầu theo dõi'
              : current == SearchUserRelation.pending
              ? 'Đã hủy yêu cầu theo dõi'
              : _isFollowing(current)
              ? 'Đã bỏ theo dõi'
              : 'Đã theo dõi',
        );
    } catch (_) {
      if (!mounted) return;
      GoMateSnackBar.show(
        context,
        message: 'Không thể cập nhật theo dõi lúc này.',
      );
    } finally {
      _busy.remove(user.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final padding = (width * 0.075).clamp(20.0, 30.0).toDouble();
    final items = _visible;
    final sourceEmpty = _tab == 0 ? _followers.isEmpty : _friends.isEmpty;
    final followersCount = widget.userId != null || _preview
        ? _followers.length
        : widget.followersCount;
    final friendsCount = widget.userId != null || _preview
        ? _friends.length
        : widget.friendsCount;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            GoMateProfilePageHeader(title: widget.nickname),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Row(
                children: [
                  _tabButton(0, '$followersCount Người theo dõi'),
                  _tabButton(1, '$friendsCount Bạn bè'),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(padding, 8, padding, 10),
              child: GoMateSearchField(
                controller: _searchController,
                hintText: 'Tìm...',
                showCancel: _query.isNotEmpty,
                onChanged: (value) => setState(() => _query = value),
                onCancel: () {
                  _searchController.clear();
                  FocusScope.of(context).unfocus();
                  setState(() => _query = '');
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryIcon,
                      ),
                    )
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    )
                  : sourceEmpty
                  ? GoMateProfileEmpty(
                      icon: LucideIcons.users_round,
                      title: _tab == 0
                          ? 'Chưa có người theo dõi'
                          : 'Chưa có bạn bè',
                    )
                  : items.isEmpty
                  ? const GoMateProfileEmpty(
                      icon: LucideIcons.search,
                      title: 'Không tìm thấy người dùng',
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final relation =
                            _relationChanges[item.id] ?? item.relation;
                        final followed = _isFollowing(relation);
                        final ownId =
                            (AuthService.instance.user?['userId'] ??
                                    AuthService.instance.user?['id'])
                                ?.toString();
                        final showAction =
                            item.id != ownId && (_tab == 1 || !followed);
                        return Padding(
                          padding: EdgeInsets.fromLTRB(padding, 8, padding, 10),
                          child: InkWell(
                            onTap: () {
                              // Preview IDs only ever reach the in-memory
                              // PublicProfileScreen preview adapter, never API.
                              final preview = _preview
                                  ? ProfileUiPreview.findPerson(item.id)
                                  : null;
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => PublicProfileScreen(
                                        userId: item.id,
                                        previewPerson: preview,
                                      ),
                                    ),
                                  )
                                  .then((_) {
                                    if (mounted) unawaited(_load());
                                  });
                            },
                            child: Row(
                              children: [
                                GoMateProfileAvatar(
                                  imageUrl: item.avatarUrl ?? item.avatarAsset,
                                  size: (width * 0.112)
                                      .clamp(40.0, 46.0)
                                      .toDouble(),
                                ),
                                SizedBox(
                                  width: (width * 0.030)
                                      .clamp(10.0, 13.0)
                                      .toDouble(),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Text(
                                        item.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF828282),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (showAction)
                                  TextButton(
                                    onPressed: _busy.contains(item.id)
                                        ? null
                                        : () => _changeFollow(item),
                                    child: Text(
                                      relation == SearchUserRelation.pending
                                          ? 'Hủy yêu cầu'
                                          : followed
                                          ? 'Bỏ theo dõi'
                                          : (_tab == 0
                                                ? 'Theo dõi lại'
                                                : 'Theo dõi'),
                                      style: const TextStyle(
                                        color: AppColors.primaryText,
                                        fontSize: 12.5,
                                      ),
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

  Widget _tabButton(int index, String text) {
    final selected = _tab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: (MediaQuery.sizeOf(context).width * 0.037)
                  .clamp(13.0, 15.0)
                  .toDouble(),
              fontWeight: FontWeight.w700,
              color: selected ? Colors.black : const Color(0xFF828282),
            ),
          ),
        ),
      ),
    );
  }
}
