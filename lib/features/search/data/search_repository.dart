import 'dart:convert';
import '../../../core/services/auth_service.dart';
import '../../../core/services/content_access_changes.dart';
import '../../map/services/location_service.dart';
import '../../recommendation/data/recommendation_repository.dart';
import '../../recommendation/models/recommendation_models.dart';
import '../models/search_models.dart';

/// Search data stays server-owned; Recommendation is used only for Discovery.
class SearchRepository {
  final AuthService _auth;
  AuthService get auth => _auth;
  final RecommendationRepository _recommendationRepository;
  final GoMateLocationService _locationService;
  SearchRepository({
    AuthService? auth,
    RecommendationRepository? recommendationRepository,
    GoMateLocationService? locationService,
  }) : _auth = auth ?? AuthService.instance,
       _recommendationRepository =
           recommendationRepository ?? RecommendationRepository(auth: auth),
       _locationService = locationService ?? GoMateLocationService();

  Future<List<SearchPlaceItem>> getSuggestedPlaces() async {
    double? latitude, longitude;
    if (_selectedContextCodes().contains('GAN_TOI')) {
      try {
        final result = await _locationService.getCurrentLocation();
        if (result.state == GoMateLocationState.ready &&
            result.position != null) {
          latitude = result.position!.latitude;
          longitude = result.position!.longitude;
        }
      } catch (_) {
        /* Discovery keeps its existing GPS-optional ranking. */
      }
    }
    final response = await _recommendationRepository.getMine(
      topK: 50,
      latitude: latitude,
      longitude: longitude,
    );
    return response.items
        .where((p) => p.placeId > 0)
        .map((p) => _fromRecommended(p, 0))
        .toList();
  }

