class PostComment {
  final int replyCount;
  final String? replyToUserId;
  final String? replyToUserName;
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
    this.replyCount = 0,
    this.replyToUserId,
    this.replyToUserName,
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

  factory PostComment.fromApi(Map<String, dynamic> r) => PostComment(
    id: r['commentId'].toString(),
    postId: r['postId'].toString(),
    userId: r['userId'].toString(),
    userName: r['userName'] as String? ?? '',
    avatarAsset: r['avatarUrl'] as String? ?? '',
    body: r['body'] as String? ?? '',
    timeText:
        DateTime.tryParse(
          r['createdAt']?.toString() ?? '',
        )?.toLocal().toString().substring(0, 16) ??
        '',
    likeCount: (r['likeCount'] as num?)?.toInt() ?? 0,
    isLiked: r['likedByMe'] == true,
    isMine: r['isMine'] == true,
    parentId: r['parentCommentId']?.toString(),
    replyToUserId: r['replyToUserId']?.toString(),
    replyToUserName: r['replyToUserName'] as String?,
    replyCount: (r['replyCount'] as num?)?.toInt() ?? 0,
    mediaAssets: ((r['media'] as List?) ?? [])
        .map((m) => m['url'] as String)
        .toList(),
  );
  bool get isReply => parentId != null;

  PostComment copyWith({int? likeCount, int? replyCount, bool? isLiked}) {
    return PostComment(
      id: id,
      replyCount: replyCount ?? this.replyCount,
      replyToUserId: replyToUserId,
      replyToUserName: replyToUserName,
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

enum ShareTargetType { user, group }

/// Target dùng chung cho Share Post.
///
/// Backend sau này chỉ cần map `id + type` sang userId / conversationId thật.
/// UI không cần tách thành hai flow khác nhau.
class ShareContact {
  final String id;
  final String name;
  final String subtitle;
  final String avatarAsset;

  /// Nullable có chủ đích để tương thích an toàn với object cũ còn nằm trong
  /// memory sau Hot Reload khi field `type` mới được bổ sung.
  ///
  /// Backend / object mới vẫn truyền enum bình thường. Nếu object cũ trả null
  /// thì UI mặc định coi target đó là user thay vì crash đỏ.
  final ShareTargetType? type;

  /// Dùng khi group chưa có ảnh bìa: render avatar chồng như message group.
  final List<String> memberAvatarAssets;

  const ShareContact({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.avatarAsset,
    this.type = ShareTargetType.user,
    this.memberAvatarAssets = const <String>[],
  });

  ShareTargetType get resolvedType => type ?? ShareTargetType.user;

  bool get isGroup => resolvedType == ShareTargetType.group;
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
