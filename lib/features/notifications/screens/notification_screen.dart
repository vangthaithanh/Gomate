import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gomate_main_tab_header.dart';
import '../../../core/widgets/snackbar.dart';
import '../../map/state/map_ui_session.dart';
import '../../messages/data/message_repository.dart';
import '../../trip/data/trip_repository.dart';
import '../../trip/models/trip_ui_models.dart';
import '../../trip/screens/trip_detail_screen.dart';
import '../data/notification_repository.dart';
import '../data/follow_request_repository.dart';
import '../../profile/screens/public_profile_screen.dart';
import '../../profile/screens/profile_post_feed_screen.dart';
import '../../posts/data/post_repository.dart';
import '../models/gomate_notification.dart';

/// Approved f11c6f7 inbox layout, backed by server invitation/event state.
class GoMateNotificationScreen extends StatefulWidget {
  final String? focusPendingInvitationId;
  final NotificationRepository? repository;
  final FollowRequestRepository? followRequests;
  final Future<TripUi> Function(String tripId)? loadTrip;
  const GoMateNotificationScreen({
    super.key,
    this.focusPendingInvitationId,
    this.repository,
    this.followRequests,
    this.loadTrip,
  });

  static _GoMateNotificationScreenState? _active;

  static Future<void> openPendingInvitation(
    BuildContext context, {
    required String notificationId,
    NotificationRepository? repository,
  }) async {
    final active = _active;
    if (active != null && active.mounted && active._route != null) {
      Navigator.of(active.context).popUntil((route) => route == active._route);
      await active._resolveFocus(notificationId);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GoMateNotificationScreen(
          focusPendingInvitationId: notificationId,
          repository: repository,
        ),
      ),
    );
  }

  @override
  State<GoMateNotificationScreen> createState() =>
      _GoMateNotificationScreenState();
}

class _GoMateNotificationScreenState extends State<GoMateNotificationScreen> {
  late final NotificationRepository _inbox;
  late final FollowRequestRepository _followRequests;
  List<FollowRequestItem> _requests = [];
  int _requestTotal = 0;
  int _requestPage = 0;
  bool _requestsLoading = false;
  bool _requestsFailed = false;
  int _requestEpoch = 0;
  String? _requestOwner;
  final ScrollController _feedController = ScrollController();
  final _busyIds = <String>{};
  String? _spotlightId;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _inbox = widget.repository ?? NotificationRepository.instance;
    _inbox.addListener(_onChanged);
    _followRequests = widget.followRequests ?? FollowRequestRepository();
    _requestOwner = _followRequests.auth.user?['id']?.toString();
    _followRequests.auth.addListener(_onAccountChanged);
    GoMateNotificationScreen._active = this;
    unawaited(_load());
    _feedController.addListener(_loadMore);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  Future<void> _load() async {
    unawaited(_loadRequests());
    await _inbox.refresh();
    if (!mounted) return;
    final id = widget.focusPendingInvitationId;
    if (id != null) await _resolveFocus(id);
  }

  void _onAccountChanged() {
    final owner = _followRequests.auth.user?['id']?.toString();
    if (owner == _requestOwner) return;
    _requestOwner = owner;
    _requestEpoch++;
    if (!mounted) return;
    setState(() {
      _requests = [];
      _requestTotal = 0;
      _busyIds.clear();
    });
    unawaited(_loadRequests());
  }

  Future<void> _loadRequests({bool more = false}) async {
    if (more && _requestsLoading) return;
    final epoch = ++_requestEpoch;
    setState(() {
      _requestsLoading = true;
      _requestsFailed = false;
    });
    try {
      final page = more ? _requestPage + 1 : 0;
      final result = await _followRequests.pending(page: page);
      if (!mounted || epoch != _requestEpoch) return;
      setState(() {
        _requests = more ? [..._requests, ...result.items] : result.items;
        _requestTotal = result.total;
        _requestPage = page;
      });
    } catch (_) {
      if (mounted && epoch == _requestEpoch) {
        setState(() => _requestsFailed = true);
      }
    } finally {
      if (mounted && epoch == _requestEpoch) {
        setState(() => _requestsLoading = false);
      }
    }
  }

