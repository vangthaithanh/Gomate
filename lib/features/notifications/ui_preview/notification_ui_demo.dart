import 'package:flutter/foundation.dart';

import '../models/gomate_notification.dart';

/// UI demo only. All IDs here are non-backend identifiers.
/// TODO(BACKEND-NOTIFICATIONS): delete this entire provider after wiring the
/// real notification/follow-request/invitation data source to NotificationScreen.
class NotificationUiDemo extends ChangeNotifier {
  NotificationUiDemo._();
  static final NotificationUiDemo instance = NotificationUiDemo._();
  static const bool enabled = true;

  bool privateAccount = true;
  String? spotlightNotificationId;
  final Set<String> readIds = {};
  final Set<String> acceptedFollowIds = {};
  final Set<String> requestedFollowIds = {};
  final Set<String> mutualFollowIds = {};
  final Set<String> acceptedTripIds = {};

  void setPrivate(bool value) {
    if (privateAccount == value) return;
    privateAccount = value;
    notifyListeners();
  }

  void markRead(String id) {
    if (readIds.add(id)) notifyListeners();
  }

  void acceptFollow(String id) {
    acceptedFollowIds.add(id);
    spotlightNotificationId = null;
    notifyListeners();
  }

  void followBack(String id, {required bool otherPrivate}) {
    if (otherPrivate) {
      requestedFollowIds.add(id);
    } else {
      mutualFollowIds.add(id);
    }
    notifyListeners();
  }

  void acceptTrip(String id) {
    // TODO(BACKEND-NOTIFICATIONS): server must confirm by invitationId first.
    acceptedTripIds.add(id);
    if (spotlightNotificationId == id) spotlightNotificationId = null;
    notifyListeners();
  }

  void spotlight(String id) {
    spotlightNotificationId = id;
    notifyListeners();
  }

  bool get hasPendingFollow =>
      privateAccount &&
      followRequests.any((item) => !acceptedFollowIds.contains(item.id));

  static const followRequests = <GoMateNotificationItem>[
    GoMateNotificationItem(
      id: 'demo-follow-1',
      type: GoMateNotificationType.followRequest,
      actorId: 'ui-preview-notification-dadada-1',
      actorName: 'DaDaDa',
      message: 'đã yêu cầu theo dõi bạn',
      timeText: '3 ngày',
      period: GoMateNotificationPeriod.lastWeek,
      actorPrivate: false,
    ),
    GoMateNotificationItem(
      id: 'demo-follow-2',
      type: GoMateNotificationType.followRequest,
      actorId: 'ui-preview-notification-dadada-2',
      actorName: 'Thanh Thuý',
      message: 'đã yêu cầu theo dõi bạn',
      timeText: '3 ngày',
      period: GoMateNotificationPeriod.lastWeek,
      actorPrivate: true,
    ),
    GoMateNotificationItem(
      id: 'demo-follow-3',
      type: GoMateNotificationType.followRequest,
      actorId: 'ui-preview-notification-dadada-3',
      actorName: 'ChiThanh',
      message: 'đã yêu cầu theo dõi bạn',
      timeText: '4 ngày',
      period: GoMateNotificationPeriod.lastWeek,
      actorPrivate: false,
    ),
    GoMateNotificationItem(
      id: 'demo-follow-4',
      type: GoMateNotificationType.followRequest,
      actorId: 'ui-preview-notification-dadada-4',
      actorName: 'Buji',
      message: 'đã yêu cầu theo dõi bạn',
      timeText: '5 ngày',
      period: GoMateNotificationPeriod.lastWeek,
      actorPrivate: true,
    ),
  ];

