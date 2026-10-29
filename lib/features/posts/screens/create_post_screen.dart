import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

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
import 'post_video_trim_screen.dart';
import 'post_detail_screen.dart';
import '../data/post_repository.dart';
import '../models/post_compose_models.dart';
import '../widgets/post_audience_content.dart';
import '../widgets/post_hashtag_content.dart';
import '../widgets/post_media_widget.dart';
import '../widgets/content_mode_selector.dart';
import '../../moments/data/moments_repository.dart';
import '../../moments/screens/moment_camera_screen.dart';

/// Existing compose UI backed by protected media upload and committed Post APIs.
class GoMateCreatePostScreen extends StatefulWidget {
  final bool enableMomentMode;
  const GoMateCreatePostScreen({super.key, this.enableMomentMode = false});
  @override
  State<GoMateCreatePostScreen> createState() => _GoMateCreatePostScreenState();
}

class _GoMateCreatePostScreenState extends State<GoMateCreatePostScreen> {
  final _caption = TextEditingController();
  final _publisher = PostPublisher();
  final List<String> _selected = <String>[];
  final List<AssetEntity> _gallery = <AssetEntity>[];
  final Map<String, String> _idToSource = <String, String>{};
  final Map<String, Uint8List?> _sourceThumbs = <String, Uint8List?>{};
  final Map<String, Future<Uint8List?>> _thumbFutures =
      <String, Future<Uint8List?>>{};
  final Map<String, GoMatePostTrimRange> _trimRanges =
      <String, GoMatePostTrimRange>{};
  final List<String> _hashtags = <String>[];
  final Set<String> _taggedUsers = <String>{};
  GoMatePostAudience _audience = GoMatePostAudience.everyone;
  GoMateMapPlace? _place;
  AssetPathEntity? _album;
  bool _galleryLoading = true;
  bool _galleryPermissionDenied = false;
  bool _hasMore = true;
  int _page = 0;
  bool _multiSelect = false;
  bool _composing = false;
  bool _sharing = false;
  bool _shareInFlight = false;
  String? _previewId;
  String? _cameraPreview;
  final List<String> _captures = [];
  bool _mediaBusy = false;
  bool _momentMode = false;

  bool get _privateAccount {
    final profile = AuthService.instance.user;
    return profile?['isPrivate'] == true;
  }

  @override
  void initState() {
    super.initState();
    _audience = _privateAccount
        ? GoMatePostAudience.followers
        : GoMatePostAudience.everyone;
    _publisher.addListener(_publishChanged);
    unawaited(_loadPrivacy());
    unawaited(_loadGallery());
  }

  Future<void> _loadPrivacy() async {
    final auth = AuthService.instance;
    final actor = auth.user?['id'];
    try {
      await auth.loadProfile();
      if (!mounted || actor != auth.user?['id']) return;
      if (_audience == GoMatePostAudience.everyone ||
          _audience == GoMatePostAudience.followers) {
        setState(
          () => _audience = _privateAccount
              ? GoMatePostAudience.followers
              : GoMatePostAudience.everyone,
        );
      }
    } catch (_) {
      // Share revalidates server privacy before uploading or publishing.
    }
  }

  @override
  void dispose() {
    _publisher.removeListener(_publishChanged);
    unawaited(_publisher.clearExports());
    _caption.dispose();
    super.dispose();
  }

