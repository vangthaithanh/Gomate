import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/gomate_main_tab_header.dart';
import '../../../core/widgets/gomate_member_invite_content.dart';
import '../../../core/widgets/snackbar.dart';
import '../../map/data/spring_map_gateway.dart';
import '../../map/models/map_place.dart';
import '../../map/screens/map_place_search_screen.dart';
import '../../map/state/map_ui_session.dart';
import '../../messages/data/message_repository.dart';
import '../ui_preview/post_ui_demo_store.dart';
import '../widgets/post_audience_content.dart';
import '../widgets/post_hashtag_content.dart';
import '../widgets/post_media_widget.dart';

/// UI-only flow: gallery -> compose -> post to in-memory demo store.
/// TODO(BACKEND-CREATE-POST): replace demo gallery/storage with media upload and
/// posts API. Keep navigation, selected media, hashtags, privacy and tag UI.
class GoMateCreatePostScreen extends StatefulWidget {
  const GoMateCreatePostScreen({super.key});
  @override
  State<GoMateCreatePostScreen> createState() => _GoMateCreatePostScreenState();
}

class _GoMateCreatePostScreenState extends State<GoMateCreatePostScreen> {
  final _caption = TextEditingController();
  final List<String> _selected = [];
  final List<GoMateDemoMediaItem> _gallery = List.of(goMateDemoGallery);
  final List<String> _hashtags = [];
  final Set<String> _taggedUsers = {};
  GoMatePostAudience _audience = GoMatePostAudience.followers;
  GoMateMapPlace? _place;
  bool _multiSelect = false;
  bool _composing = false;
  bool _sharing = false;
  String? _latestPreview;

  @override
  void initState() {
    super.initState();
    _latestPreview = _gallery.first.source;
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  void _toggleMedia(String source) {
    setState(() {
      if (_selected.contains(source)) {
        _selected.remove(source);
        _latestPreview = _selected.isNotEmpty ? _selected.last : _gallery.first.source;
      } else if (_multiSelect) {
        if (_selected.length >= 12) {
          GoMateSnackBar.show(context, message: 'Tối đa 12 ảnh hoặc video');
          return;
        }
        _selected.add(source);
        _latestPreview = source;
      } else {
        _selected..clear()..add(source);
        _latestPreview = source;
      }
    });
  }

  Future<void> _deviceGallery() async {
    // Uses existing image_picker dependency, never uploads anything.
    // TODO(BACKEND-CREATE-POST): replace with a dedicated system album provider.
    try {
      final files = await ImagePicker().pickMultipleMedia();
      if (!mounted || files.isEmpty) return;
      setState(() {
        _multiSelect = true;
        for (final x in files) {
          final isVideo = RegExp(r'\.(mp4|mov|m4v|avi|webm)$', caseSensitive: false)
              .hasMatch(x.path);
          final source = isVideo ? 'video-file:${x.path}' : Uri.file(x.path).toString();
          if (!_gallery.any((e) => e.source == source)) {
            _gallery.insert(0, GoMateDemoMediaItem(source, isVideo: isVideo));
          }
          if (_selected.length < 12 && !_selected.contains(source)) {
            _selected.add(source);
            _latestPreview = source;
          }
        }
      });
      if (files.length > 12) {
        GoMateSnackBar.show(context, message: 'Chỉ chọn tối đa 12 ảnh/video đầu tiên');
      }
    } catch (_) {
      if (mounted) GoMateSnackBar.show(context,
        message: 'Chưa mở được thư viện thiết bị. Bạn có thể thử ảnh mẫu.');
    }
  }

  void _next() {
    if (_selected.isEmpty) {
      GoMateSnackBar.show(context, message: 'Chọn ít nhất một ảnh hoặc video');
      return;
    }
    setState(() => _composing = true);
  }

  Future<bool> _confirmExit() async {
    if (_selected.isEmpty && _caption.text.isEmpty) return true;
    return await GoMateBottomSheet.show<bool>(
      context: context,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Bỏ bài viết đang tạo?', style: TextStyle(fontSize: 16,
          color: AppColors.primaryText, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        const Text('Ảnh đã chọn và nội dung chưa chia sẻ sẽ không được lưu.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.grayText)),
        const SizedBox(height: 18),
        _gradientButton('Bỏ bài viết', () => Navigator.of(context).pop(true)),
        TextButton(onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Tiếp tục chỉnh sửa')),
      ]),
    ) ?? false;
  }

  Future<void> _back() async {
    if (_composing) {
      setState(() => _composing = false);
      return;
    }
    if (await _confirmExit() && mounted) Navigator.of(context).pop();
  }

  Future<void> _chooseHashtag() async {
    if (_hashtags.length >= 5) {
      GoMateSnackBar.show(context, message: 'Mỗi bài tối đa 5 hashtag');
      return;
    }
    final newTag = await GoMateBottomSheet.show<String>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      contentPadding: const EdgeInsets.fromLTRB(18, 5, 18, 12),
      child: const GoMatePostHashtagContent(),
    );
    if (!mounted || newTag == null) return;
    if (_hashtags.any((tag) => tag.toLowerCase() == newTag.toLowerCase())) {
      GoMateSnackBar.show(context, message: 'Hashtag đã có trong bài viết');
      return;
    }
    setState(() => _hashtags.add(newTag));
  }

