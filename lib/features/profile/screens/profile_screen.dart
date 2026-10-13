import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/gomate_main_tab_header.dart';
import '../../map/screens/place_detail_screen.dart';
import '../../moments/data/moments_repository.dart';
import '../../moments/screens/moment_camera_screen.dart';
import '../../moments/screens/my_moments_screen.dart';
import '../../search/models/search_models.dart';
import '../widgets/profile_ui_widgets.dart';
import '../ui_preview/profile_ui_preview.dart';
import 'public_profile_screen.dart';
import 'profile_edit_screen.dart';
import 'profile_people_screen.dart';
import 'profile_post_feed_screen.dart';
import 'setting_screen.dart';

/// My profile - keeps the existing AuthService and FavoritePlaceStore contracts.
/// Production posts remain injected by caller. UI-preview posts are isolated
/// under ProfileUiPreview and shown only when there is no verified list.
class ProfileScreen extends StatefulWidget {
  final List<GoMateProfilePostPreview> posts;
  const ProfileScreen({super.key, this.posts = const []});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _tab = 0;
  final _auth = AuthService.instance;
  final _moments = ApiMomentsRepository.instance;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_refresh);
    _moments.addListener(_refresh);
    _auth.loadProfile().catchError((_) {});
  }

  @override
  void dispose() {
    _auth.removeListener(_refresh);
    _moments.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Map<String, dynamic> get _user => _auth.user ?? const {};
  String _text(Object? value) => value is String ? value.trim() : '';
  String get _nickname => _text(_user['nickname']).isNotEmpty
      ? _text(_user['nickname'])
      : 'GoMate';
  String get _name => _text(_user['fullName']).isNotEmpty
      ? _text(_user['fullName'])
      : (_text(_user['displayName']).isNotEmpty
          ? _text(_user['displayName'])
          : _nickname);
  String get _bio => _text(_user['bio']);
  String get _avatar => _text(_user['avatarUrl']);
  String get _userId => _text(_user['userId']).isNotEmpty
      ? _text(_user['userId'])
      : _text(_user['id']);

  int _count(String key) {
    final stats = _user['relationshipStats'];
    final value = stats is Map ? stats[key] : null;
    final actual = value is num ? value.toInt() : 0;
    // TODO(BACKEND-PROFILE-UI-PREVIEW): keep demo header stats consistent
    // with preview rows when a new account has no followers yet.
    if (actual == 0 && ProfileUiPreview.enabled) {
      if (key == 'followersCount') return ProfileUiPreview.followerRows.length;
      if (key == 'mutualFriendCount') return ProfileUiPreview.friendRows.length;
    }
    return actual;
  }

  List<MapPlaceUi> get _favorites {
    final seen = <String>{};
    final actual = FavoritePlaceStore.folders.values
        .expand((items) => items)
        .where((place) => seen.add(place.id))
        .toList(growable: false);
    // TODO(BACKEND-PROFILE-UI-PREVIEW): remove sample fallback.
    if (actual.isEmpty && ProfileUiPreview.enabled) {
      return ProfileUiPreview.favoritePlaces;
    }
    return actual;
  }

  List<GoMateProfilePostPreview> get _myPosts {
    final actual = widget.posts
        .where((post) => _userId.isNotEmpty && post.authorId == _userId)
        .toList(growable: false);
    // TODO(BACKEND-PROFILE-UI-PREVIEW): remove UI-only posts.
    if (actual.isEmpty && ProfileUiPreview.enabled) {
      return ProfileUiPreview.posts(
        authorId: _userId.isEmpty ? ProfileUiPreview.selfId : _userId,
        authorName: _name,
        authorAvatar: _avatar,
      );
    }
    return actual;
  }

  Future<void> _openMoments() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _moments.myMoments.isEmpty
          ? MomentCameraScreen(repository: _moments)
          : MyMomentsScreen(repository: _moments),
    ));
  }

  void _openEdit() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const ProfileEditScreen(),
    ));
  }

  void _openPeople(int tab) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ProfilePeopleScreen(
        nickname: _nickname,
        initialTab: tab,
        followersCount: _count('followersCount'),
        friendsCount: _count('mutualFriendCount'),
        usePreviewPeople: ProfileUiPreview.enabled,
      ),
    ));
  }

  // TODO(BACKEND-PROFILE-UI-PREVIEW): QA-only navigation; no mock IDs
  // are passed to SearchRepository or RealDirectMessageRepository.
  Future<void> _openPreviewProfiles() async {
    final selected = await GoMateBottomSheet.show<ProfilePreviewPerson>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Xem thử trang cá nhân',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                  color: AppColors.primaryText)),
          const SizedBox(height: 8),
          const Text('Dữ liệu mẫu chỉ để kiểm tra giao diện',
              style: TextStyle(fontSize: 12, color: AppColors.grayText)),
          const SizedBox(height: 12),
          for (final person in ProfileUiPreview.people)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: GoMateProfileAvatar(
                imageUrl: person.avatar, size: 38),
              title: Text(person.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              subtitle: Text(person.isPrivate
                  ? (person.initialRelation == SearchUserRelation.following
                      ? 'Riêng tư · đã chấp nhận theo dõi'
                      : 'Riêng tư · chưa theo dõi')
                  : 'Công khai',
                  style: const TextStyle(fontSize: 11, color: AppColors.grayText)),
              trailing: const Icon(LucideIcons.chevron_right,
                  size: 20, color: AppColors.primaryIcon),
              onTap: () => Navigator.of(context, rootNavigator: true).pop(person),
            ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PublicProfileScreen(
        userId: selected.id, previewPerson: selected),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = (width * 0.075).clamp(20.0, 30.0).toDouble();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header ở ngoài content padding: trùng chiều ngang với Home/Messages/Trip.
            SliverToBoxAdapter(child: _topBar()),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontal),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _identity(),
                    if (_bio.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_bio,
                            style: const TextStyle(
                                fontSize: 12, height: 1.35, color: Colors.black)),
                      ),
                    ],
                    // Backend currently returns no profile-link field.
                    // Do not render a fictional 'Thêm liên kết' in view mode.
                    const SizedBox(height: 15),
                    _button(
                      title: 'Chỉnh sửa hồ sơ',
                      icon: LucideIcons.pen_line,
                      onTap: _openEdit,
                    ),
                    if (ProfileUiPreview.enabled) ...[
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: _openPreviewProfiles,
                        icon: const Icon(LucideIcons.eye, size: 16),
                        label: const Text('Xem thử hồ sơ người khác · Demo UI'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryIcon,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: GoMateProfileTabs(
                selectedIndex: _tab,
                onSelected: (tab) => setState(() => _tab = tab),
              ),
            ),
            if (_tab == 0) _postsSliver() else _favoritesSliver(),
            SliverToBoxAdapter(
              child: SizedBox(height: (bottomInset + 115).clamp(110, 155).toDouble()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() => GoMateMainTabHeader(
    title: _nickname,
    leadingIcon: LucideIcons.plus,
    // UI ONLY: tạo bài viết chưa có route; tuyệt đối không mở camera Moments.
    onLeadingTap: null,
    trailingIcon: LucideIcons.menu,
    onTrailingTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const SettingsScreen(),
    )),
  );

  Widget _identity() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GoMateProfileAvatar(
          size: 62,
          imageUrl: _avatar,
          showAdd: true,
          onTap: _openMoments,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Expanded(child: GoMateProfileStat(
                    value: _count('followersCount'),
                    label: 'Người theo dõi',
                    onTap: () => _openPeople(0),
                  )),
                  const SizedBox(width: 9),
                  Expanded(child: GoMateProfileStat(
                    value: _count('mutualFriendCount'),
                    label: 'Bạn bè',
                    onTap: () => _openPeople(1),
                  )),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _button({required String title, IconData? icon, required VoidCallback onTap}) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          constraints: const BoxConstraints(minWidth: 160),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(color: Color(0x16000000), blurRadius: 5, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppColors.primaryIcon),
                const SizedBox(width: 5),
              ],
              Text(title,
                  style: const TextStyle(
                      color: AppColors.primaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _postsSliver() {
    final posts = _myPosts;
    if (posts.isEmpty) {
      return const SliverToBoxAdapter(
        child: GoMateProfileEmpty(
          icon: LucideIcons.images,
          title: 'Chưa có bài viết',
          description: 'Chia sẻ những chuyến đi của bạn tại đây.',
        ),
      );
    }
    return SliverGrid.builder(
      itemCount: posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final post = posts[index];
        return InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => GoMateProfilePostFeedScreen(posts: posts, initialIndex: index),
          )),
          child: _image(post.media.isEmpty ? '' : post.media.first),
        );
      },
    );
  }

  Widget _favoritesSliver() {
    final places = _favorites;
    if (places.isEmpty) {
      return const SliverToBoxAdapter(
        child: GoMateProfileEmpty(
          icon: LucideIcons.heart,
          title: 'Chưa có địa điểm yêu thích',
          description: 'Những địa điểm được lưu trong ứng dụng sẽ xuất hiện ở đây.',
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      sliver: SliverList.builder(
        itemCount: places.length,
        itemBuilder: (context, index) {
          final place = places[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                // Reuse the current PlaceDetailScreen for UI preview.
                // Do not execute itinerary/share API actions with mock place IDs.
                builder: (_) => PlaceDetailScreen(place: place),
              )).then((_) => _refresh()),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Color(0x16000000), blurRadius: 7, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 65,
                      height: 64,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _image(place.imageUrl ?? place.imageAsset ?? ''),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(place.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(place.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF828282))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _image(String source) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(source, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback());
    }
    if (source.isNotEmpty) {
      return Image.asset(source, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback());
    }
    return _fallback();
  }

  Widget _fallback() => const ColoredBox(
        color: Color(0xFFE8EDF6),
        child: Center(child: Icon(LucideIcons.image, color: Color(0xFF828282))),
      );
}
