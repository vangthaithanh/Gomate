import 'package:flutter/foundation.dart';
import '../../../core/services/auth_service.dart';

class PlaceRating {
  const PlaceRating(double? average, this.count) : average = average ?? 0;
  final double average;
  final int count;
  bool get hasValidRating =>
      count > 0 && average.isFinite && average >= 1 && average <= 5;
  // Numeric projection is never itself an unrated label. Consumers use label.
  double get display => hasValidRating ? average : 0;
  String get label => count == 0
      ? 'Chưa có đánh giá'
      : hasValidRating
      ? '${average.toStringAsFixed(1)} ($count)'
      : 'Điểm đánh giá chưa khả dụng ($count)';
  String get compactLabel => hasValidRating
      ? '${average.toStringAsFixed(1).replaceAll('.', ',')} ($count)'
      : label;
}

/// Public aggregate ACKs only, bounded to canonical Places; no author/session data.
class PlaceRatingChanges {
  static int revision = 0;
  static final _values = <String, ValueNotifier<PlaceRating?>>{};
  static ValueNotifier<PlaceRating?> forPlace(String id) =>
      _values.putIfAbsent(id, () => ValueNotifier(null));
  static void acknowledge(String id, PlaceRating value) {
    final notifier = forPlace(id);
    if (notifier.value?.average != value.average ||
        notifier.value?.count != value.count) {
      revision++;
      notifier.value = value;
    }
  }
}

class PlaceReview {
  const PlaceReview({
    required this.id,
    required this.rating,
    required this.content,
    this.author = '',
    this.userId,
    this.avatarUrl,
    this.createdAt,
    this.hidden = false,
  });
  final int id, rating;
  final String content, author;
  final String? userId, avatarUrl;
  final DateTime? createdAt;
  final bool hidden;
  factory PlaceReview.fromJson(Map<String, dynamic> r) => PlaceReview(
    id: (r['id'] as num).toInt(),
    rating: (r['rating'] as num).toInt(),
    content: r['content'] as String? ?? '',
    author: r['displayName'] as String? ?? '',
    userId: r['userId']?.toString(),
    avatarUrl: r['avatarUrl'] as String?,
    createdAt: DateTime.tryParse(r['createdAt']?.toString() ?? ''),
    hidden: r['moderationStatus'] == 'HIDDEN',
  );
}

class PlaceReviewState {
  const PlaceReviewState(this.stats, this.mine);
  final PlaceRating stats;
  final PlaceReview? mine;
  factory PlaceReviewState.fromJson(Map<String, dynamic> r) => PlaceReviewState(
    PlaceRating(
      (r['avgRating'] as num?)?.toDouble(),
      (r['reviewCount'] as num).toInt(),
    ),
    r['myReview'] == null
        ? null
        : PlaceReview.fromJson(Map<String, dynamic>.from(r['myReview'] as Map)),
  );
}

class PlaceReviewPage {
  const PlaceReviewPage(this.stats, this.items, this.nextBeforeId);
  final PlaceRating stats;
  final List<PlaceReview> items;
  final int? nextBeforeId;
}

class PlaceReviewRepository {
  PlaceReviewRepository({AuthService? auth})
    : auth = auth ?? AuthService.instance;
  final AuthService auth;
  Future<PlaceReviewState> mine(String id) async {
    final revision = PlaceRatingChanges.revision;
    final state = PlaceReviewState.fromJson(
      await auth.request('GET', '/places/$id/reviews/me'),
    );
    if (revision == PlaceRatingChanges.revision)
      PlaceRatingChanges.acknowledge(id, state.stats);
    return state;
  }

  Future<PlaceReviewPage> page(
    String id, {
    int? before,
    String sort = 'newest',
  }) async {
    final revision = PlaceRatingChanges.revision;
    final r = await auth.request(
      'GET',
      '/places/$id/reviews?size=50&sort=$sort${before == null ? '' : '&beforeId=$before'}',
    );
    final page = PlaceReviewPage(
      PlaceRating(
        (r['avgRating'] as num?)?.toDouble(),
        (r['reviewCount'] as num).toInt(),
      ),
      (r['items'] as List)
          .map((v) => PlaceReview.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList(),
      (r['nextBeforeId'] as num?)?.toInt(),
    );
    if (revision == PlaceRatingChanges.revision)
      PlaceRatingChanges.acknowledge(id, page.stats);
    return page;
  }

  Future<PlaceReviewState> save(
    String place,
    int stars,
    String content, {
    int? reviewId,
  }) async {
    final r = await auth.request(
      reviewId == null ? 'POST' : 'PATCH',
      reviewId == null ? '/places/$place/reviews' : '/reviews/$reviewId',
      body: {'rating': stars, 'content': content},
    );
    final result = PlaceReviewState.fromJson(r);
    PlaceRatingChanges.acknowledge(place, result.stats);
    return result;
  }

  Future<PlaceReviewState> delete(String place, int id) async {
    final result = PlaceReviewState.fromJson(
      await auth.request('DELETE', '/reviews/$id'),
    );
    PlaceRatingChanges.acknowledge(place, result.stats);
    return result;
  }
}
