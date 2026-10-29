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

  factory MomentFriendPreview.fromJson(Map<String, dynamic> json) {
    return MomentFriendPreview(
      userId: json['userId'].toString(),
      name: (json['name'] as String?) ?? 'Bạn bè',
      avatarAsset: (json['avatarUrl'] as String?) ?? '',
      isSelf: json['self'] == true,
      isMutualFriend: json['mutualFriend'] != false,
      isMuted: json['muted'] == true,
      hasAvailableMoment: json['hasAvailableMoment'] == true,
      latestMomentAt: _date(json['latestMomentAt']),
    );
  }
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

  factory MomentReaction.fromJson(Map<String, dynamic> json) {
    return MomentReaction(
      userId: json['userId'].toString(),
      userName: (json['userName'] as String?) ?? 'Người dùng',
      avatarAsset: (json['avatarUrl'] as String?) ?? '',
      emoji: _emoji(json['type'] as String?),
      reactedAt: _date(json['reactedAt']) ?? DateTime.now(),
    );
  }
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

  factory MomentItem.fromJson(Map<String, dynamic> json) {
    return MomentItem(
      id: json['momentId'].toString(),
      ownerId: json['ownerId'].toString(),
      ownerName: (json['ownerName'] as String?) ?? 'Người dùng',
      ownerAvatarAsset: (json['ownerAvatarUrl'] as String?) ?? '',
      imageAsset: (json['mediaUrl'] as String?) ?? '',
      createdAt: _date(json['createdAt']) ?? DateTime.now(),
      locationText: json['locationText'] as String?,
      isOwn: json['own'] == true,
      isViewedByCurrentUser: json['viewedByCurrentUser'] == true,
      reactions: [
        for (final item in (json['reactions'] as List? ?? const []))
          if (item is Map)
            MomentReaction.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

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

DateTime? _date(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

GoMateEmojiType _emoji(String? type) {
  switch ((type ?? '').toUpperCase()) {
    case 'HAHA':
      return GoMateEmojiType.laugh;
    case 'WOW':
      return GoMateEmojiType.wow;
    case 'FIRE':
      return GoMateEmojiType.fire;
    case 'CLAP':
      return GoMateEmojiType.clap;
    case 'LOVE':
      return GoMateEmojiType.loveEyes;
    case 'SAD':
      return GoMateEmojiType.sad;
    case 'ANGRY':
      return GoMateEmojiType.angry;
    case 'HEART':
    default:
      return GoMateEmojiType.heart;
  }
}

String momentEmojiCode(GoMateEmojiType emoji) {
  switch (emoji) {
    case GoMateEmojiType.heart:
      return 'HEART';
    case GoMateEmojiType.laugh:
      return 'HAHA';
    case GoMateEmojiType.wow:
      return 'WOW';
    case GoMateEmojiType.fire:
      return 'FIRE';
    case GoMateEmojiType.clap:
      return 'CLAP';
    case GoMateEmojiType.loveEyes:
      return 'LOVE';
    case GoMateEmojiType.sad:
      return 'SAD';
    case GoMateEmojiType.angry:
      return 'ANGRY';
  }
}