  Future<void> _loadGallery() async {
    if (mounted) {
      setState(() {
        _galleryLoading = true;
        _galleryPermissionDenied = false;
      });
    }
    try {
      final status = await PhotoManager.requestPermissionExtend();
      if (!mounted) return;
      if (!status.hasAccess) {
        setState(() {
          _galleryPermissionDenied = true;
          _galleryLoading = false;
        });
        return;
      }
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: true,
        // Unordered MediaStore pages can put old photos ahead of recent videos.
        filterOption: CustomFilter.sql(
          where: '',
          orderBy: [
            OrderByItem.named(
              column: CustomColumns.base.createDate,
              isAsc: false,
            ),
            if (Platform.isAndroid)
              OrderByItem.named(column: CustomColumns.android.id, isAsc: false),
          ],
        ),
      );
      if (!mounted) return;
      _album = paths.isEmpty ? null : paths.first;
      _page = 0;
      _hasMore = true;
      _gallery.clear();
      setState(() => _galleryLoading = false);
      await _loadMore();
    } catch (_) {
      if (mounted) {
        setState(() {
          _galleryLoading = false;
          _galleryPermissionDenied = true;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_galleryLoading || !_hasMore || _album == null) return;
    setState(() => _galleryLoading = true);
    try {
      final next = await _album!.getAssetListPaged(page: _page, size: 72);
      if (!mounted) return;
      setState(() {
        _page++;
        _gallery.addAll(
          next.where(
            (a) => a.type == AssetType.image || a.type == AssetType.video,
          ),
        );
        _hasMore = next.length == 72;
      });
    } catch (_) {
      if (mounted) {
        GoMateSnackBar.show(
          context,
          message: 'Chưa tải được ảnh tiếp theo từ thiết bị.',
        );
      }
    } finally {
      if (mounted) setState(() => _galleryLoading = false);
    }
  }

  Future<Uint8List?> _thumbnail(AssetEntity asset) => _thumbFutures.putIfAbsent(
    asset.id,
    () async {
      try {
        return await asset.thumbnailDataWithSize(const ThumbnailSize(300, 300));
      } catch (_) {
        return null;
      }
    },
  );

  Future<void> _toggleMedia(AssetEntity asset) async {
    if (_mediaBusy) return;
    _cameraPreview = null;
    final previous = _idToSource[asset.id];
    if (previous != null && _selected.contains(previous)) {
      setState(() {
        _selected.remove(previous);
        _idToSource.remove(asset.id);
        _trimRanges.remove(previous);
        _sourceThumbs.remove(previous);
        _previewId = _idToSource.isEmpty ? null : _idToSource.keys.last;
      });
      return;
    }
    if (_selected.length >= 12) {
      GoMateSnackBar.show(context, message: 'Chọn tối đa 12 ảnh hoặc video');
      return;
    }
    setState(() => _mediaBusy = true);
    try {
      final file = await asset.file;
      if (!mounted) return;
      if (file == null) {
        GoMateSnackBar.show(context, message: 'Không đọc được tệp này.');
        return;
      }
      final isVideo = asset.type == AssetType.video;
      GoMatePostTrimRange? clip;
      if (isVideo) {
        final player = VideoPlayerController.file(file);
        late Duration actual;
        try {
          await player.initialize();
          actual = player.value.duration;
        } finally {
          await player.dispose();
        }
        if (!mounted) return;
        if (actual <= Duration.zero) throw StateError('Không đọc được video');
        if (actual > const Duration(seconds: 30)) {
          clip = await Navigator.of(context).push<GoMatePostTrimRange>(
            MaterialPageRoute(
              builder: (_) => GoMatePostVideoTrimScreen(
                video: file,
                estimatedDuration: actual,
              ),
            ),
          );
          if (!mounted || clip == null) return;
        } else {
          clip = GoMatePostTrimRange(startMs: 0, endMs: actual.inMilliseconds);
        }
      }
      final source = isVideo
          ? 'video-file:${file.path}'
          : Uri.file(file.path).toString();
      final thumb = await _thumbnail(asset);
      if (!mounted) return;
      setState(() {
        if (!_multiSelect) {
          _selected.clear();
          _idToSource.clear();
          _trimRanges.clear();
          _sourceThumbs.clear();
        }
        _selected.add(source);
        _idToSource[asset.id] = source;
        _sourceThumbs[source] = thumb;
        if (clip != null) _trimRanges[source] = clip;
        _previewId = asset.id;
      });
    } catch (_) {
      if (mounted) {
        GoMateSnackBar.show(
          context,
          message: 'Không thể chọn tệp; kiểm tra quyền thư viện.',
        );
      }
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
    }
  }

  Future<void> _capture() async {
    if (_mediaBusy) return;
    if (_selected.length >= 12) {
      GoMateSnackBar.show(context, message: 'Chọn tối đa 12 ảnh hoặc video');
      return;
    }
    final video = await GoMateBottomSheet.show<bool>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(LucideIcons.camera),
            title: const Text('Chụp ảnh'),
            onTap: () => Navigator.of(context).pop(false),
          ),
          ListTile(
            leading: const Icon(LucideIcons.video),
            title: const Text('Quay video'),
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (!mounted || video == null) return;
    setState(() => _mediaBusy = true);
    try {
      final picker = ImagePicker();
      final file = video
          ? await picker.pickVideo(
              source: ImageSource.camera,
              maxDuration: const Duration(seconds: 30),
            )
          : await picker.pickImage(
              source: ImageSource.camera,
              imageQuality: 85,
            );
      if (!mounted || file == null) return;
      GoMatePostTrimRange? clip;
      if (video) {
        final player = VideoPlayerController.file(File(file.path));
        late Duration duration;
        try {
          await player.initialize();
          duration = player.value.duration;
        } finally {
          await player.dispose();
        }
        if (!mounted) return;
        if (duration <= Duration.zero) {
          throw StateError('Không đọc được thời lượng video');
        }
        if (duration > const Duration(seconds: 30)) {
          clip = await Navigator.of(context).push<GoMatePostTrimRange>(
            MaterialPageRoute(
              builder: (_) => GoMatePostVideoTrimScreen(
                video: File(file.path),
                estimatedDuration: duration,
              ),
            ),
          );
          if (!mounted || clip == null) return;
        } else {
          clip = GoMatePostTrimRange(
            startMs: 0,
            endMs: duration.inMilliseconds,
          );
        }
      }
      final source = video
          ? 'video-file:${file.path}'
          : Uri.file(file.path).toString();
      if (_selected.length >= 12) return;
      setState(() {
        if (!_captures.contains(source)) _captures.add(source);
        if (!_selected.contains(source)) _selected.add(source);
        if (clip != null) _trimRanges[source] = clip;
        _cameraPreview = source;
        _multiSelect = _selected.length > 1;
      });
    } catch (_) {
      if (mounted) {
        GoMateSnackBar.show(
          context,
          message:
              'Không thể chụp hoặc quay video. Kiểm tra quyền camera và micro.',
        );
      }
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bỏ bài viết đang tạo?',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ảnh đã chọn và nội dung chưa chia sẻ sẽ không được lưu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.grayText),
              ),
              const SizedBox(height: 18),
              _gradientButton(
                'Bỏ bài viết',
                () => Navigator.of(context).pop(true),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Tiếp tục chỉnh sửa'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _back() async {
    if (_sharing) return;
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
    if (_hashtags.any(
      (tag) => normalizePostHashtag(tag) == normalizePostHashtag(newTag),
    )) {
      GoMateSnackBar.show(context, message: 'Hashtag đã có trong bài viết');
      return;
    }
    setState(() => _hashtags.add(newTag));
  }

  Future<void> _chooseAudience() async {
    final selected = await GoMateBottomSheet.show<GoMatePostAudience>(
      context: context,
      child: GoMatePostAudienceContent(
        initial: _audience,
        isPrivate: _privateAccount,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _audience = selected);
  }

  Future<void> _choosePlace() async {
    // Exact Map place search screen and repository; no fake place is posted to API.
    try {
      final selected = await Navigator.of(context).push<GoMateMapPlace>(
        MaterialPageRoute(
          builder: (_) => MapPlaceSearchScreen(
            initialPlaces: GoMateMapUiSession.recentPlaces,
            onSearch: (query) =>
                SpringGoMateMapGateway().loadPlaces(query: query),
          ),
        ),
      );
      if (!mounted || selected == null) return;
      setState(() => _place = selected);
    } catch (_) {
      if (mounted) {
        GoMateSnackBar.show(
          context,
          message: 'Chưa tải được địa điểm, vui lòng thử lại.',
        );
      }
    }
  }

  Future<void> _tagPeople() async {
    final repo = RealDirectMessageRepository.instance;
    final contacts = repo.contacts
        .map(
          (e) => GoMateInviteContact(
            id: e.id,
            name: e.name,
            subtitle: e.subtitle,
            avatarAsset: e.avatarAsset,
          ),
        )
        .toList(growable: false);
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
          return items
              .map(
                (e) => GoMateInviteContact(
                  id: e.id,
                  name: e.name,
                  subtitle: e.subtitle,
                  avatarAsset: e.avatarAsset,
                ),
              )
              .toList(growable: false);
        },
      ),
    );
    if (!mounted || ids == null) return;
    setState(() => _taggedUsers.addAll(ids));
  }

  void _publishChanged() {
    if (mounted) setState(() => _sharing = _publisher.busy);
  }

  Future<void> _share() async {
    if (_shareInFlight || _selected.isEmpty) return;
    _shareInFlight = true;
    setState(() => _sharing = true);
    final actor = AuthService.instance.user?['id'];
    try {
      if (!_publisher.commitPending) {
        await AuthService.instance.loadProfile();
        if (actor != AuthService.instance.user?['id'])
          throw StateError('Tài khoản đã thay đổi');
        final invalid = _privateAccount
            ? _audience == GoMatePostAudience.everyone
            : _audience == GoMatePostAudience.followers;
        if (invalid) {
          if (mounted) await _chooseAudience();
          return;
        }
      }
      final id = await _publisher.submit(
        sources: List.of(_selected),
        ranges: Map.of(_trimRanges),
        caption: _caption.text,
        audience: _audience,
        hashtags: List.of(_hashtags),
        taggedUserIds: _taggedUsers.toList(),
        placeId: _place == null ? null : int.parse(_place!.placeId),
      );
      if (!mounted) return;
      GoMateSnackBar.show(context, message: 'Đã đăng bài viết');
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(builder: (_) => PostDetailScreen(postId: id)),
      );
    } catch (error) {
      if (mounted) {
        GoMateSnackBar.show(
          context,
          message: 'Không đăng được bài viết: $error',
        );
      }
    } finally {
      _shareInFlight = false;
      if (mounted) setState(() => _sharing = false);
    }
  }

