import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/gomate_main_tab_header.dart';
import '../../../core/widgets/gomate_notification_popup.dart';
import '../../../core/widgets/snackbar.dart';
import '../../map/screens/place_detail_screen.dart';
import '../../map/state/map_ui_session.dart';
import '../../messages/data/message_repository.dart';
import '../../messages/screens/chat_screen.dart';
import '../../messages/screens/message_screen.dart';
import '../../moments/data/moments_repository.dart';
import '../../moments/screens/my_moment_detail_screen.dart';
import '../../profile/screens/profile_post_feed_screen.dart';
import '../../profile/screens/public_profile_screen.dart';
import '../../profile/ui_preview/profile_ui_preview.dart';
import '../../profile/widgets/profile_ui_widgets.dart';
import '../../search/models/search_models.dart';
import '../../trip/models/trip_ui_models.dart';
import '../../trip/screens/trip_detail_screen.dart';
import '../models/gomate_notification.dart';
import '../ui_preview/notification_ui_demo.dart';

/// Entry point from the Home bell. UI data and actions are intentionally
/// separated from delivery; realtime events will supply GoMateNotificationItem.
class GoMateNotificationScreen extends StatefulWidget {
  /// Only set when the user taps a popup about an UNACCEPTED trip invitation.
  /// This ID is a notification ID (not a trip ID). No trip page is opened.
  final String? focusPendingInvitationId;

  const GoMateNotificationScreen({
    super.key,
    this.focusPendingInvitationId,
  });

  /// Call from the app-wide realtime/push popup when the notification screen
  /// is not already visible. The inbox owns the acceptance action; do not
  /// navigate to TripDetailScreen here.
  static Future<void> openPendingInvitation(
    BuildContext context, {
    required String notificationId,
  }) async {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => GoMateNotificationScreen(
        focusPendingInvitationId: notificationId,
      ),
    ));
  }

  @override
  State<GoMateNotificationScreen> createState() => _GoMateNotificationScreenState();
}

class _GoMateNotificationScreenState extends State<GoMateNotificationScreen> {
  final NotificationUiDemo _demo = NotificationUiDemo.instance;
  bool _showDemoTools = true;
  final ScrollController _feedController = ScrollController();

