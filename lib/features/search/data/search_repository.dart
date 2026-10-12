import 'dart:convert';

import '../../../core/services/auth_service.dart';
import '../../map/services/location_service.dart';
import '../../recommendation/data/recommendation_repository.dart';
import '../../recommendation/models/recommendation_models.dart';
import '../models/search_models.dart';

/// Điểm nối duy nhất giữa UI Search và data layer.
///
/// Hiện tại:
/// - Gợi ý địa điểm dùng Recommendation backend đang có của GoMate.
/// - Search user dùng `/api/v1/users/search` và quan hệ follow thật.
/// - Search post, lịch sử và hashtag vẫn là dữ liệu UI mẫu.
class SearchRepository {
  final RecommendationRepository _recommendationRepository;
  final GoMateLocationService _locationService;

  SearchRepository({
    RecommendationRepository? recommendationRepository,
    GoMateLocationService? locationService,
  }) : _recommendationRepository =
           recommendationRepository ?? RecommendationRepository(),
       _locationService = locationService ?? GoMateLocationService();

  List<SearchPlaceItem> _cachedRecommendedPlaces = const <SearchPlaceItem>[];

  final List<String> _recentSearches = <String>[
    // UI demo theo mockup. Khi nối backend, thay bằng lịch sử thật.
    'Thune',
    'Biển hồ',
  ];

  static const List<SearchPostItem> _demoPosts = <SearchPostItem>[
    SearchPostItem(
      id: 1,
      imageAsset: 'assets/images/home/post_1_1.jpg',
      caption: 'Du lịch Đà Nẵng cùng bạn bè',
      hashtags: <String>{'#Hashtag', '#Danang', '#Dulich'},
    ),
    SearchPostItem(
      id: 2,
      imageAsset: 'assets/images/home/post_1_2.jpg',
      caption: 'Đà Nẵng và những ngày thật đẹp',
      hashtags: <String>{'#Hashtag', '#Danang'},
    ),
    SearchPostItem(
      id: 3,
      imageAsset: 'assets/images/home/post_2_1.jpg',
      caption: 'Khám phá thiên nhiên',
      hashtags: <String>{'#Hashtag', '#Dulich'},
    ),
    SearchPostItem(
      id: 4,
      imageAsset: 'assets/images/home/post_2_2.jpg',
      caption: 'Checkin cuối tuần',
      hashtags: <String>{'#Checkin', '#Dulich'},
    ),
    SearchPostItem(
      id: 5,
      imageAsset: 'assets/images/home/post_3_1.jpg',
      caption: 'Đà Nẵng trong chuyến đi mới',
      hashtags: <String>{'#Danang', '#Dulich'},
    ),
    SearchPostItem(
      id: 6,
      imageAsset: 'assets/images/home/post_4_1.jpg',
      caption: 'Một ngày trên núi',
      hashtags: <String>{'#Hashtag', '#ThienNhien'},
    ),
  ];

  static const List<SearchHashtagItem> _hashtags = <SearchHashtagItem>[
    SearchHashtagItem(tag: '#Hashtag', postCount: 120),
    SearchHashtagItem(tag: '#Danang', postCount: 120),
    SearchHashtagItem(tag: '#Dulich', postCount: 120),
    SearchHashtagItem(tag: '#Checkin', postCount: 78),
    SearchHashtagItem(tag: '#ThienNhien', postCount: 64),
  ];

  Future<List<SearchPlaceItem>> getSuggestedPlaces() async {
    double? latitude;
    double? longitude;

    if (_selectedContextCodes().contains('GAN_TOI')) {
      try {
        final location = await _locationService.getCurrentLocation();
        if (location.state == GoMateLocationState.ready &&
            location.position != null) {
          latitude = location.position!.latitude;
          longitude = location.position!.longitude;
        }
      } catch (_) {
        // Recommendation vẫn hoạt động khi GPS không sẵn sàng.
      }
    }

    final response = await _recommendationRepository.getMine(
      // Search Discovery tải nhiều hơn Home (Home chỉ hiển thị 10).
      // Backend production nên chuyển sang pagination/cursor thay vì hard-limit.
      topK: 50,
      latitude: latitude,
      longitude: longitude,
    );

    final items = response.items
        .where((place) => place.placeId > 0)
        .toList(growable: false);

    _cachedRecommendedPlaces = List<SearchPlaceItem>.generate(
      items.length,
      (index) => _fromRecommended(items[index], index),
      growable: false,
    );

    return _cachedRecommendedPlaces;
  }

  Future<List<String>> getRecentSearches() async {
    return List<String>.unmodifiable(_recentSearches);
  }

  Future<void> saveRecentSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    _recentSearches.removeWhere(
      (item) => _normalize(item) == _normalize(clean),
    );
    _recentSearches.insert(0, clean);

