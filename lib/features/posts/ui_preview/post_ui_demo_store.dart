import 'package:flutter/foundation.dart';

import '../../profile/widgets/profile_ui_widgets.dart';

/// TODO(BACKEND-CREATE-POST): Whole store is a temporary UI-only adapter.
/// Never use mock post IDs/media paths with production endpoints.
/// Replace with authenticated post repository after upload/create/list/update/delete
/// endpoints exist; keep the screens/widgets and their model mapping.
enum GoMatePostAudience {
  everyone('Mọi người'),
  followers('Người theo dõi'),
  onlyMe('Chỉ mình tôi');

  const GoMatePostAudience(this.label);
  final String label;
}

class GoMateDemoPublishedPost {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final List<String> media;
  final String caption;
  final List<String> hashtags;
  final List<String> taggedUserIds;
  final String? placeName;
  final String? placeId;
  final GoMatePostAudience audience;
  final bool pinned;
  final DateTime createdAt;

  const GoMateDemoPublishedPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.media,
    required this.caption,
    required this.hashtags,
    required this.taggedUserIds,
    required this.placeId,
    required this.placeName,
    required this.audience,
    required this.pinned,
    required this.createdAt,
  });

  GoMateProfilePostPreview toPreview() => GoMateProfilePostPreview(
    id: id,
    authorId: authorId,
    authorName: authorName,
    authorAvatar: authorAvatar,
    caption: [caption.trim(), hashtags.join(' ')].where((e) => e.isNotEmpty).join('\n'),
    media: media,
    location: placeName,
  );

  GoMateDemoPublishedPost copyWith({bool? pinned, GoMatePostAudience? audience}) =>
      GoMateDemoPublishedPost(
        id: id,
        authorId: authorId,
        authorName: authorName,
        authorAvatar: authorAvatar,
        media: media,
        caption: caption,
        hashtags: hashtags,
        taggedUserIds: taggedUserIds,
        placeId: placeId,
        placeName: placeName,
        audience: audience ?? this.audience,
        pinned: pinned ?? this.pinned,
        createdAt: createdAt,
      );
}

class GoMatePostUiDemoStore extends ChangeNotifier {
  GoMatePostUiDemoStore._();
  static final GoMatePostUiDemoStore instance = GoMatePostUiDemoStore._();

  final List<GoMateDemoPublishedPost> _posts = <GoMateDemoPublishedPost>[];
  int _counter = 0;

  // TODO(BACKEND-CREATE-POST): UI-only mutations for legacy ProfileUiPreview
  // sample posts. Keep sample rows visible when a new local draft is posted.
  final Set<String> _previewRemoved = <String>{};
  final Set<String> _previewPinned = <String>{};
  final Map<String, GoMatePostAudience> _previewAudiences = {};

  bool isPreviewPost(String id) => id.startsWith('ui-preview-post-');
  bool previewPinned(String id) => _previewPinned.contains(id);
  GoMatePostAudience previewAudience(String id) =>
      _previewAudiences[id] ?? GoMatePostAudience.followers;

  List<GoMateProfilePostPreview> visiblePreviewPosts(
      List<GoMateProfilePostPreview> posts) {
    final values = posts.where((post) => !_previewRemoved.contains(post.id)).toList();
    values.sort((a,b) {
      final pa = _previewPinned.contains(a.id);
      final pb = _previewPinned.contains(b.id);
      if (pa == pb) return 0;
      return pa ? -1 : 1;
    });
    return List.unmodifiable(values);
  }

  void togglePreviewPin(String id) {
    if (!isPreviewPost(id)) return;
    if (!_previewPinned.remove(id)) _previewPinned.add(id);
    notifyListeners();
  }

  void changePreviewAudience(String id, GoMatePostAudience audience) {
    if (!isPreviewPost(id)) return;
    _previewAudiences[id] = audience;
    notifyListeners();
  }

  void removePreview(String id) {
    if (!isPreviewPost(id)) return;
    _previewRemoved.add(id);
    notifyListeners();
  }


  List<GoMateDemoPublishedPost> postsOf(String userId) {
    final results = _posts.where((p) => p.authorId == userId).toList();
    results.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return List.unmodifiable(results);
  }

  GoMateDemoPublishedPost? find(String id) {
    for (final p in _posts) {
      if (p.id == id) return p;
    }
    return null;
  }

  void publish({
    required String authorId,
    required String authorName,
    String? authorAvatar,
    required List<String> media,
    required String caption,
    required List<String> hashtags,
    required List<String> taggedUserIds,
    required String? placeId,
    required String? placeName,
    required GoMatePostAudience audience,
  }) {
    if (media.isEmpty || media.length > 12) return;
    _posts.insert(0, GoMateDemoPublishedPost(
      id: 'ui-post-${DateTime.now().microsecondsSinceEpoch}-${++_counter}',
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      media: List.unmodifiable(media),
      caption: caption,
      hashtags: List.unmodifiable(hashtags),
      taggedUserIds: List.unmodifiable(taggedUserIds),
      placeId: placeId,
      placeName: placeName,
      audience: audience,
      pinned: false,
      createdAt: DateTime.now(),
    ));
    notifyListeners();
  }

  void togglePin(String id) {
    final i = _posts.indexWhere((p) => p.id == id);
    if (i < 0) return;
    final current = _posts[i];
    _posts[i] = current.copyWith(pinned: !current.pinned);
    notifyListeners();
  }

  void changeAudience(String id, GoMatePostAudience audience) {
    final i = _posts.indexWhere((p) => p.id == id);
    if (i < 0) return;
    _posts[i] = _posts[i].copyWith(audience: audience);
    notifyListeners();
  }

  void remove(String id) {
    _posts.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}

/// Media picker gallery fixtures (assets must exist in pubspec asset directory).
/// TODO(BACKEND-CREATE-POST): replace mock gallery with system media library
/// and upload service; never upload these fixtures as actual user images.
class GoMateDemoMediaItem {
  final String source;
  final bool isVideo;
  const GoMateDemoMediaItem(this.source, {this.isVideo = false});
}

const goMateDemoGallery = <GoMateDemoMediaItem>[
  GoMateDemoMediaItem('assets/images/checkin.jpg'),
  GoMateDemoMediaItem('assets/images/thiennhien.jpg'),
  GoMateDemoMediaItem('assets/images/lichsu.jpg'),
  GoMateDemoMediaItem('assets/images/nghiduong.jpg'),
  GoMateDemoMediaItem('assets/images/survey_landmark.jpg'),
  GoMateDemoMediaItem('assets/images/survey_beach.jpg'),
  GoMateDemoMediaItem('assets/images/survey_city.jpg'),
  GoMateDemoMediaItem('assets/images/survey_food.jpg'),
  GoMateDemoMediaItem('assets/images/survey_culture.jpg'),
  GoMateDemoMediaItem('assets/images/survey_checkin.jpg'),
  GoMateDemoMediaItem('assets/images/survey_country.jpg'),
  GoMateDemoMediaItem('assets/images/survey_resort.jpg'),
  GoMateDemoMediaItem('video-demo:assets/images/ketban.jpg', isVideo: true),
  GoMateDemoMediaItem('assets/images/ketban.jpg'),
];
