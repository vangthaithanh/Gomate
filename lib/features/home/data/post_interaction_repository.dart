import '../models/post_interaction_models.dart';

/// Contract duy nhất giữa UI tương tác bài viết và backend.
///
/// Hiện tại Home dùng [DemoPostInteractionRepository] để hoàn thiện UI/UX.
/// Khi backend Social hoàn thiện, chỉ cần triển khai repository thật theo
/// interface này; Comment/Share widget không phải viết lại.
abstract class PostInteractionRepository {
  Future<List<PostComment>> getComments(String postId);

  Future<PostComment> createComment({
    required String postId,
    required String body,
    String? parentId,
    List<String> mediaAssets = const <String>[],
  });

  Future<void> deleteComment(String commentId);

  Future<PostComment> toggleCommentLike(PostComment comment);

  Future<List<ShareContact>> getShareContacts();

  Future<List<ShareContact>> searchShareContacts(String query);

  Future<void> sharePost({
    required String postId,
    required Set<String> recipientIds,
    String? message,
  });
}

class DemoPostInteractionRepository implements PostInteractionRepository {
  final Map<String, List<PostComment>> _commentsByPost =
  <String, List<PostComment>>{};

  final List<ShareContact> _contacts = const <ShareContact>[
    ShareContact(
      id: 'u-1',
      name: 'Thune',
      subtitle: 'Thành phố Hồ Chí Minh',
      avatarAsset: 'assets/images/home/moment_thune.jpg',
    ),
    ShareContact(
      id: 'u-2',
      name: 'ChiThanh',
      subtitle: 'Đà Nẵng',
      avatarAsset: 'assets/images/home/moment_chithanh.jpg',
    ),
    ShareContact(
      id: 'u-3',
      name: 'Buji',
      subtitle: 'Quảng Bình',
      avatarAsset: 'assets/images/home/moment_buji.jpg',
    ),
    ShareContact(
      id: 'u-4',
      name: 'DaDaDa',
      subtitle: 'Thanh Thuý',
      avatarAsset: 'assets/images/home/user_1.jpg',
    ),
    ShareContact(
      id: 'u-5',
      name: 'DaDaDa',
      subtitle: 'Thanh Thuý',
      avatarAsset: 'assets/images/home/user_2.jpg',
    ),
    ShareContact(
      id: 'u-6',
      name: 'DaDaDa',
      subtitle: 'Thanh Thuý',
      avatarAsset: 'assets/images/home/user_3.jpg',
    ),
    ShareContact(
      id: 'u-7',
      name: 'Bum',
      subtitle: 'Bạn bè',
      avatarAsset: 'assets/images/home/moment_4.jpg',
    ),
  ];

  List<PostComment> _seed(String postId) {
    return <PostComment>[
      PostComment(
        id: '$postId-c1',
        postId: postId,
        userId: 'u-thune',
        userName: 'Thune',
        avatarAsset: 'assets/images/home/moment_thune.jpg',
        body: 'Chỗ này đẹp quá',
        timeText: '3 ngày',
        likeCount: 0,
        isMine: true,
      ),
      PostComment(
        id: '$postId-r1',
        postId: postId,
        userId: 'u-chithanh',
        userName: 'ChiThanh',
        avatarAsset: 'assets/images/home/moment_chithanh.jpg',
        body: '@Thune Chỗ này đẹp quá',
        timeText: '3 ngày',
        likeCount: 2,
        isLiked: true,
        parentId: '$postId-c1',
      ),
      PostComment(
        id: '$postId-c2',
        postId: postId,
        userId: 'u-buji',
        userName: 'Buji',
        avatarAsset: 'assets/images/home/moment_buji.jpg',
        body: 'Chỗ này đẹp quá',
        timeText: '3 ngày',
        mediaAssets: <String>[
          'assets/images/home/post_2_1.jpg',
          'assets/images/home/post_2_2.jpg',
        ],
      ),
    ];
  }

  List<PostComment> _forPost(String postId) {
    return _commentsByPost.putIfAbsent(
      postId,
          () => _seed(postId),
    );
  }

  @override
  Future<List<PostComment>> getComments(String postId) async {
    return List<PostComment>.unmodifiable(_forPost(postId));
  }

  @override
  Future<PostComment> createComment({
    required String postId,
    required String body,
    String? parentId,
    List<String> mediaAssets = const <String>[],
  }) async {
    final list = _forPost(postId);

    final comment = PostComment(
      id: '$postId-local-${DateTime.now().microsecondsSinceEpoch}',
      postId: postId,
      userId: 'me',
      userName: 'Bạn',
      avatarAsset: 'assets/images/home/moment_me.jpg',
      body: body.trim(),
      timeText: 'Vừa xong',
      isMine: true,
      parentId: parentId,
      mediaAssets: mediaAssets,
    );

    list.add(comment);
    return comment;
  }

  @override
  Future<void> deleteComment(String commentId) async {
    for (final list in _commentsByPost.values) {
      final idsToRemove = list
          .where(
            (comment) =>
        comment.id == commentId || comment.parentId == commentId,
      )
          .map((comment) => comment.id)
          .toSet();

      list.removeWhere((comment) => idsToRemove.contains(comment.id));
    }
  }

  @override
  Future<PostComment> toggleCommentLike(PostComment comment) async {
    final nextLiked = !comment.isLiked;

    final next = comment.copyWith(
      isLiked: nextLiked,
      likeCount: (comment.likeCount + (nextLiked ? 1 : -1))
          .clamp(0, 1 << 30)
          .toInt(),
    );

    final list = _forPost(comment.postId);
    final index = list.indexWhere((item) => item.id == comment.id);

    if (index >= 0) {
      list[index] = next;
    }

    return next;
  }

  @override
  Future<List<ShareContact>> getShareContacts() async {
    return List<ShareContact>.unmodifiable(_contacts);
  }

  @override
  Future<List<ShareContact>> searchShareContacts(String query) async {
    final normalized = query.trim().toLowerCase();

    if (normalized.isEmpty) {
      return getShareContacts();
    }

    return _contacts
        .where(
          (contact) =>
      contact.name.toLowerCase().contains(normalized) ||
          contact.subtitle.toLowerCase().contains(normalized),
    )
        .toList(growable: false);
  }

  @override
  Future<void> sharePost({
    required String postId,
    required Set<String> recipientIds,
    String? message,
  }) async {
    // UI demo only.
    // Repository thật sẽ POST share/message theo backend contract sau này.
  }
}