    if (_recentSearches.length > 8) {
      _recentSearches.removeRange(8, _recentSearches.length);
    }
  }

  Future<void> removeRecentSearch(String query) async {
    _recentSearches.removeWhere(
      (item) => _normalize(item) == _normalize(query),
    );
  }

  Future<SearchBundle> search({
    required String query,
    Set<SearchPlaceFilter> placeFilters = const <SearchPlaceFilter>{},
    Set<String> hashtags = const <String>{},
  }) async {
    final normalizedQuery = _normalize(query);

    var places = _cachedRecommendedPlaces;
    if (places.isEmpty) {
      try {
        places = await getSuggestedPlaces();
      } catch (_) {
        places = const <SearchPlaceItem>[];
      }
    }

    final placeResults = places
        .where((place) {
          final matchesQuery =
              normalizedQuery.isEmpty ||
              _normalize(place.name).contains(normalizedQuery) ||
              _normalize(place.location).contains(normalizedQuery) ||
              _normalize(place.category ?? '').contains(normalizedQuery);

          final matchesFilters =
              placeFilters.isEmpty ||
              placeFilters.every(
                (filter) => place.filterTags.contains(filter.id),
              );

          return matchesQuery && matchesFilters;
        })
        .toList(growable: false);

    final userResults = normalizedQuery.isEmpty
        ? const <SearchUserItem>[]
        : await _searchUsers(query, size: 20);

    final postResults = _demoPosts
        .where((post) {
          final matchesQuery =
              normalizedQuery.isEmpty ||
              _normalize(post.caption).contains(normalizedQuery) ||
              post.hashtags.any(
                (tag) => _normalize(tag).contains(normalizedQuery),
              );

          final matchesHashtags =
              hashtags.isEmpty || hashtags.every(post.hashtags.contains);

          return matchesQuery && matchesHashtags;
        })
        .toList(growable: false);

    return SearchBundle(
      places: placeResults,
      users: userResults,
      posts: postResults,
    );
  }

  Future<List<SearchHashtagItem>> searchHashtags(String query) async {
    final normalizedQuery = _normalize(query);

    if (normalizedQuery.isEmpty) {
      return _hashtags;
    }

    return _hashtags
        .where((item) => _normalize(item.tag).contains(normalizedQuery))
        .toList(growable: false);
  }

  Future<SearchUserProfile> getUserProfile(String userId) async {
    final response = await AuthService.instance.request(
      'GET',
      '/users/${Uri.encodeComponent(userId)}',
    );
    return _profileFromJson(response);
  }

  Future<SearchUserRelation> followUser(String userId) async {
    final response = await AuthService.instance.request(
      'PUT',
      '/users/${Uri.encodeComponent(userId)}/follow',
    );
    return _relationFromJson(response);
  }

  Future<SearchUserRelation> unfollowUser(String userId) async {
    final response = await AuthService.instance.request(
      'DELETE',
      '/users/${Uri.encodeComponent(userId)}/follow',
    );
    return _relationFromJson(response);
  }

  Future<List<SearchUserItem>> _searchUsers(
    String query, {
    int size = 20,
  }) async {
    final uri = Uri(
      path: '/users/search',
      queryParameters: <String, String>{
        'q': query.trim(),
        'page': '0',
        'size': size.toString(),
      },
    );
    final response = await AuthService.instance.request('GET', uri.toString());
    return _asList(response['items'])
        .map(_userFromJson)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  SearchPlaceItem _fromRecommended(RecommendedPlace place, int index) {
    final rating = place.rating > 0
        ? place.rating
        : place.score.clamp(0, 5).toDouble();

    // Tags demo chỉ phục vụ UI filter trước khi endpoint search/filter hoàn thiện.
    // Khi backend có filter thật, map category/tag thật vào đây.
    final tags = <String>{
      if (index % 2 == 0) SearchPlaceFilter.nature.id,
      if (index % 3 == 0) SearchPlaceFilter.checkin.id,
      if (index % 4 == 0) SearchPlaceFilter.history.id,
      if (index % 2 == 1) SearchPlaceFilter.nearby.id,
    };

    if (tags.isEmpty) {
      tags.add(SearchPlaceFilter.nature.id);
    }

    final address = <String?>[
      place.address,
      place.district,
      place.province,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');

    return SearchPlaceItem(
      id: place.placeId,
      name: place.name,
      location: place.locationText,
      rating: rating,
      imageUrl: place.thumbnailUrl,
      description: place.description ?? place.displayReason,
      address: address.isEmpty ? place.locationText : address,
      reviewCount: place.reviewCount,
      saveCount: place.saveCount,
      category: place.displayCategory,
      filterTags: tags,
    );
  }

  SearchUserItem _userFromJson(Object? value) {
    final json = value is Map ? value : const <String, dynamic>{};
    final nickname = _text(json['nickname']);
    final displayName = _text(json['displayName'], fallback: nickname);
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
      userId: _text(json['userId'], fallback: _text(json['id'])),
      nickname: nickname,
      displayName: displayName.isEmpty ? nickname : displayName,
      avatarUrl: _nullableText(json['avatarUrl']),
      city: _nullableText(json['city']),
      bio: _nullableText(json['bio']),
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
    if (followsMe) return SearchUserRelation.followsYou;
    return SearchUserRelation.none;
  }

  Set<String> _selectedContextCodes() {
    final raw = AuthService.instance.user?['interestCodes'];
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

  String _normalize(String value) {
    const source =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
        'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const target =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

    var result = value.trim().toLowerCase();

    for (var i = 0; i < source.length; i++) {
      result = result.replaceAll(source[i], target[i].toLowerCase());
    }

    return result;
  }
}
