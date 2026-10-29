import 'package:flutter/foundation.dart';
import '../widgets/profile_ui_widgets.dart';
import 'profile_ui_preview.dart';

/// TODO(BACKEND-SETTINGS-UI): This entire file is disposable preview data.
/// No demo ID may be sent to AuthService, SearchRepository, MessageRepository or
/// an API. Replace this store with repositories once endpoints are available.
/// In particular: likes/posts, comments, reviews, saved posts, reports, blocks,
/// muted moments, view-history, search-history and time-spent analytics.
class SettingsUiDemo extends ChangeNotifier {
  SettingsUiDemo._() {
    if (!enabled) {
      likedPosts.clear();
      savedPosts.clear();
      visitedPosts.clear();
      likedPlaceIds.clear();
      visitedPlaceIds.clear();
      comments.clear();
      reviews.clear();
      blocked.clear();
      hiddenMoments.clear();
      reports.clear();
      visits.clear();
      searches.clear();
    }
  }
  static final SettingsUiDemo instance = SettingsUiDemo._();
  static const bool enabled = false;

  final List<GoMateProfilePostPreview> likedPosts = List.of(
    ProfileUiPreview.posts(authorId: 'ui-preview-self', authorName: 'Thune'),
  );
  final List<GoMateProfilePostPreview> savedPosts = List.of(
    ProfileUiPreview.posts(authorId: 'ui-preview-self', authorName: 'Thune'),
  );
  final List<GoMateProfilePostPreview> visitedPosts = List.of(
    ProfileUiPreview.posts(authorId: 'ui-preview-self', authorName: 'Thune'),
  );
  final List<String> likedPlaceIds = [
    'ui-preview-place-1',
    'ui-preview-place-2',
    'ui-preview-place-3',
  ];
  final List<String> visitedPlaceIds = [
    'ui-preview-place-1',
    'ui-preview-place-2',
  ];

