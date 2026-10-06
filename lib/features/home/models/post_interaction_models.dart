class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String avatarAsset;
  final String body;
  final String timeText;
  final int likeCount;
  final bool isLiked;
  final bool isMine;
  final String? parentId;
  final List<String> mediaAssets;

  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.avatarAsset,
    required this.body,
    required this.timeText,
    this.likeCount = 0,
    this.isLiked = false,
    this.isMine = false,
    this.parentId,
    this.mediaAssets = const <String>[],
  });

  bool get isReply => parentId != null;

  PostComment copyWith({
    int? likeCount,
    bool? isLiked,
  }) {
    return PostComment(
      id: id,
      postId: postId,
      userId: userId,
      userName: userName,
      avatarAsset: avatarAsset,
      body: body,
      timeText: timeText,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      isMine: isMine,
      parentId: parentId,
      mediaAssets: mediaAssets,
    );
  }
}

class ShareContact {
  final String id;
  final String name;
  final String subtitle;
  final String avatarAsset;

  const ShareContact({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.avatarAsset,
  });
}

class PostLocationTarget {
  final String label;
  final String? placeId;
  final double? latitude;
  final double? longitude;

  const PostLocationTarget({
    required this.label,
    this.placeId,
    this.latitude,
    this.longitude,
  });

  bool get hasPlace => placeId != null && placeId!.trim().isNotEmpty;

  bool get hasCoordinate => latitude != null && longitude != null;
}
