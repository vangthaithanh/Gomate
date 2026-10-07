import 'package:flutter/foundation.dart';

import '../../../core/widgets/gomate_emoji.dart';
import '../models/moment_models.dart';

abstract class MomentsRepository extends ChangeNotifier {
  List<MomentFriendPreview> get stripItems;

  List<MomentItem> get myMoments;

  List<MomentItem> get activeOwnMoments;

  int get activeOwnMomentCount;

  /// Toàn bộ khoảnh khắc của bạn bè 2 chiều mà user hiện chưa xem.
  /// Dùng cho thumbnail + badge ở màn Ảnh khoảnh khắc.
  List<MomentItem> get availableFriendMoments;

  int get availableFriendMomentCount;

  List<GoMateEmojiType> get frequentReactions;

  bool hasAvailableMomentForName(String name);

  List<MomentItem> availableQueue({required String startUserId});

  MomentItem? momentById(String id);

  void markViewed(String momentId);

  void muteUser(String userId);

  void reactToMoment(String momentId, GoMateEmojiType emoji);

  void deleteMoments(Set<String> momentIds);

  Future<void> sendMessage({
    required String receiverUserId,
    required String message,
  });
}

class DemoMomentsRepository extends MomentsRepository {
  DemoMomentsRepository._() {
    _seed();
  }

  static final DemoMomentsRepository instance = DemoMomentsRepository._();

  final Set<String> _mutedUserIds = <String>{};
  final Map<GoMateEmojiType, int> _reactionUsage = <GoMateEmojiType, int>{};

  late final List<_DemoFriend> _friends;
  late List<MomentItem> _moments;

  static const String currentUserId = 'me';

