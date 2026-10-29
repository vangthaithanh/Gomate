import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../../map/screens/place_detail_screen.dart';
import '../../map/state/map_ui_session.dart';
import '../../search/screens/search_screen.dart';
import '../../trip/screens/trip_detail_screen.dart';
import '../ui_preview/profile_ui_preview.dart';
import '../ui_preview/settings_ui_demo.dart';
import '../widgets/settings_shared_widgets.dart';
import 'public_profile_screen.dart';
import 'profile_post_feed_screen.dart';

enum SettingsHistoryKind { time, visits, searches }

/// Two options only. The 30-day retention rule is independent of filtering.
enum _VisitRange {
  yesterday('Ngày hôm qua'),
  lastWeek('1 tuần qua'),
  last30Days('30 ngày qua');

  const _VisitRange(this.label);
  final String label;
}

class SettingsHistoryScreen extends StatefulWidget {
  final SettingsHistoryKind kind;
  const SettingsHistoryScreen({super.key, required this.kind});
  @override
  State<SettingsHistoryScreen> createState() => _SettingsHistoryScreenState();
}

class _SettingsHistoryScreenState extends State<SettingsHistoryScreen> {
  final demo = SettingsUiDemo.instance;
  bool postsTab = false;
  _VisitRange _range = _VisitRange.last30Days;

  @override
  void initState() {
    super.initState();
    demo.addListener(_refresh);
  }