  Future<void> _chooseAudience() async {
    final selected = await GoMateBottomSheet.show<GoMatePostAudience>(
      context: context,
      child: GoMatePostAudienceContent(initial: _audience),
    );
    if (!mounted || selected == null) return;
    setState(() => _audience = selected);
  }

  Future<void> _choosePlace() async {
    // Exact Map place search screen and repository; no fake place is posted to API.
    try {
      final selected = await Navigator.of(context).push<GoMateMapPlace>(
        MaterialPageRoute(builder: (_) => MapPlaceSearchScreen(
          initialPlaces: GoMateMapUiSession.recentPlaces,
          onSearch: (query) => SpringGoMateMapGateway().loadPlaces(query: query),
        )),
      );
      if (!mounted || selected == null) return;
      setState(() => _place = selected);
    } catch (_) {
      if (mounted) GoMateSnackBar.show(context,
          message: 'Chưa tải được địa điểm, vui lòng thử lại.');
    }
  }

  Future<void> _tagPeople() async {
    final repo = RealDirectMessageRepository.instance;
    final contacts = repo.contacts.map((e) => GoMateInviteContact(
      id: e.id, name: e.name, subtitle: e.subtitle, avatarAsset: e.avatarAsset,
    )).toList(growable: false);
    final ids = await GoMateBottomSheet.show<Set<String>>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      child: GoMateMemberInviteContent(
        title: 'Gắn thẻ bạn bè',
        searchHint: 'Tìm kiếm bạn bè...',
        contacts: contacts,
        pendingInviteIds: const <String>{},
        excludedContactIds: _taggedUsers,
        onAddInvites: (newIds) {
          // Reuse candidate-search/selection UI, NOT its invitation API.
          Navigator.of(context, rootNavigator: true).pop(<String>{...newIds});
        },
        onCancelPending: (_) {},
        onSearchContacts: (query) async {
          final items = await repo.fetchContactSuggestions(query);
          return items.map((e) => GoMateInviteContact(
            id: e.id, name: e.name, subtitle: e.subtitle, avatarAsset: e.avatarAsset,
          )).toList(growable: false);
        },
      ),
    );
    if (!mounted || ids == null) return;
    setState(() => _taggedUsers.addAll(ids));
  }

  void _share() {
    if (_sharing || _selected.isEmpty) return;
    setState(() => _sharing = true);
    final current = AuthService.instance.user ?? const <String, dynamic>{};
    final id = (current['userId'] ?? current['id'])?.toString().trim();
    final name = (current['displayName'] ?? current['fullName'] ?? current['nickname'])
        ?.toString().trim();
    GoMatePostUiDemoStore.instance.publish(
      authorId: id == null || id.isEmpty ? 'ui-preview-self' : id,
      authorName: name == null || name.isEmpty ? 'Bạn' : name,
      authorAvatar: current['avatarUrl']?.toString(),
      media: _selected,
      caption: _caption.text.trim(),
      hashtags: _hashtags,
      taggedUserIds: _taggedUsers.toList(growable: false),
      placeId: _place?.placeId,
      placeName: _place?.name,
      audience: _audience,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gap = (width * .055).clamp(18.0, 24.0).toDouble();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: Column(children: [
        GoMateMainTabHeader(
          title: 'Bài viết mới',
          titleSizeOverride: 16,
          leadingIcon: LucideIcons.chevron_left,
          onLeadingTap: _back,
          trailingWidget: _composing ? null : TextButton(onPressed: _next,
            child: const Text('Tiếp tục', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: AppColors.primaryText))),
        ),
        Expanded(child: _composing
            ? _composePage(width, gap)
            : _galleryPage(width, gap)),
      ])),
    );
  }

  Widget _galleryPage(double width, double gap) {
    final source = _latestPreview ?? _gallery.first.source;
    return Column(children: [
      Padding(padding: EdgeInsets.fromLTRB(gap, 6, gap, 8),
        child: AspectRatio(aspectRatio: 1.13,
          child: ClipRRect(borderRadius: BorderRadius.circular(5),
            child: GoMatePostMediaWidget(source: source))),
      ),
      Padding(padding: EdgeInsets.fromLTRB(gap, 7, gap, 12),
        child: Row(children: [
          Expanded(child: Text('Đã chọn ${_selected.length}/12',
            style: const TextStyle(fontSize: 12, color: AppColors.grayText))),
          TextButton.icon(
            onPressed: () => setState(() => _multiSelect = !_multiSelect),
            label: Text(_multiSelect ? 'Chọn nhiều: Bật' : 'Chọn ảnh',
              style: const TextStyle(fontSize: 12, color: AppColors.primaryText)),
            icon: const Icon(LucideIcons.copy, size: 18, color: AppColors.black),
          ),
          IconButton(onPressed: _deviceGallery, tooltip: 'Thư viện thiết bị',
            icon: const Icon(LucideIcons.images, size: 20, color: AppColors.primaryIcon)),
        ])),
      Expanded(child: GridView.builder(
        padding: const EdgeInsets.only(bottom: 12),
        itemCount: _gallery.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, crossAxisSpacing: 3, mainAxisSpacing: 3),
        itemBuilder: (context, index) {
          final item = _gallery[index];
          final order = _selected.indexOf(item.source);
          return InkWell(onTap: () => _toggleMedia(item.source),
            child: Stack(fit: StackFit.expand, children: [
              GoMatePostMediaWidget(source: item.source),
              if (_multiSelect || order >= 0)
                Positioned(top: 6, right: 6,
                  child: Container(width: 24, height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: order >= 0 ? AppColors.primaryIcon : Colors.black38,
                      border: Border.all(color: Colors.white, width: 1.4),
                    ),
                    child: order >= 0 ? Text('${order + 1}',
                      style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 11)) : null)),
            ]));
        },
      )),
    ]);
  }

  Widget _composePage(double width, double gap) {
    final previewWidth = (width * .66).clamp(210.0, 285.0).toDouble();
    final previewHeight = previewWidth * 1.05;
    return Column(children: [
      Expanded(child: ListView(padding: EdgeInsets.only(bottom: gap), children: [
        SizedBox(height: previewHeight + 18,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            padding: EdgeInsets.symmetric(horizontal: gap),
            itemCount: _selected.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final source = _selected.removeAt(oldIndex);
                _selected.insert(newIndex, source);
              });
            },
            itemBuilder: (_, index) => ReorderableDelayedDragStartListener(
              key: ValueKey(_selected[index]),
              index: index,
              child: Container(
                width: previewWidth,
                height: previewHeight,
                margin: const EdgeInsets.only(right: 8),
                child: ClipRRect(borderRadius: BorderRadius.circular(16),
                  child: GoMatePostMediaWidget(source: _selected[index])),
              ),
            ),
          ),
        ),
        Padding(padding: EdgeInsets.fromLTRB(gap, 4, gap, 0),
          child: const Text('Giữ ảnh để đổi thứ tự · Vuốt ngang để xem',
            style: TextStyle(color: AppColors.grayText, fontSize: 11)),
        ),
        Padding(padding: EdgeInsets.fromLTRB(gap, 12, gap, 0),
          child: TextField(
            controller: _caption,
            cursorColor: AppColors.primaryIcon,
            maxLines: null,
            minLines: 2,
            maxLength: 2200,
            style: const TextStyle(fontSize: 13, color: AppColors.black),
            decoration: const InputDecoration(
              hintText: 'Thêm chú thích....',
              border: InputBorder.none,
              hintStyle: TextStyle(color: AppColors.grayText),
            ),
          ),
        ),
        Padding(padding: EdgeInsets.symmetric(horizontal: gap),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(onTap: _chooseHashtag,
              child: const Padding(padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('#NhậpHashtag...', style: TextStyle(fontSize: 13,
                  color: AppColors.black, fontWeight: FontWeight.w700)))),
            for (final tag in _hashtags)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
                Expanded(child: Text(tag, style: const TextStyle(
                  fontSize: 12, color: AppColors.grayText))),
                InkWell(onTap: () => setState(() => _hashtags.remove(tag)),
                  child: const Icon(LucideIcons.x, size: 18, color: AppColors.grayText)),
              ])),
          ]),
        ),
        const SizedBox(height: 10),
        _detailRow(width: width, gap: gap,
          icon: LucideIcons.user_round, label: 'Gắn thẻ bạn bè',
          info: _taggedUsers.isEmpty ? null : '${_taggedUsers.length} người',
          onTap: _tagPeople),
        _detailRow(width: width, gap: gap,
          icon: LucideIcons.map_pin, label: _place?.name ?? 'Địa điểm',
          info: _place?.district ?? _place?.province,
          placeThumbnail: _place?.thumbnailUrl,
          onTap: _choosePlace),
        _detailRow(width: width, gap: gap,
          icon: LucideIcons.globe, label: 'Đối tượng',
          info: _audience.label, onTap: _chooseAudience),
      ])),
      Padding(padding: EdgeInsets.fromLTRB(gap, 8, gap,
        10 + MediaQuery.paddingOf(context).bottom),
        child: _gradientButton('Chia sẻ', _share)),
    ]);
  }

  Widget _detailRow({required double width, required double gap,
    required IconData icon, required String label, String? info,
    String? placeThumbnail, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, child: Padding(
      padding: EdgeInsets.symmetric(horizontal: gap, vertical: 16),
      child: Row(children: [
        if (placeThumbnail != null && placeThumbnail.isNotEmpty)
          ClipRRect(borderRadius: BorderRadius.circular(7), child: SizedBox(
            width: 26, height: 26, child: Image.network(placeThumbnail,
              fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                Icon(icon, size: 23, color: AppColors.black))))
        else Icon(icon, size: 23, color: AppColors.black),
        const SizedBox(width: 13),
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600,
            color: AppColors.black, fontSize: 13))),
        if (info != null && info.isNotEmpty)
          ConstrainedBox(constraints: BoxConstraints(maxWidth: width * .27),
            child: Text(info, textAlign: TextAlign.right,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.grayText, fontSize: 12))),
        const SizedBox(width: 7),
        const Icon(LucideIcons.chevron_right, size: 20, color: AppColors.grayText),
      ])));
  }

  Widget _gradientButton(String label, VoidCallback onTap) =>
      Center(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minWidth: 155, minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppColors.elevatedShadow),
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(color: Colors.white,
            fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ));
}