  @override
  void initState() {
    super.initState();
    _demo.addListener(_onDemoChanged);
    if (widget.focusPendingInvitationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final id = widget.focusPendingInvitationId!;
        // TODO(BACKEND-NOTIFICATIONS): resolve this ID using the real inbox
        // repository. Never synthesize an accepted invitation from the popup.
        for (final notification in _demo.feed) {
          if (notification.id == id &&
              notification.type == GoMateNotificationType.tripInvitation &&
              !_demo.acceptedTripIds.contains(id)) {
            _focusPendingInvitation(notification);
            return;
          }
        }
        _notify('Lời mời không còn chờ xác nhận hoặc đã được xử lý.');
      });
    }
  }

  void _onDemoChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _demo.removeListener(_onDemoChanged);
    _feedController.dispose();
    super.dispose();
  }

  void _notify(String message) {
    GoMateSnackBar.show(context, message: message);
  }

  void _scrollToPendingInvitation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _feedController.hasClients) {
        // The pending invitation is rendered as the FIRST list entry,
        // above follow requests and all chronological groups.
        _feedController.animateTo(0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic);
      }
    });
  }

  void _focusPendingInvitation(GoMateNotificationItem item) {
    if (!mounted || item.type != GoMateNotificationType.tripInvitation ||
        _demo.acceptedTripIds.contains(item.id)) return;
    // UI state only. Accepting the invitation is deliberately a SEPARATE tap.
    _demo.spotlight(item.id);
    _scrollToPendingInvitation();
  }

  Future<void> _openUser(GoMateNotificationItem item) async {
    if (item.actorId.isEmpty) return;
    // TODO(BACKEND-NOTIFICATIONS): remove ProfilePreviewPerson and use the
    // actual target user id from the notification when data is connected.
    final following = _demo.mutualFollowIds.contains(item.id);
    final requested = _demo.requestedFollowIds.contains(item.id);
    final alreadyFollows = _demo.acceptedFollowIds.contains(item.id);
    final relation = following
        ? SearchUserRelation.friend
        : requested
            ? SearchUserRelation.pending
            : alreadyFollows || item.type == GoMateNotificationType.startedFollowing
                ? SearchUserRelation.followsYou
                : item.type == GoMateNotificationType.followAccepted
                    ? SearchUserRelation.following
                    : SearchUserRelation.none;
    final person = ProfilePreviewPerson(
      id: item.actorId,
      nickname: item.actorName.toLowerCase().replaceAll(' ', ''),
      name: item.actorName,
      avatar: item.avatar ?? 'assets/map/member_an.png',
      bio: 'Cùng GoMate khám phá những điểm đến mới.',
      isPrivate: item.actorPrivate,
      initialRelation: relation,
      followersCount: 320,
      friendsCount: 20,
    );
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PublicProfileScreen(
        userId: person.id,
        isPrivate: person.isPrivate,
        previewPerson: person,
      ),
    ));
  }

  Future<void> _openPost(GoMateNotificationItem item) async {
    final post = GoMateProfilePostPreview(
      id: 'ui-preview-notification-post-${item.id}',
      authorId: 'ui-preview-self',
      authorName: 'Thune',
      authorAvatar: 'assets/map/member_thu.png',
      location: 'Đà Nẵng',
      caption: 'Những trải nghiệm đáng nhớ cùng GoMate. #DuLich',
      media: <String>[
        item.thumbnail ?? 'assets/images/thiennhien.jpg',
      ],
      likeCount: 24,
      commentCount: 4,
    );
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => GoMateProfilePostFeedScreen(
        posts: <GoMateProfilePostPreview>[post], initialIndex: 0),
    ));
  }

  Future<void> _openPlace() async {
    // TODO(BACKEND-NOTIFICATIONS): replace with the concrete place ID returned
    // by the recommendation engine; preview only (not a real place ID).
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const PlaceDetailScreen(
        place: MapPlaceUi(
          id: 'ui-preview-notification-place',
          name: 'Cầu Vàng, Bà Nà Hills',
          subtitle: 'Địa điểm nổi bật',
          address: 'Hòa Vang, Đà Nẵng',
          distanceText: '',
          openInfo: 'Xem thử giao diện',
          priceInfo: 'Đang cập nhật',
          rating: 4.8, reviewCount: 120, likeCount: 980,
          tags: ['Điểm tham quan', 'Đà Nẵng'],
          imageAsset: 'assets/images/checkin.jpg',
          mediaUrls: ['assets/images/checkin.jpg'],
        ),
      ),
    ));
  }

  Future<void> _openOwnMoment() async {
    final repository = DemoMomentsRepository.instance;
    final moments = repository.myMoments;
    if (moments.isEmpty) {
      _notify('Chưa có khoảnh khắc mẫu để hiển thị.');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MyMomentDetailScreen(
        repository: repository, momentId: moments.first.id),
    ));
  }

  Future<void> _openMessage() async {
    final repository = DemoMessageRepository.instance;
    final directs = repository.mainConversations.where((item) => !item.isGroup);
    if (directs.isEmpty) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => MessageScreen(repository: repository),
      ));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MessageChatScreen(
        conversationId: directs.first.id, repository: repository),
    ));
  }

  TripUi _previewTrip(GoMateNotificationItem item) => TripUi(
    id: 'ui-preview-notification-trip',
    title: item.tripName ?? 'Đà Nẵng',
    days: 2,
    destination: 'Đà Nẵng',
    coverAsset: 'assets/images/survey_beach.jpg',
    currentUserRole: TripAccessRole.member,
    isGroup: true,
    startDate: DateTime(2026, 10, 16),
    endDate: DateTime(2026, 10, 17),
    places: const <TripPlaceUi>[
      TripPlaceUi(
        id: 'ui-preview-stop-1',
        placeId: '',
        name: 'Quán cà phê',
        startTime: '12:00', endTime: '13:00',
        hasCompleteInterval: true,
        day: 1,
        imageAsset: 'assets/images/checkin.jpg',
      ),
      TripPlaceUi(
        id: 'ui-preview-stop-2',
        placeId: '',
        name: 'Chùa vàng',
        startTime: '14:00', endTime: '15:00',
        hasCompleteInterval: true,
        day: 1,
        imageAsset: 'assets/images/lichsu.jpg',
      ),
    ],
  );

  Future<void> _openTrip(GoMateNotificationItem item) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TripDetailScreen(trip: _previewTrip(item)),
    ));
  }

  void _openMapTrip(GoMateNotificationItem item) {
    // TODO(BACKEND-NOTIFICATIONS): resolve real tripId/day/member GPS before
    // navigating. The preview has no coordinates and cannot actually focus a
    // member's position. Map launch uses the existing GoMate session contract.
    final realTrip = GoMateMapUiSession.availableTrips.where(
      (trip) => item.tripId != null
        ? trip.id == item.tripId
        : trip.title == (item.tripName ?? 'Đà Nẵng'),
    );
    final target = realTrip.isNotEmpty ? realTrip.first : _previewTrip(item);
    GoMateMapUiSession.requestOpenTripOnMap(
      target, day: item.tripDay, expandDayRoute: true,
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _acceptFollow(GoMateNotificationItem item) async {
    _demo.acceptFollow(item.id);
    _notify('Đã chấp nhận yêu cầu theo dõi (demo)');
  }

  Future<void> _followBack(GoMateNotificationItem item) async {
    if (_demo.requestedFollowIds.contains(item.id)) {
      _notify('Đang chờ người này xác nhận (demo)');
      return;
    }
    _demo.followBack(item.id, otherPrivate: item.actorPrivate);
    _notify(item.actorPrivate
        ? 'Đã gửi yêu cầu theo dõi (demo)'
        : 'Đã theo dõi lại (demo)');
  }

  Future<void> _acceptTrip(GoMateNotificationItem item) async {
    // TODO(BACKEND-NOTIFICATIONS): replace with successful server-side
    // invitation acceptance by invitationId, followed by an inbox refresh.
    // Do not treat tapping a popup or opening a notification as acceptance.
    _demo.acceptTrip(item.id);
    _notify('Đã chấp nhận lời mời tham gia lịch trình (demo)');
  }

  String? _actionLabel(GoMateNotificationItem item) {
    switch (item.type) {
      case GoMateNotificationType.followRequest:
        if (!_demo.acceptedFollowIds.contains(item.id)) return 'Xác nhận';
        if (_demo.mutualFollowIds.contains(item.id)) return 'Nhắn tin';
        if (_demo.requestedFollowIds.contains(item.id)) return 'Chờ xác nhận';
        return 'Theo dõi lại';
      case GoMateNotificationType.startedFollowing:
        if (_demo.mutualFollowIds.contains(item.id)) return 'Nhắn tin';
        if (_demo.requestedFollowIds.contains(item.id)) return 'Chờ xác nhận';
        return 'Theo dõi lại';
      case GoMateNotificationType.followAccepted:
        return 'Nhắn tin';
      case GoMateNotificationType.tripInvitation:
        return _demo.acceptedTripIds.contains(item.id) ? null : 'Chấp nhận';
      case GoMateNotificationType.newMessage:
        return 'Xem tin nhắn';
      case GoMateNotificationType.memberArrived:
        return 'Xem vị trí';
      case GoMateNotificationType.upcomingPlace:
        return 'Xem lộ trình';
      default:
        return null;
    }
  }

  Future<void> _onAction(GoMateNotificationItem item) async {
    switch (item.type) {
      case GoMateNotificationType.followRequest:
        if (!_demo.acceptedFollowIds.contains(item.id)) {
          await _acceptFollow(item);
        } else if (_demo.mutualFollowIds.contains(item.id)) {
          await _openMessage();
        } else {
          await _followBack(item);
        }
        return;
      case GoMateNotificationType.startedFollowing:
        if (_demo.mutualFollowIds.contains(item.id)) {
          await _openMessage();
        } else {
          await _followBack(item);
        }
        return;
      case GoMateNotificationType.tripInvitation:
        await _acceptTrip(item);
        return;
      default:
        await _openNotification(item);
    }
  }

  Future<void> _openNotification(GoMateNotificationItem item) async {
    _demo.markRead(item.id);
    switch (item.type) {
      case GoMateNotificationType.followRequest:
      case GoMateNotificationType.followAccepted:
      case GoMateNotificationType.startedFollowing:
        await _openUser(item);
        break;
      case GoMateNotificationType.postLiked:
      case GoMateNotificationType.postCommented:
      case GoMateNotificationType.postMentioned:
        await _openPost(item);
        break;
      case GoMateNotificationType.recommendedPlace:
        await _openPlace();
        break;
      case GoMateNotificationType.momentReaction:
        await _openOwnMoment();
        break;
      case GoMateNotificationType.tripInvitation:
        if (!_demo.acceptedTripIds.contains(item.id)) {
          // Popup or inbox row: DO NOT open the itinerary or auto-accept.
          // If already inside the inbox, highlight the invitation there.
          // For app-wide popups shown on another page, call
          // GoMateNotificationScreen.openPendingInvitation(...).
          _focusPendingInvitation(item);
        } else {
          await _openTrip(item);
        }
        break;
      case GoMateNotificationType.tripInvitationAccepted:
        await _openTrip(item);
        break;
      case GoMateNotificationType.newMessage:
        await _openMessage();
        break;
      case GoMateNotificationType.memberArrived:
      case GoMateNotificationType.upcomingPlace:
        _openMapTrip(item);
        break;
    }
  }

  Future<void> _openFollowRequests() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _FollowRequestsScreen(
        demo: _demo,
        onOpen: _openUser,
        onAction: _onAction,
        actionLabel: _actionLabel,
      ),
    ));
  }

  Future<void> _chooseRealtime() async {
    final selected = await GoMateBottomSheet.show<GoMateNotificationItem>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      contentPadding: EdgeInsets.zero,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .52,
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Chọn thông báo để thử realtime',
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryText)),
            ),
            Expanded(child: ListView.builder(
              itemCount: _demo.previewCandidates.length,
              itemBuilder: (_, index) {
                final item = _demo.previewCandidates[index];
                return ListTile(
                  dense: true,
                  title: Text(item.actorName.isEmpty ? item.message : '${item.actorName} ${item.message}',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.of(context, rootNavigator: true).pop(item),
                );
              },
            )),
          ]),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    // Merely PREVIEWING the popup must not change inbox order or state.
    // Only tapping the actual popup triggers the pending-invitation route.
    GoMateNotificationPopup.show(
      context,
      avatar: selected.avatar,
      message: selected.actorName.isEmpty
        ? selected.message : '${selected.actorName} ${selected.message}',
      onTap: () {
        if (!mounted) return;
        // This demo popup is already shown on the notification page; keep the
        // current page and move the invitation to the first row for approval.
        // Outside this page, use openPendingInvitation() to navigate here.
        _openNotification(selected);
      },
    );
  }

  Widget _buildTestingControls() {
    if (!NotificationUiDemo.enabled) return const SizedBox.shrink();
    final width = MediaQuery.sizeOf(context).width;
    final gap = (width * .045).clamp(14.0, 18.0).toDouble();
    return Padding(
      padding: EdgeInsets.fromLTRB(gap, 4, gap, 9),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _showDemoTools = !_showDemoTools),
          child: Row(children: [
            const Icon(LucideIcons.bell, size: 15, color: AppColors.primaryIcon),
            const SizedBox(width: 7),
            const Expanded(child: Text('Kiểm thử giao diện thông báo',
              style: TextStyle(fontSize: 12, color: AppColors.primaryText,
                fontWeight: FontWeight.w600))),
            Icon(_showDemoTools ? LucideIcons.chevron_up : LucideIcons.chevron_down,
              color: AppColors.grayText, size: 17),
          ]),
        ),
        if (_showDemoTools) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _ModeChip(
              text: 'Private', selected: _demo.privateAccount,
              onTap: () => _demo.setPrivate(true))),
            const SizedBox(width: 8),
            Expanded(child: _ModeChip(
              text: 'Public', selected: !_demo.privateAccount,
              onTap: () => _demo.setPrivate(false))),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: InkWell(
              onTap: _chooseRealtime,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(22)),
                child: const Text('Thử popup realtime',
                  style: TextStyle(color: Colors.white, fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
              ),
            )),
          ]),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gap = (width * .065).clamp(22.0, 28.0).toDouble();
    final rows = NotificationUiDemo.enabled ? _demo.feed : <GoMateNotificationItem>[];
    final spotlightId = _demo.spotlightNotificationId;
    final seenGroups = <GoMateNotificationPeriod>{};
    final entries = <Widget>[];

    // The invite tapped from a realtime popup MUST be the first inbox row,
    // even on private accounts with follow requests and regardless of date.
    // It is excluded from normal groups below (no duplicate notification).
    GoMateNotificationItem? pinnedInvitation;
    if (spotlightId != null) {
      for (final item in rows) {
        if (item.id == spotlightId &&
            item.type == GoMateNotificationType.tripInvitation &&
            !_demo.acceptedTripIds.contains(item.id)) {
          pinnedInvitation = item;
          break;
        }
      }
    }
    if (pinnedInvitation != null) {
      final invite = pinnedInvitation;
      entries.add(Padding(
        padding: EdgeInsets.fromLTRB(gap, 12, gap, 6),
        child: Text('Lời mời tham gia lịch trình',
          style: TextStyle(
            fontSize: (width * .037).clamp(13.0, 15.0).toDouble(),
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          )),
      ));
      entries.add(Padding(
        padding: EdgeInsets.fromLTRB(gap, 2, gap, 14),
        child: _NotificationRow(
          key: ValueKey('pending-invite-${invite.id}'),
          item: invite,
          emphasized: true,
          actionLabel: 'Chấp nhận',
          onTap: () => _openNotification(invite),
          onAction: () => _acceptTrip(invite),
        ),
      ));
    }

    if (NotificationUiDemo.enabled && _demo.hasPendingFollow) {
      final pending = NotificationUiDemo.followRequests
        .where((item) => !_demo.acceptedFollowIds.contains(item.id))
        .toList(growable: false);
      final shownNames = pending.take(2).map((item) => item.actorName).join(', ');
      final pendingText = pending.length > 2
        ? '$shownNames + ${pending.length - 2} người khác'
        : shownNames;
      entries.add(Padding(
        padding: EdgeInsets.fromLTRB(gap, 9, gap, 22),
        child: InkWell(
          onTap: _openFollowRequests,
          child: Row(children: [
            const _PersonAvatar(source: null, size: 43, stacked: true),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Yêu cầu theo dõi',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(pendingText,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.grayText)),
              ],
            )),
            const Icon(LucideIcons.chevron_right, size: 20, color: AppColors.grayText),
          ]),
        ),
      ));
    }
    for (final item in rows) {
      if (item.id == pinnedInvitation?.id) continue;
      if (seenGroups.add(item.period)) {
        final heading = item.period == GoMateNotificationPeriod.lastWeek
          ? '7 ngày qua' : item.period == GoMateNotificationPeriod.lastMonth
            ? '30 ngày qua' : 'Cũ hơn';
        entries.add(Padding(
          padding: EdgeInsets.fromLTRB(gap, 12, gap, 13),
          child: Text(heading,
            style: TextStyle(fontSize: (width * .037).clamp(13.0, 15.0).toDouble(),
            fontWeight: FontWeight.w700, color: AppColors.black)),
        ));
      }
      entries.add(Padding(
        padding: EdgeInsets.fromLTRB(gap, 2, gap, 12),
        child: _NotificationRow(
          key: ValueKey(item.id), item: item,
          emphasized: item.id == spotlightId,
          actionLabel: _actionLabel(item),
          onTap: () => _openNotification(item),
          onAction: () => _onAction(item),
        ),
      ));
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          GoMateMainTabHeader(
            title: 'Thune',
            leadingIcon: LucideIcons.chevron_left,
            onLeadingTap: () => Navigator.of(context).maybePop(),
          ),
          _buildTestingControls(),
          Expanded(child: ListView(
            controller: _feedController,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 24),
            children: entries,
          )),
        ]),
      ),
    );
  }
}

