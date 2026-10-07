import '../../../core/widgets/gomate_emoji.dart';

class MomentFriendPreview {
  final String userId;
  final String name;
  final String avatarAsset;
  final bool isSelf;
  final bool isMutualFriend;
  final bool isMuted;
  final bool hasAvailableMoment;
  final DateTime? latestMomentAt;

  const MomentFriendPreview({
    required this.userId,
    required this.name,
    required this.avatarAsset,
    required this.isSelf,
    required this.isMutualFriend,
    required this.isMuted,
    required this.hasAvailableMoment,
    required this.latestMomentAt,
  });
}

class MomentReaction {
  final String userId;
  final String userName;
  final String avatarAsset;
  final GoMateEmojiType emoji;
  final DateTime reactedAt;

  const MomentReaction({
    required this.userId,
    required this.userName,
    required this.avatarAsset,
    required this.emoji,
    required this.reactedAt,
  });
}

class MomentItem {
  final String id;
  final String ownerId;
  final String ownerName;
  final String ownerAvatarAsset;
  final String imageAsset;
  final DateTime createdAt;
  final String? locationText;
  final bool isOwn;
  final bool isViewedByCurrentUser;
  final List<MomentReaction> reactions;

  const MomentItem({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerAvatarAsset,
    required this.imageAsset,
    required this.createdAt,
    required this.locationText,
    required this.isOwn,
    required this.isViewedByCurrentUser,
    required this.reactions,
  });

  MomentItem copyWith({
    bool? isViewedByCurrentUser,
    List<MomentReaction>? reactions,
  }) {
    return MomentItem(
      id: id,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerAvatarAsset: ownerAvatarAsset,
      imageAsset: imageAsset,
      createdAt: createdAt,
      locationText: locationText,
      isOwn: isOwn,
      isViewedByCurrentUser:
          isViewedByCurrentUser ?? this.isViewedByCurrentUser,
      reactions: reactions ?? this.reactions,
    );
  }
}
