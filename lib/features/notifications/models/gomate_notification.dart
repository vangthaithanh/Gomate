/// The presentation contract for GoMate notifications.
/// TODO(BACKEND-NOTIFICATIONS): map real API/WebSocket/push events into this
/// model; do not keep the demo data provider when production is connected.
enum GoMateNotificationType {
  followRequest,
  followAccepted,
  startedFollowing,
  postLiked,
  postCommented,
  postReplied,
  postMentioned,
  recommendedPlace,
  momentReaction,
  tripInvitation,
  tripInvitationAccepted,
  tripStartReminder,
  newMessage,
  memberArrived,
  upcomingPlace,
}

enum GoMateNotificationPeriod { lastWeek, lastMonth, older }

enum GoMateNotificationAction {
  none,
  acceptFollow,
  followBack,
  message,
  acceptTrip,
  pendingFollow,
  pendingTrip,
  openLocation,
  openRoute,
}

class GoMateNotificationItem {
  final String id;
  final GoMateNotificationType type;
  final String actorName;
  final String actorId;
  final String message;
  final String timeText;
  final String? thumbnail;
  final String? avatar;

  /// Stable identifiers supplied by backend once connected.
  final String? targetId;
  final String? postId;
  final String? commentId;
  final String? momentId;
  final String? placeId;
  final String? tripId;
  final String? invitationId;
  final String? invitationStatus;
  final String? conversationId;
  final String? memberId;
  final double? memberLatitude;
  final double? memberLongitude;
  final DateTime? occurredAt;
  final int? upcomingLeadMinutes;
  final String? tripName;
  final String? reminderId;
  final int? reminderDaysBefore;
  // Calendar dates in reminderTimezone; never convert with toLocal().
  final String? tripStartDate;
  final String? reminderDate;
  final String? reminderTimezone;
  // Historical T-60/T-30 notifications only.
  final int? reminderOffsetMinutes;
  final DateTime? plannedStartAt;
  final int tripDay;
  final bool actorPrivate;
  final bool isRead;
  final GoMateNotificationPeriod period;

  const GoMateNotificationItem({
    required this.id,
    required this.type,
    required this.actorName,
    required this.actorId,
    required this.message,
    required this.timeText,
    required this.period,
    this.thumbnail,
    this.avatar,
    this.targetId,
    this.postId,
    this.commentId,
    this.momentId,
    this.placeId,
    this.tripId,
    this.invitationId,
    this.invitationStatus,
    this.conversationId,
    this.memberId,
    this.memberLatitude,
    this.memberLongitude,
    this.occurredAt,
    this.upcomingLeadMinutes,
    this.tripName,
    this.reminderId,
    this.reminderDaysBefore,
    this.tripStartDate,
    this.reminderDate,
    this.reminderTimezone,
    this.reminderOffsetMinutes,
    this.plannedStartAt,
    this.tripDay = 1,
    this.actorPrivate = false,
    this.isRead = false,
  });

  bool get isPendingInvitation =>
      type == GoMateNotificationType.tripInvitation &&
      invitationStatus == 'PENDING';

  bool get isPostInteraction =>
      type == GoMateNotificationType.postLiked ||
      type == GoMateNotificationType.postCommented ||
      type == GoMateNotificationType.postReplied;