class _FollowRequestsScreen extends StatelessWidget {
  final NotificationUiDemo demo;
  final ValueChanged<GoMateNotificationItem> onOpen;
  final Future<void> Function(GoMateNotificationItem) onAction;
  final String? Function(GoMateNotificationItem) actionLabel;

  const _FollowRequestsScreen({required this.demo,
    required this.onOpen, required this.onAction, required this.actionLabel});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: demo,
    builder: (context, _) => Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: Column(children: [
        GoMateMainTabHeader(
          title: 'Yêu cầu theo dõi',
          leadingIcon: LucideIcons.chevron_left,
          onLeadingTap: () => Navigator.of(context).maybePop(),
        ),
        Expanded(child: ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(23, 22, 23, 32),
          itemCount: NotificationUiDemo.followRequests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 22),
          itemBuilder: (context, index) {
            final item = NotificationUiDemo.followRequests[index];
            return _NotificationRow(
              item: item,
              useSubtitle: true,
              actionLabel: actionLabel(item),
              onTap: () => onOpen(item),
              onAction: () => onAction(item),
            );
          },
        )),
      ])),
    ),
  );
}

class _NotificationRow extends StatelessWidget {
  final GoMateNotificationItem item;
  final String? actionLabel;
  final VoidCallback onTap;
  final VoidCallback onAction;
  final bool emphasized;
  final bool useSubtitle;
  const _NotificationRow({super.key, required this.item, required this.onTap,
    required this.onAction, this.actionLabel,
    this.emphasized = false, this.useSubtitle = false});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final thumbnailSize = (width * .12).clamp(40.0, 47.0).toDouble();
    final avatarSize = (width * .093).clamp(34.0, 40.0).toDouble();
    return Material(
      color: emphasized ? const Color(0x0D0A43A8) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (item.type == GoMateNotificationType.recommendedPlace ||
                item.type == GoMateNotificationType.upcomingPlace)
              _Thumbnail(item.thumbnail ?? 'assets/images/checkin.jpg', thumbnailSize)
            else
              _PersonAvatar(source: item.avatar, size: avatarSize),
            SizedBox(width: (width * .028).clamp(9.0, 12.0).toDouble()),
            Expanded(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (useSubtitle) ...[
                  Text(item.actorName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const Text('Thanh Thuý',
                    style: TextStyle(fontSize: 11.5, color: AppColors.grayText)),
                ] else ...[
                  Text.rich(TextSpan(
                    style: TextStyle(fontSize: (width * .0335).clamp(12.0, 13.5).toDouble(),
                        color: AppColors.black, height: 1.18),
                    children: [
                      if (item.actorName.isNotEmpty) TextSpan(
                        text: '${item.actorName} ',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: item.message),
                    ],
                  ), maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('• ${item.timeText}',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFFA6A6A6))),
                ],
              ],
            )),
            if (actionLabel != null) ...[
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width * .245),
                child: InkWell(
                  onTap: onAction,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                    child: Text(actionLabel!, textAlign: TextAlign.end,
                      style: TextStyle(fontSize: (width * .026).clamp(9.5, 11.0).toDouble(),
                        color: AppColors.primaryText, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ] else if (item.thumbnail != null) ...[
              const SizedBox(width: 7),
              _Thumbnail(item.thumbnail!, thumbnailSize),
            ],
          ]),
        ),
      ),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  final String? source;
  final double size;
  final bool stacked;
  const _PersonAvatar({required this.source, required this.size, this.stacked = false});
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(children: [
      Container(
        margin: EdgeInsets.only(right: stacked ? 7 : 0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle, color: const Color(0xFFE7EBF3),
          border: Border.all(color: AppColors.grayBorder)),
        child: source == null || source!.isEmpty
          ? Center(child: Icon(LucideIcons.user_round,
              size: size * .63, color: Colors.white))
          : Image.asset(source!, width: size, height: size, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(child: Icon(
                LucideIcons.user_round, size: size * .63, color: Colors.white))),
      ),
      if (stacked) Positioned(
        right: 0, bottom: 0,
        child: Container(width: size * .59, height: size * .59,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: const Color(0xFFE7EBF3), border: Border.all(color: Colors.white, width: 2)),
          child: const Icon(LucideIcons.user_round, size: 15, color: Colors.white)),
      ),
    ]),
  );
}

class _Thumbnail extends StatelessWidget {
  final String image;
  final double size;
  const _Thumbnail(this.image, this.size);
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(9),
    child: Image.asset(image, width: size, height: size, fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: size, height: size, color: AppColors.blue50,
        child: const Icon(LucideIcons.image, color: AppColors.primaryIcon))),
  );
}

class _ModeChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({required this.text, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Container(
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: selected ? AppColors.blue100 : AppColors.grayBackground,
      ),
      child: Text(text, style: TextStyle(fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? AppColors.primaryText : AppColors.grayText)),
    ),
  );
}
