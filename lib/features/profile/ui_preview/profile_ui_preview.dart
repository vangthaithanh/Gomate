import '../../map/screens/place_detail_screen.dart';
import '../../search/models/search_models.dart';
import '../widgets/profile_ui_widgets.dart';

/// TODO(BACKEND-PROFILE-UI-PREVIEW): Delete this entire file, then remove
/// `ProfileUiPreview` references when the server supports public/private
/// relationship requests, posts-by-author, followers/friends and saved places.
///
/// IMPORTANT: These IDs are NOT backend identifiers. This class must NEVER
/// be used as an input to AuthService, SearchRepository or MessageRepository.
class ProfileUiPreview {
  ProfileUiPreview._();

  /// Switch OFF in production. Default ON so QA can visit all UI states.
  static const bool enabled = false;

  static const String selfId = 'ui-preview-self';

  static const List<ProfilePreviewPerson> people = [
    ProfilePreviewPerson(
      id: 'ui-preview-public',
      nickname: 'thune',
      name: 'Xuân Thu',
      avatar: 'assets/map/member_thu.png',
      bio: 'Thích khám phá những nơi mới và ghi lại từng khoảnh khắc.',
      isPrivate: false,
      initialRelation: SearchUserRelation.none,
      followersCount: 4200,
      friendsCount: 20,
    ),
    ProfilePreviewPerson(
      id: 'ui-preview-private',
      nickname: 'dadada',
      name: 'Thanh Thúy',
      avatar: 'assets/map/member_an.png',
      bio: 'Những ngày bình yên.',
      isPrivate: true,
      initialRelation: SearchUserRelation.none,
      followersCount: 126,
      friendsCount: 18,
    ),
    ProfilePreviewPerson(
      id: 'ui-preview-friend',
      nickname: 'banthan',
      name: 'Bạn đồng hành',
      avatar: 'assets/map/member_an.png',
      bio: 'Bạn bè cùng đi du lịch, có khoảnh khắc để thử ẩn/bỏ ẩn.',
      isPrivate: false,
      initialRelation: SearchUserRelation.friend,
      followersCount: 230,
      friendsCount: 36,
    ),
    ProfilePreviewPerson(
      id: 'ui-preview-private-approved',
      nickname: 'chithanh',
      name: 'Chí Thành',
      avatar: 'assets/map/member_thu.png',
      bio: 'Cùng nhau đi đến những vùng đất mới.',
      isPrivate: true,
      initialRelation: SearchUserRelation.following,
      followersCount: 310,
      friendsCount: 32,
    ),
  ];

  static ProfilePreviewPerson? findPerson(String id) {
    for (final item in people) {
      if (item.id == id) return item;
    }
    return null;
  }

  static bool isPreviewId(String id) => id == selfId || findPerson(id) != null;

  // TODO(BACKEND-PROFILE-UI-PREVIEW): all preview rows must agree with the
  // destination profile relation. Previously people[1] was marked friend in
  // a row, but its profile itself had relation=none. The 3-dot menu therefore
  // correctly hid the moment option when navigating from that list.
  static List<SearchUserItem> get followerRows => [
    SearchUserItem(
      id: people[0].id,
      name: people[0].name,
      subtitle: '@${people[0].nickname}',
      avatarAsset: people[0].avatar,
      relation: SearchUserRelation.followsYou,
    ),
    SearchUserItem(
      id: people[2].id,
      name: people[2].name,
      subtitle: '@${people[2].nickname}',
      avatarAsset: people[2].avatar,
      relation: SearchUserRelation.friend,
    ),
  ];

  // Only actual mutual-friend preview profiles belong to the Friends tab.
  // `people[3]` is following-only and `people[1]` is private/unfollowed.
  static List<SearchUserItem> get friendRows => [
    SearchUserItem(
      id: people[2].id,
      name: people[2].name,
      subtitle: '@${people[2].nickname}',
      avatarAsset: people[2].avatar,
      relation: SearchUserRelation.friend,
    ),
  ];