  factory GoMateNotificationItem.fromJson(Map<String, dynamic> json) {
    final time = DateTime.parse(json['occurredAt'] as String).toLocal();
    final age = DateTime.now().difference(time);
    final type = switch (json['type']) {
      'POST_LIKE' => GoMateNotificationType.postLiked,
      'POST_COMMENT' => GoMateNotificationType.postCommented,
      'POST_REPLY' => GoMateNotificationType.postReplied,
      'TRIP_START_REMINDER' => GoMateNotificationType.tripStartReminder,
      'TRIP_INVITATION' => GoMateNotificationType.tripInvitation,
      'TRIP_INVITATION_ACCEPTED' =>
        GoMateNotificationType.tripInvitationAccepted,
      _ => throw const FormatException('Unsupported notification type'),
    };
    final tripName = json['tripName'] as String?;
    final message = switch (type) {
      GoMateNotificationType.postLiked => 'đã thích bài viết của bạn',
      GoMateNotificationType.postCommented =>
        'đã bình luận về bài viết của bạn',
      GoMateNotificationType.postReplied => 'đã trả lời bình luận của bạn',
      _ =>
        type == GoMateNotificationType.tripStartReminder
            ? json['message'] as String? ?? 'Nhắc lịch trình dự kiến'
            : type == GoMateNotificationType.tripInvitation
            ? json['invitationStatus'] == 'CANCELLED'
                  ? 'đã hủy lời mời tham gia lịch trình ${tripName ?? "không còn khả dụng"}'
                  : 'mời bạn tham gia lịch trình ${tripName ?? "không còn khả dụng"}'
            : 'đã chấp nhận lời mời tham gia lịch trình ${tripName ?? "không còn khả dụng"}',
    };
    return GoMateNotificationItem(
      id: json['id'] as String,
      type: type,
      actorName: type == GoMateNotificationType.tripStartReminder
          ? ''
          : json['actorName'] as String? ?? 'Người dùng',
      actorId: json['actorId'] as String? ?? '',
      postId: json['postId']?.toString(),
      commentId: json['commentId']?.toString(),
      avatar: json['avatarUrl'] as String?,
      message: message,
      timeText: age.inDays > 0
          ? '${age.inDays} ngày'
          : age.inHours > 0
          ? '${age.inHours} giờ'
          : age.inMinutes > 0
          ? '${age.inMinutes} phút'
          : 'Vừa xong',
      period: age.inDays < 7
          ? GoMateNotificationPeriod.lastWeek
          : age.inDays < 30
          ? GoMateNotificationPeriod.lastMonth
          : GoMateNotificationPeriod.older,
      occurredAt: time,
      invitationId: json['invitationId'] as String?,
      invitationStatus: json['invitationStatus'] as String?,
      tripId: json['tripId'] as String?,
      tripName: tripName,
      reminderId: json['reminderId'] as String?,
      reminderDaysBefore: json['reminderDaysBefore'] as int?,
      tripStartDate: json['tripStartDate'] as String?,
      reminderDate: json['reminderDate'] as String?,
      reminderTimezone: json['reminderTimezone'] as String?,
      reminderOffsetMinutes: json['reminderOffsetMinutes'] as int?,
      plannedStartAt: DateTime.tryParse(
        json['plannedStartAt'] as String? ?? '',
      ),
      isRead: json['isRead'] == true,
    );
  }

  GoMateNotificationItem copyWith({bool? isRead, String? invitationStatus}) =>
      GoMateNotificationItem(
        id: id,
        type: type,
        actorName: actorName,
        actorId: actorId,
        message: message,
        timeText: timeText,
        period: period,
        thumbnail: thumbnail,
        avatar: avatar,
        targetId: targetId,
        postId: postId,
        commentId: commentId,
        momentId: momentId,
        placeId: placeId,
        tripId: tripId,
        invitationId: invitationId,
        invitationStatus: invitationStatus ?? this.invitationStatus,
        conversationId: conversationId,
        memberId: memberId,
        memberLatitude: memberLatitude,
        memberLongitude: memberLongitude,
        occurredAt: occurredAt,
        upcomingLeadMinutes: upcomingLeadMinutes,
        tripName: tripName,
        reminderId: reminderId,
        reminderDaysBefore: reminderDaysBefore,
        tripStartDate: tripStartDate,
        reminderDate: reminderDate,
        reminderTimezone: reminderTimezone,
        reminderOffsetMinutes: reminderOffsetMinutes,
        plannedStartAt: plannedStartAt,
        tripDay: tripDay,
        actorPrivate: actorPrivate,
        isRead: isRead ?? this.isRead,
      );
}
