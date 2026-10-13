/// The presentation contract for GoMate notifications.
/// TODO(BACKEND-NOTIFICATIONS): map real API/WebSocket/push events into this
/// model; do not keep the demo data provider when production is connected.
enum GoMateNotificationType {
  followRequest,
  followAccepted,
  startedFollowing,
  postLiked,
  postCommented,
  postMentioned,
  recommendedPlace,
  momentReaction,
  tripInvitation,
  tripInvitationAccepted,
  newMessage,
  memberArrived,
  upcomingPlace,
}

enum GoMateNotificationPeriod { lastWeek, lastMonth, older }

enum GoMateNotificationAction { none, acceptFollow, followBack, message, acceptTrip, pendingFollow, pendingTrip, openLocation, openRoute }

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
  final String? momentId;
  final String? placeId;
  final String? tripId;
  final String? invitationId;
  final String? conversationId;
  final String? memberId;
  final double? memberLatitude;
  final double? memberLongitude;
  final DateTime? occurredAt;
  final int? upcomingLeadMinutes;
  final String? tripName;
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
    this.postId, this.momentId, this.placeId, this.tripId,
    this.invitationId, this.conversationId, this.memberId,
    this.memberLatitude, this.memberLongitude, this.occurredAt,
    this.upcomingLeadMinutes,
    this.tripName,
    this.tripDay = 1,
    this.actorPrivate = false,
    this.isRead = false,
  });

  GoMateNotificationItem copyWith({bool? isRead}) => GoMateNotificationItem(
    id: id, type: type, actorName: actorName, actorId: actorId,
    message: message, timeText: timeText, period: period,
    thumbnail: thumbnail, avatar: avatar, targetId: targetId,
    postId: postId, momentId: momentId, placeId: placeId,
    tripId: tripId, invitationId: invitationId,
    conversationId: conversationId, memberId: memberId,
    memberLatitude: memberLatitude, memberLongitude: memberLongitude,
    occurredAt: occurredAt, upcomingLeadMinutes: upcomingLeadMinutes,
    tripName: tripName, tripDay: tripDay, actorPrivate: actorPrivate,
    isRead: isRead ?? this.isRead,
  );
}