  Future<List<String>> getRecentSearches() async =>
      (await _auth.requestJson('GET', '/search/recent') as List).cast<String>();
  Future<void> saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    await _auth.requestJson(
      'POST',
      '/search/recent',
      body: {'query': query.trim()},
    );
  }

  Future<void> removeRecentSearch(String query) async {
    await _auth.requestJson(
      'DELETE',
      Uri(path: '/search/recent', queryParameters: {'q': query}).toString(),
    );
  }

  Future<SearchBundle> search({
    required String query,
    Set<SearchPlaceFilter> placeFilters = const {},
    Set<String> hashtags = const {},
  }) async {
    final pages = await Future.wait([
      _firstPlacePage(query, placeFilters),
      _usersPage(query, 0),
      _postPage(query, hashtags, null),
    ]);
    final places = pages[0], users = pages[1], posts = pages[2];
    return SearchBundle(
      placeError: places.placeError,
      latitude: places.latitude,
      longitude: places.longitude,
      places: places.places,
      users: users.users,
      posts: posts.posts,
      placeCursor: places.placeCursor,
      postCursor: posts.postCursor,
      userNextPage: users.userNextPage,
    );
  }

  Future<SearchBundle> _firstPlacePage(
    String query,
    Set<SearchPlaceFilter> filters,
  ) async {
    double? latitude, longitude;
    if (filters.contains(SearchPlaceFilter.nearby)) {
      try {
        final result = await _locationService.getCurrentLocation().timeout(
          const Duration(seconds: 12),
        );
        if (result.state != GoMateLocationState.ready ||
            result.position == null)
          throw StateError('GPS unavailable');
        latitude = result.position!.latitude;
        longitude = result.position!.longitude;
      } catch (_) {
        return const SearchBundle(
          placeError: 'Cần vị trí hiện tại để tìm địa điểm gần bạn.',
        );
      }
    }
    return _placePage(
      query,
      filters,
      null,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<SearchBundle> nextPage({
    required String query,
    required SearchTab tab,
    required SearchBundle current,
    Set<SearchPlaceFilter> placeFilters = const {},
    Set<String> hashtags = const {},
  }) async {
    switch (tab) {
      case SearchTab.places:
        return _placePage(
          query,
          placeFilters,
          current.placeCursor,
          latitude: current.latitude,
          longitude: current.longitude,
        );
      case SearchTab.users:
        return _usersPage(query, current.userNextPage ?? 0);
      case SearchTab.posts:
        return _postPage(query, hashtags, current.postCursor);
    }
  }

  Future<SearchBundle> _placePage(
    String query,
    Set<SearchPlaceFilter> filters,
    String? cursor, {
    double? latitude,
    double? longitude,
  }) async {
    final data = await _auth.request(
      'GET',
      Uri(
        path: '/search/places',
        queryParameters: {
          'q': query,
          'size': '20',
          if (filters.isNotEmpty) 'filters': filters.map((f) => f.id).join(','),
          if (cursor != null) 'cursor': cursor,
          if (filters.contains(SearchPlaceFilter.nearby) && latitude != null)
            'latitude': '$latitude',
          if (filters.contains(SearchPlaceFilter.nearby) && longitude != null)
            'longitude': '$longitude',
        },
      ).toString(),
    );
    return SearchBundle(
      latitude: latitude,
      longitude: longitude,
      placeCursor: data['nextCursor'] as String?,
      places: (data['items'] as List)
          .map(
            (r) => SearchPlaceItem(
              id: (r['placeId'] as num).toInt(),
              name: r['name'] as String,
              location: [
                r['district'],
                r['province'],
              ].whereType<String>().join(', '),
              address: r['address'] as String?,
              category: r['categoryName'] as String?,
              rating: (r['avgRating'] as num?)?.toDouble() ?? 0,
              imageUrl: r['thumbnailUrl'] as String?,
              reviewCount: (r['reviewCount'] as num?)?.toInt() ?? 0,
              saveCount: (r['saveCount'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(),
    );
  }

  Future<SearchBundle> _usersPage(String query, int page) async {
    final data = await _auth.request(
      'GET',
      Uri(
        path: '/users/search',
        queryParameters: {'q': query, 'page': '$page', 'size': '20'},
      ).toString(),
    );
    final items = (data['items'] as List).map(_userFromJson).toList();
    return SearchBundle(
      users: items,
      userNextPage: (page + 1) * 20 < _int(data['total']) ? page + 1 : null,
    );
  }

  Future<SearchBundle> _postPage(
    String query,
    Set<String> hashtags,
    String? cursor,
  ) async {
    final data = await _auth.request(
      'GET',
      Uri(
        path: '/search/posts',
        queryParameters: {
          'q': query.startsWith('#') && hashtags.isNotEmpty ? '' : query,
          'size': '20',
          if (hashtags.isNotEmpty)
            'hashtags': hashtags
                .map((t) => t.replaceFirst(RegExp(r'^#'), ''))
                .join(','),
          if (cursor != null) 'cursor': cursor,
        },
      ).toString(),
    );
    return SearchBundle(
      postCursor: data['nextCursor'] as String?,
      posts: (data['items'] as List)
          .map(
            (r) => SearchPostItem(
              id: (r['id'] as num).toInt(),
              imageAsset: '',
              thumbnailPath: r['thumbnailUrl'] as String?,
              caption: r['caption'] as String,
              hashtags: (r['hashtags'] as List).map((t) => '#$t').toSet(),
            ),
          )
          .toList(),
    );
  }

  Future<List<SearchHashtagItem>> searchHashtags(String query) async {
    final data = await _auth.requestJson(
      'GET',
      Uri(path: '/search/hashtags', queryParameters: {'q': query}).toString(),
    );
    return (data as List)
        .map(
          (r) => SearchHashtagItem(
            tag: '#${r['tag']}',
            postCount: (r['postCount'] as num).toInt(),
          ),
        )
        .toList();
  }

  Future<SearchUserProfile> getUserProfile(String userId) async {
    final response = await _auth.request(
      'GET',
      '/users/${Uri.encodeComponent(userId)}',
    );
    return _profileFromJson(response);
  }

  Future<({List<SearchUserItem> items, int total})> profilePeople({
    required String userId,
    required bool friends,
    int page = 0,
  }) async {
    final kind = friends ? 'mutual-friends' : 'followers';
    final response = await _auth.request(
      'GET',
      '/users/${Uri.encodeComponent(userId)}/$kind?page=$page&size=50',
    );
    return (
      items: _asList(
        response['items'],
      ).map(_userFromJson).toList(growable: false),
      total: _int(response['total']),
    );
  }

  Future<SearchUserRelation> followUser(String userId) async {
    final response = await _auth.request(
      'PUT',
      '/users/${Uri.encodeComponent(userId)}/follow',
    );
    ContentAccessChanges.changed();
    return _relationFromJson(response);
  }

  Future<SearchUserRelation> unfollowUser(String userId) async {
    final response = await _auth.request(
      'DELETE',
      '/users/${Uri.encodeComponent(userId)}/follow',
    );
    ContentAccessChanges.changed();
    return _relationFromJson(response);
  }

  SearchPlaceItem _fromRecommended(RecommendedPlace place, int index) {
    final address = <String?>[
      place.address,
      place.district,
      place.province,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');

    return SearchPlaceItem(
      id: place.placeId,
      name: place.name,
      location: place.locationText,
      rating: place.rating,
      imageUrl: place.thumbnailUrl,
      description: place.description ?? place.displayReason,
      address: address.isEmpty ? place.locationText : address,
      reviewCount: place.reviewCount,
      saveCount: place.saveCount,
      category: place.displayCategory,
      filterTags: const <String>{},
    );
  }

  SearchUserItem _userFromJson(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    final nickname = _text(json['nickname']);
    final displayName = _text(
      json['displayName'],
      fallback: _text(json['fullName'], fallback: nickname),
    );
    final city = _text(json['city']);
    final bio = _text(json['bio']);
    final subtitle = city.isNotEmpty
        ? city
        : (bio.isNotEmpty
              ? bio
              : (nickname.isEmpty ? 'Người dùng GoMate' : '@$nickname'));

    return SearchUserItem(
      id: _text(json['userId']),
      name: displayName.isEmpty ? nickname : displayName,
      subtitle: subtitle,
      avatarUrl: _nullableText(json['avatarUrl']),
      relation: _relationFromJson(json),
    );
  }

  SearchUserProfile _profileFromJson(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    final nickname = _text(json['nickname']);
    final displayName = _text(json['displayName'], fallback: nickname);
    final stats = json['relationshipStats'] is Map
        ? json['relationshipStats'] as Map
        : const {};
    return SearchUserProfile(
      canInitiateMessage: json['canInitiateMessage'] == true,
      isBlockedByMe: json['isBlockedByMe'] == true,
      userId: _text(json['userId'], fallback: _text(json['id'])),
      nickname: nickname,
      displayName: displayName.isEmpty ? nickname : displayName,
      avatarUrl: _nullableText(json['avatarUrl']),
      city: _nullableText(json['city']),
      bio: _nullableText(json['bio']),
      isPrivate: _bool(json['isPrivate']),
      followingCount: _int(stats['followingCount']),
      followersCount: _int(stats['followersCount']),
      mutualFriendCount: _int(stats['mutualFriendCount']),
      relation: _relationFromJson(json),
    );
  }

  SearchUserRelation _relationFromJson(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    final followingByMe = _bool(json['followingByMe']);
    final followsMe = _bool(json['followsMe']);
    final mutualFriend = _bool(json['mutualFriend']);
    if (mutualFriend || (followingByMe && followsMe)) {
      return SearchUserRelation.friend;
    }
    if (followingByMe) return SearchUserRelation.following;
    if (_bool(json['followRequestPending'])) return SearchUserRelation.pending;
    if (followsMe) return SearchUserRelation.followsYou;
    return SearchUserRelation.none;
  }

  Set<String> _selectedContextCodes() {
    final raw = _auth.user?['interestCodes'];
    final values = <String>[];

    if (raw is List) {
      values.addAll(raw.map((item) => item.toString()));
    } else if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          values.addAll(decoded.map((item) => item.toString()));
        }
      } catch (_) {
        values.addAll(raw.split(','));
      }
    }

    return values.map((value) => value.trim()).where((value) {
      return value == 'GAN_TOI' ||
          value == 'LOCAL' ||
          value == 'DANG_HOT' ||
          value == 'DI_TRONG_NGAY' ||
          value == 'CO_REVIEW' ||
          value == 'UU_TIEN_KHAC';
    }).toSet();
  }

  List<Object?> _asList(Object? value) {
    if (value is List) return value;
    return const <Object?>[];
  }

  String _text(Object? value, {String fallback = ''}) {
    if (value is! String) return fallback;
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String? _nullableText(Object? value) {
    final text = _text(value);
    return text.isEmpty ? null : text;
  }

  int _int(Object? value) {
    if (value is num) return value.toInt();
    return 0;
  }

  bool _bool(Object? value) => value == true;
}
