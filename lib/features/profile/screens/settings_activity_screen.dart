import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../moments/data/moments_repository.dart';
import '../../moments/screens/my_moments_screen.dart';
import '../widgets/settings_shared_widgets.dart';
import 'settings_collection_screen.dart';
import 'settings_account_lists_screen.dart';
import 'settings_history_screen.dart';

/// Single entry point for everything under "Hoạt động của bạn".
class SettingsActivityScreen extends StatelessWidget {
  const SettingsActivityScreen({super.key});
  void _go(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  @override
  Widget build(BuildContext context) => SettingsPageShell(
    title: 'Hoạt động của bạn',
    description:
        'Xem và quản lý lượt tương tác, nội dung cũng như hoạt động của bạn.',
    body: ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        const SettingsSectionLabel('Lượt tương tác'),
        SettingsMenuRow(
          icon: LucideIcons.heart,
          title: 'Lượt thích',
          onTap: () => _go(
            context,
            const SettingsCollectionScreen(kind: SettingsCollectionKind.likes),
          ),
        ),
        SettingsMenuRow(
          icon: LucideIcons.message_circle,
          title: 'Bình luận',
          onTap: () => _go(
            context,
            const SettingsCollectionScreen(
              kind: SettingsCollectionKind.comments,
            ),
          ),
        ),
        SettingsMenuRow(
          icon: LucideIcons.star,
          title: 'Đánh giá',
          onTap: () => _go(
            context,
            const SettingsCollectionScreen(
              kind: SettingsCollectionKind.reviews,
            ),
          ),
        ),
        SettingsMenuRow(
          icon: LucideIcons.bookmark,
          title: 'Đã lưu',
          onTap: () => _go(
            context,
            const SettingsCollectionScreen(kind: SettingsCollectionKind.saved),
          ),
        ),
        SettingsMenuRow(
          icon: LucideIcons.images,
          title: 'Thư viện khoảnh khắc',
          onTap: () => _go(
            context,
            MyMomentsScreen(repository: ApiMomentsRepository.instance),
          ),
        ),
        const Divider(
          thickness: 4,
          height: 24,
          color: AppColors.grayBackground,
        ),
        const SettingsSectionLabel('Nội dung'),
        SettingsMenuRow(
          icon: LucideIcons.ban,
          title: 'Đã chặn',
          onTap: () => _go(
            context,
            const SettingsPeopleListScreen(
              kind: SettingsPeopleListKind.blocked,
            ),
          ),
        ),
        SettingsMenuRow(
          icon: LucideIcons.message_square_warning,
          title: 'Đã báo cáo',
          onTap: () => _go(
            context,
            const SettingsPeopleListScreen(
              kind: SettingsPeopleListKind.reports,
            ),
          ),
        ),
        SettingsMenuRow(
          icon: LucideIcons.eye_off,
          title: 'Khoảnh khắc đã ẩn',
          onTap: () => _go(
            context,
            const SettingsPeopleListScreen(
              kind: SettingsPeopleListKind.hiddenMoments,
            ),
          ),
        ),
        const Divider(
          thickness: 4,
          height: 24,
          color: AppColors.grayBackground,
        ),
        const SettingsSectionLabel('Hoạt động'),
        SettingsMenuRow(
          icon: LucideIcons.timer,
          title: 'Quản lý thời gian',
          onTap: () => _go(
            context,
            const SettingsHistoryScreen(kind: SettingsHistoryKind.time),
          ),
        ),
        SettingsMenuRow(
          icon: LucideIcons.timer_reset,
          title: 'Lịch sử xem',
          onTap: () => _go(
            context,
            const SettingsHistoryScreen(kind: SettingsHistoryKind.visits),
          ),
        ),
        SettingsMenuRow(
          icon: LucideIcons.search,
          title: 'Tìm kiếm gần đây',
          onTap: () => _go(
            context,
            const SettingsHistoryScreen(kind: SettingsHistoryKind.searches),
          ),
        ),
        const SizedBox(height: 28),
      ],
    ),
  );
}