  Future<void> _respondFollow(FollowRequestItem item, bool accept) async {
    if (!_busyIds.add(item.id)) return;
    final owner = _requestOwner;
    setState(() {});
    try {
      await _followRequests.respond(item.id, accept: accept);
      if (!mounted || owner != _requestOwner) return;
      await _loadRequests();
      await _followRequests.auth.loadProfile().catchError((_) {});
      if (mounted && owner == _requestOwner) {
        _notify(
          accept
              ? 'Đã chấp nhận yêu cầu theo dõi'
              : 'Đã từ chối yêu cầu theo dõi',
        );
      }
    } catch (_) {
      if (mounted && owner == _requestOwner) {
        _notify('Không xử lý được yêu cầu. Vui lòng thử lại.');
        unawaited(_loadRequests());
      }
    } finally {
      _busyIds.remove(item.id);
      if (mounted) setState(() {});
    }
  }

  void _loadMore() {
    if (_feedController.hasClients &&
        _feedController.position.extentAfter < 220) {
      unawaited(_inbox.loadMore());
    }
  }

  void _onChanged() {
    if (!mounted) return;
    final pending = _inbox.items.any(
      (item) => item.id == _spotlightId && item.isPendingInvitation,
    );
    setState(() {
      if (!pending) _spotlightId = null;
    });
  }

  @override
  void dispose() {
    if (GoMateNotificationScreen._active == this)
      GoMateNotificationScreen._active = null;
    _inbox.removeListener(_onChanged);
    _followRequests.auth.removeListener(_onAccountChanged);
    _requestEpoch++;
    _feedController.dispose();
    super.dispose();
  }

  void _notify(String message) =>
      GoMateSnackBar.show(context, message: message);