  Widget _modeSelector(bool enabled) => ContentModeSelector(
    moment: _momentMode,
    enabled: enabled,
    onChanged: (moment) {
      if (!enabled || _sharing || _mediaBusy || moment == _momentMode) return;
      setState(() => _momentMode = moment);
    },
  );

  @override
  Widget build(BuildContext context) {
    if (widget.enableMomentMode && _momentMode) {
      // Keep draft fields, not hidden video/camera widgets or native controllers.
      return MomentCameraScreen(
        repository: ApiMomentsRepository.instance,
        modeSelectorBuilder: _modeSelector,
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    final gap = (width * .055).clamp(18.0, 24.0).toDouble();
    return PopScope(
      canPop: !_sharing,
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: widget.enableMomentMode && !_composing
            ? _modeSelector(!_sharing && !_mediaBusy)
            : null,
        body: SafeArea(
          child: Column(
            children: [
              Stack(
                children: [
                  GoMateMainTabHeader(
                    title: 'Bài viết mới',
                    titleSizeOverride: 16,
                    leadingIcon: LucideIcons.chevron_left,
                    onLeadingTap: _back,
                  ),
                  if (!_composing)
                    Positioned(
                      right: (width * .058).clamp(20.0, 24.0).toDouble(),
                      top: 5,
                      child: SizedBox(
                        height: 40,
                        child: TextButton(
                          onPressed: _next,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryText,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            minimumSize: const Size(65, 36),
                          ),
                          child: const Text(
                            'Tiếp tục',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: _composing
                    ? _composePage(width, gap)
                    : _galleryPage(width, gap),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _galleryPage(double width, double gap) {
    AssetEntity? preview;
    if (_gallery.isNotEmpty) {
      for (final asset in _gallery) {
        if (asset.id == _previewId) {
          preview = asset;
          break;
        }
      }
      preview ??= _gallery.first;
    }
    final activeSource =
        _cameraPreview ?? (_previewId == null ? null : _idToSource[_previewId]);
    return Column(
      children: [
        if (preview != null || _cameraPreview != null)
          Padding(
            padding: EdgeInsets.fromLTRB(gap, 6, gap, 8),
            child: AspectRatio(
              aspectRatio: 1.13,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: activeSource == null
                    ? _assetImage(preview!)
                    : FutureBuilder<Uint8List?>(
                        future: _cameraPreview != null
                            ? Future.value(null)
                            : _thumbnail(preview!),
                        builder: (_, snap) => GoMatePostMediaWidget(
                          source: activeSource,
                          thumbnailBytes: snap.data,
                          trimRange: _trimRanges[activeSource],
                        ),
                      ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(gap, 7, gap, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Đã chọn ${_selected.length}/12',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grayText,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _multiSelect = !_multiSelect),
                label: Text(
                  _multiSelect ? 'Chọn nhiều: Bật' : 'Chọn nhiều',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryText,
                  ),
                ),
                icon: const Icon(
                  LucideIcons.copy,
                  size: 18,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
        ),
        if (_galleryPermissionDenied)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gap),
            child: Column(
              children: [
                const Text(
                  'Cần quyền truy cập ảnh và video trong thiết bị',
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () async {
                    await PhotoManager.openSetting();
                    if (mounted) await _loadGallery();
                  },
                  child: const Text('Mở cài đặt cấp quyền'),
                ),
                TextButton(
                  onPressed: _loadGallery,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          )
        else if (_gallery.isEmpty && !_galleryLoading)
          const Text(
            'Album thiết bị chưa có ảnh hoặc video',
            style: TextStyle(color: AppColors.grayText),
          ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (event) {
              if (event.metrics.extentAfter < 250 &&
                  _hasMore &&
                  !_galleryLoading) {
                unawaited(_loadMore());
              }
              return false;
            },
            child: GridView.builder(
              padding: const EdgeInsets.only(bottom: 14),
              itemCount:
                  1 +
                  _captures.length +
                  _gallery.length +
                  (_galleryLoading ? 1 : 0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
              ),
              itemBuilder: (context, index) {
                if (index == 0) return _cameraCell();
                if (index <= _captures.length) {
                  return _capturedCell(_captures[index - 1]);
                }
                index -= 1 + _captures.length;
                if (index >= _gallery.length) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryIcon,
                      strokeWidth: 2,
                    ),
                  );
                }
                final item = _gallery[index];
                final source = _idToSource[item.id];
                final order = source == null ? -1 : _selected.indexOf(source);
                return InkWell(
                  onTap: () => _toggleMedia(item),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _assetImage(item),
                      if (item.type == AssetType.video)
                        Positioned(
                          left: 5,
                          bottom: 5,
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.play,
                                size: 14,
                                color: Colors.white,
                              ),
                              Text(
                                '${item.duration ~/ 60}:${(item.duration % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_multiSelect || order >= 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: order >= 0
                                  ? AppColors.primaryIcon
                                  : Colors.black38,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.4,
                              ),
                            ),
                            child: order >= 0
                                ? Text(
                                    '${order + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _assetImage(AssetEntity asset) => FutureBuilder<Uint8List?>(
    future: _thumbnail(asset),
    builder: (context, snap) {
      if (snap.data == null) {
        return const ColoredBox(
          color: Color(0xFFE8EDF6),
          child: Center(
            child: Icon(LucideIcons.image, color: AppColors.grayText),
          ),
        );
      }
      return Image.memory(snap.data!, fit: BoxFit.cover, gaplessPlayback: true);
    },
  );

  Widget _cameraCell() => InkWell(
    key: const ValueKey('post-camera-cell'),
    onTap: _capture,
    child: const ColoredBox(
      color: Color(0xFFE8EDF6),
      child: Center(
        child: Icon(LucideIcons.camera, size: 30, color: AppColors.primaryIcon),
      ),
    ),
  );

  Widget _capturedCell(String source) {
    final order = _selected.indexOf(source);
    return InkWell(
      onTap: () {
        if (_mediaBusy) return;
        if (order < 0 && _selected.length >= 12) {
          GoMateSnackBar.show(
            context,
            message: 'Chọn tối đa 12 ảnh hoặc video',
          );
          return;
        }
        setState(() {
          if (order >= 0) {
            _selected.remove(source);
          } else {
            _selected.add(source);
          }
          _cameraPreview = source;
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: GoMatePostMediaWidget(
              source: source,
              trimRange: _trimRanges[source],
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: order >= 0 ? AppColors.primaryIcon : Colors.black38,
                border: Border.all(color: Colors.white, width: 1.4),
              ),
              child: order >= 0
                  ? Text(
                      '${order + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _composePage(double width, double gap) {
    final previewWidth = (width * .66).clamp(210.0, 285.0).toDouble();
    final previewHeight = previewWidth * 1.05;
    return Column(
      children: [
        Expanded(
          child: AbsorbPointer(
            absorbing: _sharing || _publisher.commitPending,
            child: ListView(
              padding: EdgeInsets.only(bottom: gap),
              children: [
                SizedBox(
                  height: previewHeight + 18,
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
                    itemBuilder: (_, index) =>
                        ReorderableDelayedDragStartListener(
                          key: ValueKey(_selected[index]),
                          index: index,
                          child: Container(
                            width: previewWidth,
                            height: previewHeight,
                            margin: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: GoMatePostMediaWidget(
                                source: _selected[index],
                                thumbnailBytes: _sourceThumbs[_selected[index]],
                                trimRange: _trimRanges[_selected[index]],
                              ),
                            ),
                          ),
                        ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(gap, 4, gap, 0),
                  child: const Text(
                    'Giữ ảnh để đổi thứ tự · Vuốt ngang để xem',
                    style: TextStyle(color: AppColors.grayText, fontSize: 11),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(gap, 12, gap, 0),
                  child: TextField(
                    controller: _caption,
                    cursorColor: AppColors.primaryIcon,
                    maxLines: null,
                    minLines: 2,
                    maxLength: 2200,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.black,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Thêm chú thích....',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: AppColors.grayText),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: gap),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: _chooseHashtag,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            '#NhậpHashtag...',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.black,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      for (final tag in _hashtags)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.grayText,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () =>
                                    setState(() => _hashtags.remove(tag)),
                                child: const Icon(
                                  LucideIcons.x,
                                  size: 18,
                                  color: AppColors.grayText,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _detailRow(
                  width: width,
                  gap: gap,
                  icon: LucideIcons.user_round,
                  label: 'Gắn thẻ bạn bè',
                  info: _taggedUsers.isEmpty
                      ? null
                      : '${_taggedUsers.length} người',
                  onTap: _tagPeople,
                ),
                _detailRow(
                  width: width,
                  gap: gap,
                  icon: LucideIcons.map_pin,
                  label: _place?.name ?? 'Địa điểm',
                  info: _place?.district ?? _place?.province,
                  placeThumbnail: _place?.thumbnailUrl,
                  onTap: _choosePlace,
                ),
                _detailRow(
                  width: width,
                  gap: gap,
                  icon: LucideIcons.globe,
                  label: 'Đối tượng',
                  info: _audience.label,
                  onTap: _chooseAudience,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            gap,
            8,
            gap,
            10 + MediaQuery.paddingOf(context).bottom,
          ),
          child: _gradientButton(
            _sharing
                ? _publisher.phase
                : _publisher.commitPending
                ? 'Kiểm tra và thử lại'
                : 'Chia sẻ',
            _share,
          ),
        ),
      ],
    );
  }

  Widget _detailRow({
    required double width,
    required double gap,
    required IconData icon,
    required String label,
    String? info,
    String? placeThumbnail,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gap, vertical: 16),
        child: Row(
          children: [
            if (placeThumbnail != null && placeThumbnail.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: Image.network(
                    placeThumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(icon, size: 23, color: AppColors.black),
                  ),
                ),
              )
            else
              Icon(icon, size: 23, color: AppColors.black),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                  fontSize: 13,
                ),
              ),
            ),
            if (info != null && info.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width * .27),
                child: Text(
                  info,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.grayText,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(width: 7),
            const Icon(
              LucideIcons.chevron_right,
              size: 20,
              color: AppColors.grayText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _gradientButton(String label, VoidCallback onTap) => Center(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minWidth: 155, minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.elevatedShadow,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}