  static const items = <GoMateNotificationItem>[
    GoMateNotificationItem(
      id: 'demo-follow-accepted',
      type: GoMateNotificationType.followAccepted,
      actorName: 'Thune',
      actorId: 'ui-preview-notification-thune',
      message: 'đã chấp nhận yêu cầu theo dõi của bạn',
      timeText: '3 ngày',
      period: GoMateNotificationPeriod.lastWeek,
    ),
    GoMateNotificationItem(
      id: 'demo-moment',
      type: GoMateNotificationType.momentReaction,
      actorName: 'CThanh',
      actorId: 'ui-preview-notification-cthanh',
      message: 'đã bày tỏ cảm xúc với khoảnh khắc của bạn',
      timeText: '3 ngày',
      period: GoMateNotificationPeriod.lastWeek,
      thumbnail: 'assets/images/ketban.jpg',
    ),
    GoMateNotificationItem(
      id: 'demo-post-like',
      type: GoMateNotificationType.postLiked,
      actorName: 'CThanh',
      actorId: 'ui-preview-notification-cthanh',
      message: 'đã thích bài viết của bạn',
      timeText: '3 ngày',
      period: GoMateNotificationPeriod.lastWeek,
      thumbnail: 'assets/images/thiennhien.jpg',
    ),
    GoMateNotificationItem(
      id: 'demo-post-comment',
      type: GoMateNotificationType.postCommented,
      actorName: 'CThanh',
      actorId: 'ui-preview-notification-cthanh',
      message: 'đã bình luận bài viết của bạn: thích quá nhỉ',
      timeText: '3 ngày',
      period: GoMateNotificationPeriod.lastWeek,
      thumbnail: 'assets/images/thiennhien.jpg',
    ),
    GoMateNotificationItem(
      id: 'demo-post-mention',
      type: GoMateNotificationType.postMentioned,
      actorName: 'CThanh',
      actorId: 'ui-preview-notification-cthanh',
      message: 'đã nhắc đến bạn trong một bình luận: thích quá…',
      timeText: '3 ngày',
      period: GoMateNotificationPeriod.lastWeek,
      thumbnail: 'assets/images/thiennhien.jpg',
    ),
    GoMateNotificationItem(
      id: 'demo-recommendation',
      type: GoMateNotificationType.recommendedPlace,
      actorName: '',
      actorId: '',
      message: 'Khám phá địa điểm phù hợp với bạn: Đà Nẵng, Bà Nà',
      timeText: '3 ngày',
      period: GoMateNotificationPeriod.lastWeek,
      thumbnail: 'assets/images/checkin.jpg',
    ),
    GoMateNotificationItem(
      id: 'demo-follow-accepted-older',
      type: GoMateNotificationType.followAccepted,
      actorName: 'DaDaDa',
      actorId: 'ui-preview-notification-older',
      message: 'đã chấp nhận yêu cầu theo dõi của bạn',
      timeText: '10 ngày',
      period: GoMateNotificationPeriod.lastMonth,
      actorPrivate: true,
    ),
    GoMateNotificationItem(
      id: 'demo-trip-invite',
      type: GoMateNotificationType.tripInvitation,
      actorName: 'Thune',
      actorId: 'ui-preview-notification-thune',
      message: 'đã mời bạn tham gia lịch trình Đà Nẵng',
      timeText: '3 ngày',
      period: GoMateNotificationPeriod.lastMonth,
      tripName: 'Đà Nẵng',
      thumbnail: 'assets/images/survey_beach.jpg',
    ),
    GoMateNotificationItem(
      id: 'demo-trip-accepted',
      type: GoMateNotificationType.tripInvitationAccepted,
      actorName: 'CThanh',
      actorId: 'ui-preview-notification-cthanh',
      message: 'đã chấp nhận tham gia lịch trình Đà Lạt ơi',
      timeText: '3 ngày',
      period: GoMateNotificationPeriod.lastMonth,
      tripName: 'Đà Lạt ơi',
      thumbnail: 'assets/images/nghiduong.jpg',
    ),
    GoMateNotificationItem(
      id: 'demo-message',
      type: GoMateNotificationType.newMessage,
      actorName: 'Thune',
      actorId: 'ui-preview-notification-thune',
      message: 'đã gửi tin nhắn mới',
      timeText: '3 ngày',
      period: GoMateNotificationPeriod.lastMonth,
    ),
    GoMateNotificationItem(
      id: 'demo-member-arrived',
      type: GoMateNotificationType.memberArrived,
      actorName: 'Thune',
      actorId: 'ui-preview-notification-thune',
      message: 'đã đến địa điểm quán cà phê vào lúc 12:30',
      timeText: '3 ngày',
      period: GoMateNotificationPeriod.lastMonth,
      tripName: 'Đà Nẵng',
      tripDay: 1,
    ),
    GoMateNotificationItem(
      id: 'demo-upcoming-60',
      type: GoMateNotificationType.upcomingPlace,
      upcomingLeadMinutes: 60,
      actorName: '',
      actorId: '',
      message: 'Còn 1 giờ đến địa điểm Chùa vàng, Tây Ninh',
      timeText: '1 giờ trước',
      period: GoMateNotificationPeriod.older,
      thumbnail: 'assets/images/lichsu.jpg',
      tripName: 'Đà Nẵng',
      tripDay: 1,
    ),
    GoMateNotificationItem(
      id: 'demo-upcoming',
      type: GoMateNotificationType.upcomingPlace,
      upcomingLeadMinutes: 30,
      actorName: '',
      actorId: '',
      message: 'Chuẩn bị đến địa điểm Chùa vàng, Tây Ninh',
      timeText: '1 phút trước',
      period: GoMateNotificationPeriod.older,
      thumbnail: 'assets/images/lichsu.jpg',
      tripName: 'Đà Nẵng',
      tripDay: 1,
    ),
  ];

  List<GoMateNotificationItem> get feed {
    final rows = <GoMateNotificationItem>[
      for (final item in items)
        if (privateAccount ||
            item.type != GoMateNotificationType.followAccepted ||
            item.id != 'demo-follow-accepted-older')
          item,
      if (!privateAccount)
        const GoMateNotificationItem(
          id: 'demo-follow-public',
          type: GoMateNotificationType.startedFollowing,
          actorName: 'Thune',
          actorId: 'ui-preview-notification-new-follower',
          message: 'đã bắt đầu theo dõi bạn',
          timeText: '3 ngày',
          period: GoMateNotificationPeriod.lastWeek,
          actorPrivate: true,
        ),
      if (!privateAccount)
        const GoMateNotificationItem(
          id: 'demo-follow-public-2',
          type: GoMateNotificationType.startedFollowing,
          actorName: 'Buji',
          actorId: 'ui-preview-notification-new-follower2',
          message: 'đã bắt đầu theo dõi bạn',
          timeText: '3 ngày',
          period: GoMateNotificationPeriod.lastWeek,
          actorPrivate: false,
        ),
    ];
    if (spotlightNotificationId != null) {
      rows.sort((a, b) {
        if (a.id == spotlightNotificationId) return -1;
        if (b.id == spotlightNotificationId) return 1;
        return 0;
      });
    }
    return rows
        .map((row) => row.copyWith(isRead: readIds.contains(row.id)))
        .toList(growable: false);
  }

  List<GoMateNotificationItem> get previewCandidates => [
    if (privateAccount) followRequests.first,
    ...feed,
  ];
}