  /// Local-only visuals. None of the items should be interpreted as a post
  /// fetched from the current account's real social feed.
  static List<GoMateProfilePostPreview> posts({
    required String authorId,
    required String authorName,
    String? authorAvatar,
  }) => [
    GoMateProfilePostPreview(
      id: 'ui-preview-post-a-$authorId',
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      location: 'Đà Nẵng',
      caption: 'Một chuyến đi thật nhiều kỷ niệm 🌿',
      media: ['assets/images/checkin.jpg', 'assets/images/nghiduong.jpg'],
      likeCount: 28,
      commentCount: 4,
    ),
    GoMateProfilePostPreview(
      id: 'ui-preview-post-b-$authorId',
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      location: 'Việt Nam',
      caption: 'Lưu giữ những khoảnh khắc bình yên.',
      media: ['assets/images/thiennhien.jpg'],
      likeCount: 84,
      commentCount: 12,
    ),
    GoMateProfilePostPreview(
      id: 'ui-preview-post-c-$authorId',
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      location: 'Miền Trung',
      caption: 'Hành trình tiếp theo bắt đầu từ đây.',
      media: ['assets/images/lichsu.jpg', 'assets/images/survey_beach.jpg'],
      likeCount: 16,
      commentCount: 3,
    ),
    GoMateProfilePostPreview(
      id: 'ui-preview-post-d-$authorId',
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      location: 'Việt Nam',
      caption: 'Cùng GoMate khám phá nhiều hơn.',
      media: ['assets/images/survey_culture.jpg'],
      likeCount: 63,
      commentCount: 7,
    ),
  ];

  /// These models exist only to preview the layout and can be opened inside
  /// the already-existing PlaceDetailScreen. Do not add them to FavoritePlaceStore
  /// or use these IDs in create-trip / itinerary / upload actions.
  static const List<MapPlaceUi> favoritePlaces = [
    MapPlaceUi(
      id: 'ui-preview-place-1',
      name: 'Cầu Vàng – Bà Nà Hills',
      subtitle: 'Điểm đến nổi bật',
      address: 'Hòa Vang, Đà Nẵng',
      distanceText: '',
      openInfo: 'Thông tin xem thử',
      priceInfo: '',
      rating: 4.8,
      reviewCount: 120,
      likeCount: 980,
      tags: ['Đà Nẵng', 'Check-in'],
      imageAsset: 'assets/images/checkin.jpg',
      mediaUrls: ['assets/images/checkin.jpg'],
    ),
    MapPlaceUi(
      id: 'ui-preview-place-2',
      name: 'Điểm khám phá thiên nhiên',
      subtitle: 'Thiên nhiên',
      address: 'Việt Nam',
      distanceText: '',
      openInfo: 'Thông tin xem thử',
      priceInfo: '',
      rating: 4.6,
      reviewCount: 45,
      likeCount: 350,
      tags: ['Thiên nhiên'],
      imageAsset: 'assets/images/thiennhien.jpg',
      mediaUrls: ['assets/images/thiennhien.jpg'],
    ),
    MapPlaceUi(
      id: 'ui-preview-place-3',
      name: 'Khu nghỉ dưỡng ven biển',
      subtitle: 'Nghỉ dưỡng',
      address: 'Miền Trung, Việt Nam',
      distanceText: '',
      openInfo: 'Thông tin xem thử',
      priceInfo: '',
      rating: 4.7,
      reviewCount: 78,
      likeCount: 540,
      tags: ['Nghỉ dưỡng'],
      imageAsset: 'assets/images/nghiduong.jpg',
      mediaUrls: ['assets/images/nghiduong.jpg'],
    ),
  ];
}

class ProfilePreviewPerson {
  final String id;
  final String nickname;
  final String name;
  final String avatar;
  final String bio;
  final bool isPrivate;
  final SearchUserRelation initialRelation;
  final int followersCount;
  final int friendsCount;

  const ProfilePreviewPerson({
    required this.id,
    required this.nickname,
    required this.name,
    required this.avatar,
    required this.bio,
    required this.isPrivate,
    required this.initialRelation,
    required this.followersCount,
    required this.friendsCount,
  });

  SearchUserProfile asProfile({SearchUserRelation? relation}) =>
      SearchUserProfile(
        userId: id,
        nickname: nickname,
        displayName: name,
        avatarUrl: avatar,
        bio: bio,
        followersCount: followersCount,
        mutualFriendCount: friendsCount,
        relation: relation ?? initialRelation,
      );
}