  void _seed() {
    final now = DateTime.now();

    _friends = const [
      _DemoFriend(
        userId: currentUserId,
        name: 'Bạn',
        avatarAsset: 'assets/images/checkin.jpg',
        isMutualFriend: true,
      ),
      _DemoFriend(
        userId: 'chithanh',
        name: 'ChiThanh',
        avatarAsset: 'assets/images/ketban.jpg',
        isMutualFriend: true,
      ),
      _DemoFriend(
        userId: 'thune',
        name: 'Thune',
        avatarAsset: 'assets/images/thiennhien.jpg',
        isMutualFriend: true,
      ),
      _DemoFriend(
        userId: 'buji',
        name: 'Buji',
        avatarAsset: 'assets/images/survey_city.jpg',
        isMutualFriend: true,
      ),
      _DemoFriend(
        userId: 'bum',
        name: 'Bum',
        avatarAsset: 'assets/images/survey_country.jpg',
        isMutualFriend: true,
      ),
      // Demo boundary: người này không phải bạn bè 2 chiều nên không xuất hiện.
      _DemoFriend(
        userId: 'one-way-follow',
        name: 'Một chiều',
        avatarAsset: 'assets/images/survey_beach.jpg',
        isMutualFriend: false,
      ),
    ];

    MomentReaction chiThanhHeart() {
      return MomentReaction(
        userId: 'chithanh',
        userName: 'ChiThanh',
        avatarAsset: 'assets/images/ketban.jpg',
        emoji: GoMateEmojiType.heart,
        reactedAt: now.subtract(const Duration(minutes: 18)),
      );
    }

    _moments = [
      MomentItem(
        id: 'friend-chi-1',
        ownerId: 'chithanh',
        ownerName: 'ChiThanh',
        ownerAvatarAsset: 'assets/images/ketban.jpg',
        imageAsset: 'assets/images/thiennhien.jpg',
        createdAt: now.subtract(const Duration(minutes: 19)),
        locationText: 'Hồ Xuân Hương, Đà Lạt',
        isOwn: false,
        isViewedByCurrentUser: false,
        reactions: const [],
      ),
      MomentItem(
        id: 'friend-chi-2',
        ownerId: 'chithanh',
        ownerName: 'ChiThanh',
        ownerAvatarAsset: 'assets/images/ketban.jpg',
        imageAsset: 'assets/images/survey_beach.jpg',
        createdAt: now.subtract(const Duration(minutes: 31)),
        locationText: null,
        isOwn: false,
        isViewedByCurrentUser: false,
        reactions: const [],
      ),
      MomentItem(
        id: 'friend-thune-1',
        ownerId: 'thune',
        ownerName: 'Thune',
        ownerAvatarAsset: 'assets/images/thiennhien.jpg',
        imageAsset: 'assets/images/survey_city.jpg',
        createdAt: now.subtract(const Duration(hours: 1, minutes: 12)),
        locationText: 'Đà Nẵng',
        isOwn: false,
        isViewedByCurrentUser: false,
        reactions: const [],
      ),
      MomentItem(
        id: 'friend-buji-1',
        ownerId: 'buji',
        ownerName: 'Buji',
        ownerAvatarAsset: 'assets/images/survey_city.jpg',
        imageAsset: 'assets/images/survey_country.jpg',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 8)),
        locationText: null,
        isOwn: false,
        isViewedByCurrentUser: false,
        reactions: const [],
      ),
      MomentItem(
        id: 'me-live-1',
        ownerId: currentUserId,
        ownerName: 'Bạn',
        ownerAvatarAsset: 'assets/images/checkin.jpg',
        imageAsset: 'assets/images/checkin.jpg',
        createdAt: now.subtract(const Duration(hours: 2)),
        locationText: 'Phố cổ, Hội An',
        isOwn: true,
        isViewedByCurrentUser: true,
        reactions: [chiThanhHeart()],
      ),
      MomentItem(
        id: 'me-live-2',
        ownerId: currentUserId,
        ownerName: 'Bạn',
        ownerAvatarAsset: 'assets/images/checkin.jpg',
        imageAsset: 'assets/images/survey_checkin.jpg',
        createdAt: now.subtract(const Duration(hours: 7)),
        locationText: 'Hội An',
        isOwn: true,
        isViewedByCurrentUser: true,
        reactions: const [],
      ),
      MomentItem(
        id: 'me-sep-30',
        ownerId: currentUserId,
        ownerName: 'Bạn',
        ownerAvatarAsset: 'assets/images/checkin.jpg',
        imageAsset: 'assets/images/checkin.jpg',
        createdAt: DateTime(now.year, 9, 30, 20, 30),
        locationText: 'Phố cổ, Hội An',
        isOwn: true,
        isViewedByCurrentUser: true,
        reactions: [chiThanhHeart()],
      ),
      MomentItem(
        id: 'me-sep-22',
        ownerId: currentUserId,
        ownerName: 'Bạn',
        ownerAvatarAsset: 'assets/images/checkin.jpg',
        imageAsset: 'assets/images/lichsu.jpg',
        createdAt: DateTime(now.year, 9, 22, 17, 15),
        locationText: 'Huế',
        isOwn: true,
        isViewedByCurrentUser: true,
        reactions: const [],
      ),
      MomentItem(
        id: 'me-sep-12',
        ownerId: currentUserId,
        ownerName: 'Bạn',
        ownerAvatarAsset: 'assets/images/checkin.jpg',
        imageAsset: 'assets/images/survey_food.jpg',
        createdAt: DateTime(now.year, 9, 12, 12, 5),
        locationText: 'TP. Hồ Chí Minh',
        isOwn: true,
        isViewedByCurrentUser: true,
        reactions: const [],
      ),
      MomentItem(
        id: 'me-sep-04',
        ownerId: currentUserId,
        ownerName: 'Bạn',
        ownerAvatarAsset: 'assets/images/checkin.jpg',
        imageAsset: 'assets/images/survey_landmark.jpg',
        createdAt: DateTime(now.year, 9, 4, 9, 45),
        locationText: 'Đà Nẵng',
        isOwn: true,
        isViewedByCurrentUser: true,
        reactions: const [],
      ),
      MomentItem(
        id: 'me-aug-28',
        ownerId: currentUserId,
        ownerName: 'Bạn',
        ownerAvatarAsset: 'assets/images/checkin.jpg',
        imageAsset: 'assets/images/survey_resort.jpg',
        createdAt: DateTime(now.year, 8, 28, 15, 20),
        locationText: 'Nha Trang',
        isOwn: true,
        isViewedByCurrentUser: true,
        reactions: const [],
      ),
      MomentItem(
        id: 'me-aug-20',
        ownerId: currentUserId,
        ownerName: 'Bạn',
        ownerAvatarAsset: 'assets/images/checkin.jpg',
        imageAsset: 'assets/images/nghiduong.jpg',
        createdAt: DateTime(now.year, 8, 20, 16, 10),
        locationText: 'Phú Quốc',
        isOwn: true,
        isViewedByCurrentUser: true,
        reactions: const [],
      ),
      MomentItem(
        id: 'me-aug-11',
        ownerId: currentUserId,
        ownerName: 'Bạn',
        ownerAvatarAsset: 'assets/images/checkin.jpg',
        imageAsset: 'assets/images/survey_country.jpg',
        createdAt: DateTime(now.year, 8, 11, 10, 40),
        locationText: 'Đà Lạt',
        isOwn: true,
        isViewedByCurrentUser: true,
        reactions: const [],
      ),
      MomentItem(
        id: 'me-aug-03',
        ownerId: currentUserId,
        ownerName: 'Bạn',
        ownerAvatarAsset: 'assets/images/checkin.jpg',
        imageAsset: 'assets/images/survey_culture.jpg',
        createdAt: DateTime(now.year, 8, 3, 8, 30),
        locationText: 'Hà Nội',
        isOwn: true,
        isViewedByCurrentUser: true,
        reactions: const [],
      ),
    ];
  }

  bool _isWithin24Hours(MomentItem moment) {
    return DateTime.now().difference(moment.createdAt) < const Duration(hours: 24);
  }

  List<MomentItem> _availableForUser(String userId) {
    if (_mutedUserIds.contains(userId)) return const [];

    final values = _moments.where((moment) {
      return !moment.isOwn &&
          moment.ownerId == userId &&
          !moment.isViewedByCurrentUser;
    }).toList();

    values.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  }

  @override
  List<MomentFriendPreview> get stripItems {
    final self = _friends.firstWhere((friend) => friend.userId == currentUserId);

    final friendItems = _friends
        .where((friend) => friend.userId != currentUserId && friend.isMutualFriend)
        .map((friend) {
      final available = _availableForUser(friend.userId);
      return MomentFriendPreview(
        userId: friend.userId,
        name: friend.name,
        avatarAsset: friend.avatarAsset,
        isSelf: false,
        isMutualFriend: true,
        isMuted: _mutedUserIds.contains(friend.userId),
        hasAvailableMoment: available.isNotEmpty,
        latestMomentAt: available.isEmpty ? null : available.first.createdAt,
      );
    }).toList();

    friendItems.sort((a, b) {
      if (a.hasAvailableMoment != b.hasAvailableMoment) {
        return a.hasAvailableMoment ? -1 : 1;
      }

      if (a.hasAvailableMoment && b.hasAvailableMoment) {
        return b.latestMomentAt!.compareTo(a.latestMomentAt!);
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return [
      MomentFriendPreview(
        userId: self.userId,
        name: self.name,
        avatarAsset: self.avatarAsset,
        isSelf: true,
        isMutualFriend: true,
        isMuted: false,
        hasAvailableMoment: activeOwnMomentCount > 0,
        latestMomentAt:
            activeOwnMoments.isEmpty ? null : activeOwnMoments.first.createdAt,
      ),
      ...friendItems,
    ];
  }

  @override
  List<MomentItem> get myMoments {
    final values = _moments.where((moment) => moment.isOwn).toList();
    values.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  }

  @override
  List<MomentItem> get activeOwnMoments {
    return myMoments.where(_isWithin24Hours).toList(growable: false);
  }

  @override
  int get activeOwnMomentCount => activeOwnMoments.length;

  @override
  List<MomentItem> get availableFriendMoments {
    final activeFriends = stripItems
        .where((item) => !item.isSelf && item.hasAvailableMoment)
        .toList(growable: false);

    return [
      for (final friend in activeFriends) ..._availableForUser(friend.userId),
    ];
  }

  @override
  int get availableFriendMomentCount => availableFriendMoments.length;

  @override
  List<GoMateEmojiType> get frequentReactions {
    final ranked = _reactionUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final result = ranked.map((entry) => entry.key).take(3).toList();

    for (final fallback in GoMateEmojiCatalog.defaults) {
      if (result.length >= 3) break;
      if (!result.contains(fallback)) result.add(fallback);
    }

    return result;
  }

  @override
  bool hasAvailableMomentForName(String name) {
    for (final item in stripItems) {
      if (!item.isSelf && item.name == name) {
        return item.hasAvailableMoment;
      }
    }
    return false;
  }

  @override
  List<MomentItem> availableQueue({required String startUserId}) {
    final activeFriends = stripItems
        .where((item) => !item.isSelf && item.hasAvailableMoment)
        .toList();

    final startIndex = activeFriends.indexWhere((item) => item.userId == startUserId);
    if (startIndex > 0) {
      final before = activeFriends.take(startIndex).toList();
      final after = activeFriends.skip(startIndex).toList();
      activeFriends
        ..clear()
        ..addAll(after)
        ..addAll(before);
    }

    return [
      for (final friend in activeFriends) ..._availableForUser(friend.userId),
    ];
  }

  @override
  MomentItem? momentById(String id) {
    for (final moment in _moments) {
      if (moment.id == id) return moment;
    }
    return null;
  }

  @override
  void markViewed(String momentId) {
    final index = _moments.indexWhere((moment) => moment.id == momentId);
    if (index < 0 || _moments[index].isOwn || _moments[index].isViewedByCurrentUser) {
      return;
    }

    _moments[index] = _moments[index].copyWith(isViewedByCurrentUser: true);
    notifyListeners();
  }

  @override
  void muteUser(String userId) {
    if (_mutedUserIds.add(userId)) {
      notifyListeners();
    }
  }

  @override
  void reactToMoment(String momentId, GoMateEmojiType emoji) {
    final index = _moments.indexWhere((moment) => moment.id == momentId);
    if (index < 0) return;

    final current = _moments[index];
    final reactions = List<MomentReaction>.from(current.reactions)
      ..removeWhere((reaction) => reaction.userId == currentUserId)
      ..add(
        MomentReaction(
          userId: currentUserId,
          userName: 'Bạn',
          avatarAsset: 'assets/images/checkin.jpg',
          emoji: emoji,
          reactedAt: DateTime.now(),
        ),
      );

    _reactionUsage.update(emoji, (value) => value + 1, ifAbsent: () => 1);
    _moments[index] = current.copyWith(reactions: reactions);
    notifyListeners();
  }

  @override
  void deleteMoments(Set<String> momentIds) {
    if (momentIds.isEmpty) return;
    _moments.removeWhere((moment) => moment.isOwn && momentIds.contains(moment.id));
    notifyListeners();
  }

  @override
  Future<void> sendMessage({
    required String receiverUserId,
    required String message,
  }) async {
    // UI boundary only. Backend messaging will replace this implementation.
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }
}

class _DemoFriend {
  final String userId;
  final String name;
  final String avatarAsset;
  final bool isMutualFriend;

  const _DemoFriend({
    required this.userId,
    required this.name,
    required this.avatarAsset,
    required this.isMutualFriend,
  });
}
