enum SearchTab { places, users, posts }

enum SearchUserRelation { friend, following, followsYou, none, pending }

enum SearchPlaceFilter {
  nature('nature', 'Thiên nhiên'),
  checkin('checkin', 'Checkin'),
  history('history', 'Di tích lịch sử'),
  nearby('nearby', 'Gần tôi');

  final String id;
  final String label;

  const SearchPlaceFilter(this.id, this.label);
}

class SearchPlaceItem {
  final int id;
  final String name;
  final String location;
  final double rating;
  final String? imageUrl;
  final String? description;
  final String? address;
  final int reviewCount;
  final int saveCount;
  final String? category;
  final Set<String> filterTags;

  const SearchPlaceItem({
    required this.id,
    required this.name,
    required this.location,
    required this.rating,
    required this.imageUrl,
    this.description,
    this.address,
    this.reviewCount = 0,
    this.saveCount = 0,
    this.category,
    this.filterTags = const <String>{},
  });
}

class SearchUserItem {
  final String id;
  final String name;
  final String subtitle;
  final String? avatarUrl;
  final String? avatarAsset;
  final SearchUserRelation relation;

  const SearchUserItem({
    required this.id,
    required this.name,
    required this.subtitle,
    this.avatarUrl,
    this.avatarAsset,
    this.relation = SearchUserRelation.none,
  });

  String? get actionLabel {
    switch (relation) {
      case SearchUserRelation.friend:
        return 'Bạn bè';
      case SearchUserRelation.following:
        return 'Đang theo dõi';
      case SearchUserRelation.followsYou:
        return 'Theo dõi lại';
      case SearchUserRelation.none:
        return 'Theo dõi';
      case SearchUserRelation.pending:
        return 'Chờ xác nhận';
    }
  }
}

class SearchUserProfile {
  final bool canInitiateMessage;
  final bool isBlockedByMe;
  final String userId;
  final String nickname;
  final String displayName;
  final String? avatarUrl;
  final String? city;
  final String? bio;
  final bool isPrivate;
  final int followingCount;
  final int followersCount;
  final int mutualFriendCount;
  final SearchUserRelation relation;

  const SearchUserProfile({
    this.canInitiateMessage = false,
    this.isBlockedByMe = false,
    required this.userId,
    required this.nickname,
    required this.displayName,
    this.avatarUrl,
    this.city,
    this.bio,
    this.isPrivate = false,
    this.followingCount = 0,
    this.followersCount = 0,
    this.mutualFriendCount = 0,
    this.relation = SearchUserRelation.none,
  });

  SearchUserProfile copyWith({
    SearchUserRelation? relation,
    int? followingCount,
    int? followersCount,
    int? mutualFriendCount,
  }) {
    return SearchUserProfile(
      canInitiateMessage: canInitiateMessage,
      isBlockedByMe: isBlockedByMe,
      userId: userId,
      nickname: nickname,
      displayName: displayName,
      avatarUrl: avatarUrl,
      city: city,
      bio: bio,
      isPrivate: isPrivate,
      followingCount: followingCount ?? this.followingCount,
      followersCount: followersCount ?? this.followersCount,
      mutualFriendCount: mutualFriendCount ?? this.mutualFriendCount,
      relation: relation ?? this.relation,
    );
  }
}

class SearchPostItem {
  final int id;
  final String? thumbnailPath;
  final String imageAsset;
  final String caption;
  final Set<String> hashtags;

  const SearchPostItem({
    required this.id,
    required this.imageAsset,
    this.thumbnailPath,
    required this.caption,
    this.hashtags = const <String>{},
  });
}

class SearchHashtagItem {
  final String tag;
  final int postCount;

  const SearchHashtagItem({required this.tag, required this.postCount});
}

class SearchBundle {
  final String? placeError;
  final double? latitude;
  final double? longitude;
  final String? placeCursor;
  final String? postCursor;
  final int? userNextPage;
  final List<SearchPlaceItem> places;
  final List<SearchUserItem> users;
  final List<SearchPostItem> posts;

  const SearchBundle({
    this.placeError,
    this.latitude,
    this.longitude,
    this.placeCursor,
    this.postCursor,
    this.userNextPage,
    this.places = const <SearchPlaceItem>[],
    this.users = const <SearchUserItem>[],
    this.posts = const <SearchPostItem>[],
  });

  bool get isEmpty => places.isEmpty && users.isEmpty && posts.isEmpty;
}