  final List<SettingsDemoComment> comments = [
    SettingsDemoComment(
      'c1',
      'Chỗ này đẹp quá',
      'Thune',
      '3 ngày',
      'assets/images/thiennhien.jpg',
      'assets/images/checkin.jpg',
    ),
    SettingsDemoComment(
      'c2',
      '@Thune Chỗ này đẹp quá',
      'Thune',
      '3 ngày',
      'assets/images/thiennhien.jpg',
      'assets/images/checkin.jpg',
      reply: true,
    ),
    SettingsDemoComment(
      'c3',
      'Caption tuyệt vời',
      'Thune',
      '3 ngày',
      'assets/images/nghiduong.jpg',
      'assets/images/survey_city.jpg',
    ),
  ];
  final List<SettingsDemoReview> reviews = [
    SettingsDemoReview('r1', 'ui-preview-place-1', 'Caption, đánh giá', 4.8, [
      'assets/images/checkin.jpg',
      'assets/images/survey_beach.jpg',
    ]),
    SettingsDemoReview(
      'r2',
      'ui-preview-place-2',
      'Không gian rất đẹp',
      4.7,
      [],
    ),
  ];
  final List<SettingsDemoPerson> blocked = [
    SettingsDemoPerson('blocked-1', 'DaDaDa', 'Thanh Thuý'),
    SettingsDemoPerson('blocked-2', 'ChiThanh', 'Chí Thành'),
  ];
  final List<SettingsDemoPerson> hiddenMoments = [
    SettingsDemoPerson('hidden-1', 'DaDaDa', 'Thanh Thuý'),
    SettingsDemoPerson('hidden-2', 'ChiThanh', 'Chí Thành'),
  ];
  final List<SettingsDemoReport> reports = [
    SettingsDemoReport(
      'report-1',
      'Nội dung mang tính tiêu cực, bạo lực hoặc công kích',
      'profile',
      'DaDaDa',
      '',
    ),
    SettingsDemoReport(
      'report-2',
      'Nội dung lừa đảo, gian lận hoặc spam',
      'post',
      '',
      'assets/images/thiennhien.jpg',
    ),
    SettingsDemoReport(
      'report-3',
      'Thông tin sai sự thật',
      'place',
      '',
      'assets/images/checkin.jpg',
    ),
  ];
  final List<SettingsDemoVisit> visits = [
    SettingsDemoVisit(
      'ui-preview-place-1',
      true,
      DateTime.now().subtract(const Duration(days: 1)),
    ),
    SettingsDemoVisit(
      'ui-preview-post-a-ui-preview-self',
      false,
      DateTime.now().subtract(const Duration(days: 2)),
    ),
    SettingsDemoVisit(
      'ui-preview-post-b-ui-preview-self',
      false,
      DateTime.now().subtract(const Duration(days: 1)),
    ),
    SettingsDemoVisit(
      'ui-preview-place-2',
      true,
      DateTime.now().subtract(const Duration(days: 4)),
    ),
  ];
  final List<SettingsDemoSearch> searches = [
    SettingsDemoSearch(
      'Cầu Vàng – Bà Nà Hills',
      'Địa điểm',
      DateTime.now(),
      targetId: 'ui-preview-place-1',
    ),
    SettingsDemoSearch(
      'Xuân Thu',
      'Người dùng',
      DateTime.now().subtract(const Duration(days: 2)),
      targetId: 'ui-preview-public',
    ),
    SettingsDemoSearch(
      'Lịch trình Đà Lạt',
      'Lịch trình',
      DateTime.now().subtract(const Duration(days: 3)),
      targetId: 'ui-preview-settings-trip',
    ),
    SettingsDemoSearch(
      'Biển xanh',
      'Tìm kiếm chung',
      DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  // UI controls only, NOT persisted. Backend must own privacy settings.
  bool privatePreview = false;
  bool darkModePreview = false;

  void changed() => notifyListeners();
  void removePosts(Iterable<String> ids, {required bool saved}) {
    final target = saved ? savedPosts : likedPosts;
    target.removeWhere((p) => ids.contains(p.id));
    notifyListeners();
  }

  void removePlaces(Iterable<String> ids) {
    likedPlaceIds.removeWhere(ids.contains);
    notifyListeners();
  }

  void removeComments(Iterable<String> ids) {
    comments.removeWhere((p) => ids.contains(p.id));
    notifyListeners();
  }

  void removeReviews(Iterable<String> ids) {
    reviews.removeWhere((p) => ids.contains(p.id));
    notifyListeners();
  }

  void unblock(String id) {
    blocked.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void unhide(String id) {
    hiddenMoments.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void removeSearch(SettingsDemoSearch entry) {
    searches.remove(entry);
    notifyListeners();
  }

  void clearSearch() {
    searches.clear();
    notifyListeners();
  }
}

class SettingsDemoComment {
  final String id, text, author, time, postThumbnail, image;
  final String parentCaption;
  final bool reply;
  const SettingsDemoComment(
    this.id,
    this.text,
    this.author,
    this.time,
    this.postThumbnail,
    this.image, {
    this.reply = false,
    this.parentCaption = 'Một chuyến đi thật nhiều kỷ niệm',
  });
}

class SettingsDemoReview {
  final String id, placeId, caption;
  final double rating;
  final List<String> images;
  const SettingsDemoReview(
    this.id,
    this.placeId,
    this.caption,
    this.rating,
    this.images,
  );
}

class SettingsDemoPerson {
  final String id, name, subtitle;
  const SettingsDemoPerson(this.id, this.name, this.subtitle);
}

class SettingsDemoReport {
  final String id, reason, type, name, image;
  const SettingsDemoReport(
    this.id,
    this.reason,
    this.type,
    this.name,
    this.image,
  );
}

class SettingsDemoVisit {
  final String targetId;
  final bool isPlace;
  final DateTime date;
  const SettingsDemoVisit(this.targetId, this.isPlace, this.date);
}

class SettingsDemoSearch {
  final String text, type;
  final DateTime date;

  /// Trusted target ID after backend migration; demo IDs stay local.
  final String targetId;
  const SettingsDemoSearch(
    this.text,
    this.type,
    this.date, {
    this.targetId = '',
  });
}