  @override
  void dispose() {
    demo.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  // TODO(BACKEND-SETTINGS-UI): server should purge/expire entries after 30 days.
  bool _recent(DateTime date) =>
      !date.isBefore(DateTime.now().subtract(const Duration(days: 30)));

  bool _dateMatches(DateTime date) {
    final today = _dayStart(DateTime.now());
    final day = _dayStart(date);

    switch (_range) {
      case _VisitRange.yesterday:
        return day == today.subtract(const Duration(days: 1));

      case _VisitRange.lastWeek:
        return !day.isBefore(today.subtract(const Duration(days: 6))) &&
            !day.isAfter(today);

      case _VisitRange.last30Days:
        return !day.isBefore(today.subtract(const Duration(days: 29))) &&
            !day.isAfter(today);
    }
  }

  Future<void> _pickRange() async {
    final next = await GoMateBottomSheet.show<_VisitRange>(
      context: context,
      size: GoMateBottomSheetSize.compact,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Lọc lịch sử xem',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          for (final option in _VisitRange.values)
            ListTile(
              title: Text(option.label),
              trailing: Icon(
                _range == option
                    ? LucideIcons.circle_check
                    : LucideIcons.circle,
                color: _range == option
                    ? AppColors.primaryIcon
                    : AppColors.grayText,
              ),
              onTap: () => Navigator.of(context).pop(option),
            ),
        ],
      ),
    );
    if (!mounted || next == null) return;
    setState(() => _range = next);
  }

  void _openVisited(SettingsDemoVisit item) {
    if (item.isPlace) {
      final places = ProfileUiPreview.favoritePlaces.where(
        (p) => p.id == item.targetId,
      );
      if (places.isNotEmpty)
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PlaceDetailScreen(place: places.first),
          ),
        );
    } else {
      final posts = demo.visitedPosts.where((p) => p.id == item.targetId);
      if (posts.isNotEmpty)
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GoMateProfilePostFeedScreen(posts: [posts.first]),
          ),
        );
    }
  }

  void _openSearchResult(SettingsDemoSearch item) {
    // TODO(BACKEND-SETTINGS-UI): use trusted targetId for typed history events;
    // current mock routes NEVER pass preview IDs to server APIs.
    switch (item.type) {
      case 'Người dùng':
        final person = ProfileUiPreview.findPerson(item.targetId);
        if (person == null) {
          GoMateSnackBar.show(context, message: 'Hồ sơ xem thử không khả dụng');
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                PublicProfileScreen(userId: person.id, previewPerson: person),
          ),
        );
        return;
      case 'Địa điểm':
        final places = ProfileUiPreview.favoritePlaces.where(
          (p) => p.id == item.targetId,
        );
        if (places.isEmpty) {
          GoMateSnackBar.show(context, message: 'Không tìm thấy địa điểm');
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PlaceDetailScreen(place: places.first),
          ),
        );
        return;
      case 'Lịch trình':
        final trips = GoMateMapUiSession.availableTrips.where(
          (trip) => trip.id == item.targetId || trip.title == item.text,
        );
        if (trips.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TripDetailScreen(trip: trips.first),
            ),
          );
        } else {
          // Preview ONLY when no real trip is available. Never send a fake
          // trip ID into TripDetailScreen's repository-backed editing actions.
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _PreviewTripDetailScreen(title: item.text),
            ),
          );
        }
        return;
      default:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                SearchScreen(initialQuery: item.text, startSubmitted: true),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.kind) {
      SettingsHistoryKind.time => 'Quản lý thời gian',
      SettingsHistoryKind.visits => 'Lịch sử xem',
      SettingsHistoryKind.searches => 'Tìm kiếm gần đây',
    };
    return SettingsPageShell(
      title: title,
      trailing: widget.kind == SettingsHistoryKind.visits
          ? IconButton(
              onPressed: _pickRange,
              icon: const Icon(
                LucideIcons.sliders_horizontal,
                size: 22,
                color: AppColors.black,
              ),
            )
          : null,
      body: switch (widget.kind) {
        SettingsHistoryKind.time => _timeChart(),
        SettingsHistoryKind.visits => _viewHistory(),
        SettingsHistoryKind.searches => _searchHistory(),
      },
    );
  }

  Widget _timeChart() {
    // TODO(BACKEND-SETTINGS-UI): mock minutes until device usage integration.
    const values = SettingsUiDemo.enabled
        ? [12, 24, 68, 31, 41, 84, 55]
        : [0, 0, 0, 0, 0, 0, 0];
    const days = ['T4', 'T5', 'T6', 'T7', 'CN', 'T2', 'Hôm nay'];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      children: [
        const Text(
          SettingsUiDemo.enabled ? '42 phút' : '--',
          style: TextStyle(
            fontSize: 39,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        const Text(
          'Trung bình hàng ngày',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Thống kê thời gian sử dụng GoMate trong 7 ngày qua. '
          'Chỉ để xem; chưa có dữ liệu thiết bị thật.',
          style: TextStyle(
            color: AppColors.grayText,
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 35),
        SizedBox(
          height: 245,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(
              values.length,
              (i) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: values[i] / 100,
                            widthFactor: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      // Equal 37px label boxes keep the bars aligned even when
                      // 'Hôm nay' wraps to two lines.
                      SizedBox(
                        height: 37,
                        child: Center(
                          child: Text(
                            days[i],
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.1,
                              fontWeight: i == 6
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: AppColors.grayText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const SettingsSectionLabel('Tổng quan'),
        const SettingsMenuRow(
          title: 'Thời gian trung bình',
          icon: LucideIcons.clock,
          value: SettingsUiDemo.enabled ? '42 phút' : '--',
          showArrow: false,
        ),
        const SettingsMenuRow(
          title: 'Thời gian cao nhất',
          icon: LucideIcons.trending_up,
          value: SettingsUiDemo.enabled ? '84 phút' : '--',
          showArrow: false,
        ),
        const SizedBox(height: 30),
        const Text(
          'Bản demo không ghi nhận hoạt động nền hoặc '
          'quyền sử dụng thiết bị.',
          style: TextStyle(fontSize: 12, color: AppColors.grayText),
        ),
      ],
    );
  }

  Widget _viewHistory() {
    final rows = demo.visits
        .where(
          (item) =>
              _recent(item.date) &&
              _dateMatches(item.date) &&
              item.isPlace != postsTab,
        )
        .toList();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _tab(
                'Địa điểm',
                !postsTab,
                () => setState(() => postsTab = false),
              ),
            ),
            Expanded(
              child: _tab(
                'Bài viết',
                postsTab,
                () => setState(() => postsTab = true),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(right: 22),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              _range.label,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Expanded(
          child: rows.isEmpty
              ? const SettingsEmpty(
                  'Không có lịch sử xem trong khoảng thời gian này',
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                  itemCount: rows.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: .83,
                  ),
                  itemBuilder: (context, index) {
                    final item = rows[index];
                    final p = ProfileUiPreview.favoritePlaces.where(
                      (x) => x.id == item.targetId,
                    );
                    final post = demo.visitedPosts.where(
                      (x) => x.id == item.targetId,
                    );
                    final title = item.isPlace
                        ? (p.isEmpty ? 'Địa điểm' : p.first.name)
                        : (post.isEmpty ? 'Bài viết' : post.first.caption);
                    final image = item.isPlace
                        ? (p.isEmpty ? '' : p.first.imageAsset ?? '')
                        : (post.isEmpty || post.first.media.isEmpty
                              ? ''
                              : post.first.media.first);
                    return InkWell(
                      onTap: () => _openVisited(item),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            SettingsMediaImage(image),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0x99000000),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 9,
                              left: 8,
                              right: 8,
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _tab(String title, bool active, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: SizedBox(
      height: 47,
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: active ? AppColors.black : AppColors.grayText,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    ),
  );

  Widget _searchHistory() {
    final items = demo.searches.where((x) => _recent(x.date)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 5),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Trong 30 ngày gần đây',
                  style: TextStyle(color: AppColors.grayText, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () {
                  demo.clearSearch();
                  GoMateSnackBar.show(context, message: 'Đã xoá lịch sử demo');
                },
                child: const Text(
                  'Xoá tất cả',
                  style: TextStyle(color: AppColors.primaryText),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const SettingsEmpty('Chưa có lượt tìm kiếm nào')
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final icon = switch (item.type) {
                      'Người dùng' => LucideIcons.user_round,
                      'Địa điểm' => LucideIcons.map_pin,
                      'Lịch trình' => LucideIcons.calendar_days,
                      _ => LucideIcons.search,
                    };
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _openSearchResult(item),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 65,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 29,
                                      child: Icon(
                                        icon,
                                        color: AppColors.black,
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: 11),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            item.text,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: AppColors.black,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            item.type,
                                            style: const TextStyle(
                                              color: AppColors.grayText,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 43,
                            height: 43,
                            child: IconButton(
                              onPressed: () => demo.removeSearch(item),
                              icon: const Icon(
                                LucideIcons.x,
                                color: AppColors.grayText,
                                size: 19,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// This is a UI-only fallback for search history sample trips when the user
/// does not have a matching real itinerary. Do not send fake IDs to Trip APIs.
/// TODO(BACKEND-SETTINGS-UI): remove when history entries carry real trip IDs.
class _PreviewTripDetailScreen extends StatelessWidget {
  final String title;
  const _PreviewTripDetailScreen({required this.title});
  @override
  Widget build(BuildContext context) => SettingsPageShell(
    title: 'Chi tiết lịch trình',
    body: ListView(
      children: [
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const SettingsSectionLabel(
          'Dữ liệu xem thử · Chưa kết nối lịch trình thật',
        ),
        const SettingsMenuRow(
          title: 'Điểm đến',
          value: 'Đà Lạt',
          icon: LucideIcons.map_pin,
          showArrow: false,
        ),
        const SettingsMenuRow(
          title: 'Số ngày',
          value: '3 ngày',
          icon: LucideIcons.calendar_days,
          showArrow: false,
        ),
        const SettingsMenuRow(
          title: 'Trạng thái',
          value: 'Chưa ghim',
          icon: LucideIcons.clock,
          showArrow: false,
        ),
      ],
    ),
  );
}