  void _focus(GoMateNotificationItem item) {
    if (!mounted || !item.isPendingInvitation) return;
    setState(() => _spotlightId = item.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _feedController.hasClients) {
        _feedController.animateTo(
          0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _resolveFocus(String id) async {
    final owner = _inbox.auth.user?['id']?.toString();
    try {
      final fresh = await _inbox.resolve(id);
      if (!mounted) return;
      if (fresh.isPostInteraction) {
        await _inbox.markRead(id);
        if (mounted && owner == _inbox.auth.user?['id']?.toString()) {
          await _openPost(fresh);
        }
      } else if (fresh.isPendingInvitation) {
        _focus(fresh);
      } else if (fresh.type == GoMateNotificationType.tripStartReminder) {
        await _inbox.markRead(id);
        if (mounted && owner == _inbox.auth.user?['id']?.toString()) {
          await _openTrip(fresh);
        }
      } else if (fresh.invitationStatus == 'ACCEPTED') {
        await _openTrip(fresh);
      } else if (fresh.invitationStatus == 'CANCELLED') {
        _notify('Lời mời đã được nhóm trưởng hủy.');
      } else {
        _notify('Lời mời không còn chờ xác nhận hoặc không còn khả dụng.');
      }
    } catch (_) {
      if (mounted) _notify('Không tải được thông báo. Vui lòng thử lại.');
    }
  }

  Future<void> _openPost(GoMateNotificationItem item) async {
    final owner = _inbox.auth.user?['id']?.toString();
    int? postId;
    bool comments = false;
    bool unavailableComment = false;
    try {
      final target = await _inbox.postTarget(item.id);
      postId = (target['postId'] as num).toInt();
      comments = target['commentId'] != null;
      unavailableComment = comments && target['commentAvailable'] != true;
    } on ApiException catch (failure) {
      if (failure.status != 404) rethrow;
      // The existing protected viewer renders its approved unavailable state.
      postId = int.tryParse(item.postId ?? '');
    }
    if (!mounted || owner != _inbox.auth.user?['id']?.toString()) return;
    if (postId == null) {
      _notify('Bài viết không còn khả dụng');
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GoMateProfilePostFeedScreen(
          posts: const [],
          remote: true,
          postId: postId,
          repository: PostRepository(auth: _inbox.auth),
          sharedReference: true,
          showCommentsOnOpen: comments,
          commentUnavailable: unavailableComment,
          unavailableBackLabel: 'Quay lại thông báo',
        ),
      ),
    );
  }

  Future<void> _openTrip(GoMateNotificationItem item) async {
    final actor =
        AuthService.instance.user?['id'] ??
        AuthService.instance.user?['userId'];
    final tripId = item.tripId;
    if (tripId == null) {
      _notify('Lịch trình không còn khả dụng.');
      return;
    }
    final trip = await (widget.loadTrip ?? RealTripRepository.instance.detail)(
      tripId,
    );
    if (!mounted ||
        actor !=
            (AuthService.instance.user?['id'] ??
                AuthService.instance.user?['userId'])) {
      return;
    }
    GoMateMapUiSession.updateTrip(trip);
    await Navigator.of(context).push<TripDetailResult>(
      MaterialPageRoute<TripDetailResult>(
        builder: (_) => TripDetailScreen(trip: trip),
      ),
    );
  }

  Future<void> _openNotification(GoMateNotificationItem item) async {
    final owner = _inbox.auth.user?['id']?.toString();
    try {
      // Fetch current server state, including responses made on another device.
      final fresh = await _inbox.resolve(item.id);
      await _inbox.markRead(item.id);
      if (!mounted || owner != _inbox.auth.user?['id']?.toString()) return;
      if (fresh.isPostInteraction) {
        await _openPost(fresh);
      } else if (fresh.isPendingInvitation) {
        _focus(fresh);
      } else if (fresh.type == GoMateNotificationType.tripStartReminder ||
          fresh.invitationStatus == 'ACCEPTED') {
        await _openTrip(fresh);
      } else if (fresh.invitationStatus == 'CANCELLED') {
        _notify('Lời mời đã được nhóm trưởng hủy.');
      } else {
        _notify('Lời mời hoặc lịch trình không còn khả dụng.');
      }
    } catch (failure) {
      if (mounted) _notify('Không mở được thông báo: $failure');
    }
  }

  Future<void> _acceptTrip(GoMateNotificationItem item) async {
    if (!_busyIds.add(item.id)) return;
    setState(() {});
    try {
      final trip = await _inbox.accept(item);
      if (!mounted) return;
      setState(() => _spotlightId = null);
      GoMateMapUiSession.updateTrip(trip);
      unawaited(RealDirectMessageRepository.instance.refresh());
      unawaited(_inbox.markRead(item.id).catchError((_) {}));
      _notify('Đã tham gia lịch trình ${trip.title}');
    } catch (failure) {
      unawaited(_inbox.refresh());
      if (mounted) _notify('Không thể chấp nhận lời mời: $failure');
    } finally {
      _busyIds.remove(item.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gap = (width * .065).clamp(22.0, 28.0).toDouble();
    final rows = _inbox.items;
    final seenGroups = <GoMateNotificationPeriod>{};
    final entries = <Widget>[];
    if (_requests.isNotEmpty) {
      entries.add(
        Padding(
          padding: EdgeInsets.fromLTRB(gap, 12, gap, 13),
          child: const Text(
            'Yêu cầu theo dõi',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      );
      for (final request in _requests) {
        final item = GoMateNotificationItem(
          id: request.id,
          type: GoMateNotificationType.followRequest,
          actorId: request.requesterId,
          actorName: request.name,
          avatar: request.avatarUrl,
          message: 'đã yêu cầu theo dõi bạn',
          timeText: 'Đang chờ xác nhận',
          period: GoMateNotificationPeriod.lastWeek,
        );
        entries.add(
          Padding(
            padding: EdgeInsets.fromLTRB(gap, 2, gap, 12),
            child: _NotificationRow(
              key: ValueKey('follow-request-${request.id}'),
              item: item,
              actionLabel: 'Chấp nhận',
              busy: _busyIds.contains(request.id),
              onAction: () => _respondFollow(request, true),
              onReject: () => _respondFollow(request, false),
              onTap: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PublicProfileScreen(userId: request.requesterId),
                  ),
                );
                if (mounted) unawaited(_loadRequests());
              },
            ),
          ),
        );
      }
    }
    if (_requestsFailed) {
      entries.add(
        TextButton(
          onPressed: _loadRequests,
          child: const Text('Không tải được yêu cầu theo dõi. Thử lại'),
        ),
      );
    }
    if (_requestsLoading) {
      entries.add(
        const Padding(
          padding: EdgeInsets.all(8),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    } else if (_requests.length < _requestTotal) {
      entries.add(
        TextButton(
          onPressed: () => _loadRequests(more: true),
          child: const Text('Xem thêm yêu cầu'),
        ),
      );
    }
    GoMateNotificationItem? pinned;
    for (final item in rows) {
      if (item.id == _spotlightId && item.isPendingInvitation) pinned = item;
    }
    if (pinned != null) {
      final invite = pinned;
      entries.add(
        Padding(
          padding: EdgeInsets.fromLTRB(gap, 12, gap, 6),
          child: Text(
            'Lời mời tham gia lịch trình',
            style: TextStyle(
              fontSize: (width * .037).clamp(13.0, 15.0).toDouble(),
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
        ),
      );
      entries.add(
        Padding(
          padding: EdgeInsets.fromLTRB(gap, 2, gap, 14),
          child: _NotificationRow(
            key: ValueKey('pending-invite-${invite.id}'),
            item: invite,
            emphasized: true,
            actionLabel: 'Chấp nhận',
            busy: _busyIds.contains(invite.id),
            onTap: () => _openNotification(invite),
            onAction: () => _acceptTrip(invite),
          ),
        ),
      );
    }
    for (final item in rows) {
      if (item.id == pinned?.id) continue;
      if (seenGroups.add(item.period)) {
        final heading = item.period == GoMateNotificationPeriod.lastWeek
            ? '7 ngày qua'
            : item.period == GoMateNotificationPeriod.lastMonth
            ? '30 ngày qua'
            : 'Cũ hơn';
        entries.add(
          Padding(
            padding: EdgeInsets.fromLTRB(gap, 12, gap, 13),
            child: Text(
              heading,
              style: TextStyle(
                fontSize: (width * .037).clamp(13.0, 15.0).toDouble(),
                fontWeight: FontWeight.w700,
                color: AppColors.black,
              ),
            ),
          ),
        );
      }
      entries.add(
        Padding(
          padding: EdgeInsets.fromLTRB(gap, 2, gap, 12),
          child: _NotificationRow(
            key: ValueKey(item.id),
            item: item,
            actionLabel: item.isPendingInvitation ? 'Chấp nhận' : null,
            busy: _busyIds.contains(item.id),
            onTap: () => _openNotification(item),
            onAction: () => _acceptTrip(item),
          ),
        ),
      );
    }
    if (_inbox.loading) {
      entries.add(
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryIcon,
            ),
          ),
        ),
      );
    } else if (_inbox.error != null) {
      entries.add(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'Không tải được thông báo.',
                style: TextStyle(color: AppColors.grayText),
              ),
              TextButton(
                onPressed: _inbox.refresh,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    } else if (rows.isEmpty &&
        _requests.isEmpty &&
        !_requestsLoading &&
        !_requestsFailed) {
      entries.add(
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text(
              'Chưa có thông báo',
              style: TextStyle(color: AppColors.grayText),
            ),
          ),
        ),
      );
    }
    if (_inbox.loadingMore)
      entries.add(
        const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            GoMateMainTabHeader(
              title: (AuthService.instance.user?['nickname'] ?? 'Thông báo')
                  .toString(),
              leadingIcon: LucideIcons.chevron_left,
              onLeadingTap: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primaryIcon,
                onRefresh: () async {
                  await _loadRequests();
                  await _inbox.refresh();
                },
                child: ListView(
                  controller: _feedController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  children: entries,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final GoMateNotificationItem item;
  final String? actionLabel;
  final VoidCallback onTap;
  final VoidCallback onAction;
  final VoidCallback? onReject;
  final bool emphasized;
  final bool useSubtitle;
  final bool busy;
  const _NotificationRow({
    super.key,
    required this.item,
    required this.onTap,
    required this.onAction,
    this.onReject,
    this.actionLabel,
    this.emphasized = false,
    this.useSubtitle = false,
    this.busy = false,
  });

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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (item.type == GoMateNotificationType.recommendedPlace ||
                  item.type == GoMateNotificationType.upcomingPlace)
                _Thumbnail(
                  item.thumbnail ?? 'assets/images/checkin.jpg',
                  thumbnailSize,
                )
              else if (item.type == GoMateNotificationType.tripStartReminder)
                SizedBox.square(
                  dimension: avatarSize,
                  child: const Icon(
                    LucideIcons.clock,
                    color: AppColors.primaryIcon,
                  ),
                )
              else
                _PersonAvatar(source: item.avatar, size: avatarSize),
              SizedBox(width: (width * .028).clamp(9.0, 12.0).toDouble()),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (useSubtitle) ...[
                      Text(
                        item.actorName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        'Thanh Thuý',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.grayText,
                        ),
                      ),
                    ] else ...[
                      Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: (width * .0335)
                                .clamp(12.0, 13.5)
                                .toDouble(),
                            color: AppColors.black,
                            height: 1.18,
                          ),
                          children: [
                            if (item.actorName.isNotEmpty)
                              TextSpan(
                                text: '${item.actorName} ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            TextSpan(text: item.message),
                          ],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '• ${item.timeText}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFFA6A6A6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onReject != null)
                IconButton(
                  tooltip: 'Từ chối',
                  onPressed: busy ? null : onReject,
                  icon: const Icon(
                    LucideIcons.x,
                    size: 18,
                    color: AppColors.grayText,
                  ),
                ),
              if (actionLabel != null) ...[
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width * .245),
                  child: InkWell(
                    onTap: busy ? null : onAction,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 10,
                      ),
                      child: busy
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryIcon,
                              ),
                            )
                          : Text(
                              actionLabel!,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontSize: (width * .026)
                                    .clamp(9.5, 11.0)
                                    .toDouble(),
                                color: AppColors.primaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ] else if (item.thumbnail != null) ...[
                const SizedBox(width: 7),
                _Thumbnail(item.thumbnail!, thumbnailSize),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  final String? source;
  final double size;
  final bool stacked;
  const _PersonAvatar({
    required this.source,
    required this.size,
    this.stacked = false,
  });
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      children: [
        Container(
          margin: EdgeInsets.only(right: stacked ? 7 : 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE7EBF3),
            border: Border.all(color: AppColors.grayBorder),
          ),
          child: source == null || source!.isEmpty
              ? Center(
                  child: Icon(
                    LucideIcons.user_round,
                    size: size * .63,
                    color: Colors.white,
                  ),
                )
              : source!.startsWith('https://') || source!.startsWith('http://')
              ? Image.network(
                  source!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      LucideIcons.user_round,
                      size: size * .63,
                      color: Colors.white,
                    ),
                  ),
                )
              : Image.asset(
                  source!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      LucideIcons.user_round,
                      size: size * .63,
                      color: Colors.white,
                    ),
                  ),
                ),
        ),
        if (stacked)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * .59,
              height: size * .59,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE7EBF3),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                LucideIcons.user_round,
                size: 15,
                color: Colors.white,
              ),
            ),
          ),
      ],
    ),
  );
}

class _Thumbnail extends StatelessWidget {
  final String image;
  final double size;
  const _Thumbnail(this.image, this.size);
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(9),
    child: Image.asset(
      image,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        color: AppColors.blue50,
        child: const Icon(LucideIcons.image, color: AppColors.primaryIcon),
      ),
    ),
  );
}

class _ModeChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });
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
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.primaryText : AppColors.grayText,
        ),
      ),
    ),
  );
}
