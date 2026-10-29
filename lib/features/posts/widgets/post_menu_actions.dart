import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/network/api_exception.dart';
import 'post_session_gate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../../home/widgets/post_action_content.dart';
import '../../home/widgets/report_reason_content.dart';
import '../screens/post_reports_screen.dart';
import '../data/post_repository.dart';
import '../models/post_compose_models.dart';
import 'post_audience_content.dart';

/// One real Post menu for Home, Profile and the shared viewer.
class PostMenuActions {
  final PostRepository repository;
  bool _busy = false;
  PostMenuActions(this.repository);

  Future<void> open(
    BuildContext context,
    int id, {
    VoidCallback? onDeleted,
    VoidCallback? onUnavailable,
  }) async {
    if (_busy) return;
    _busy = true;
    final actor = repository.auth.user?['id']?.toString();
    bool valid() =>
        context.mounted &&
        actor != null &&
        actor == repository.auth.user?['id']?.toString();
    Widget guard(Widget child) =>
        PostSessionGate(auth: repository.auth, actor: actor, child: child);
    try {
      if (!context.mounted || !valid()) return;
      final current = await repository.detail(id);
      if (!context.mounted || !valid()) return;
      if (current['authorId']?.toString() != actor) {
        final result = await GoMateBottomSheet.show<PostActionResult>(
          context: context,
          child: guard(const PostActionContent()),
        );
        if (context.mounted && valid() && result == PostActionResult.report) {
          final key = newPostRequestId();
          final sent = await GoMateBottomSheet.show<bool>(
            context: context,
            size: GoMateBottomSheetSize.expanded,
            child: guard(
              ReportReasonContent(
                onSubmit: (reason, description) async {
                  if (!valid()) throw StateError('Tài khoản đã thay đổi');
                  await repository.report(id, key, reason.code, description);
                  if (!valid()) throw StateError('Tài khoản đã thay đổi');
                },
              ),
            ),
          );
          if (context.mounted && valid() && sent == true)
            GoMateSnackBar.show(
              context,
              message: 'Cảm ơn bạn đã đóng góp ý kiến',
              actionLabel: 'Xem báo cáo',
              onAction: () {
                if (valid())
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PostReportsScreen(repository: repository),
                    ),
                  );
              },
            );
        } else if (context.mounted && valid() && result != null) {
          GoMateSnackBar.show(context, message: 'Chức năng này chưa khả dụng.');
        }
        return;
      }
      final choice = await chooseOwnAction(
        context,
        current['pinned'] == true,
        guard: guard,
      );
      if (!context.mounted || !valid() || choice == null) return;
      if (choice == 'pin') {
        await repository.pin(id, current['pinned'] != true);
      } else if (choice == 'audience') {
        await repository.auth.loadProfile();
        if (!context.mounted || !valid()) return;
        final selected = await GoMateBottomSheet.show<GoMatePostAudience>(
          context: context,
          child: guard(
            GoMatePostAudienceContent(
              initial: switch (current['audience']) {
                'FRIENDS' => GoMatePostAudience.friends,
                'ONLY_ME' => GoMatePostAudience.onlyMe,
                'FOLLOWERS' => GoMatePostAudience.followers,
                _ => GoMatePostAudience.everyone,
              },
              isPrivate: repository.auth.user?['isPrivate'] == true,
            ),
          ),
        );
        if (!context.mounted || !valid() || selected == null) return;
        await repository.audience(id, switch (selected) {
          GoMatePostAudience.everyone => 'EVERYONE',
          GoMatePostAudience.followers => 'FOLLOWERS',
          GoMatePostAudience.friends => 'FRIENDS',
          GoMatePostAudience.onlyMe => 'ONLY_ME',
        });
      } else if (choice == 'delete') {
        final confirmed = await confirmDelete(context, true, guard: guard);
        if (!context.mounted || !valid() || confirmed != true) return;
        await repository.delete(id);
        if (context.mounted && valid()) onDeleted?.call();
      }
      if (context.mounted && valid()) {
        GoMateSnackBar.show(
          context,
          message: switch (choice) {
            'pin' =>
              current['pinned'] == true
                  ? 'Đã bỏ ghim bài viết'
                  : 'Đã ghim bài viết',
            'audience' => 'Đã đổi quyền riêng tư',
            _ => 'Đã xoá bài viết',
          },
        );
      }
    } catch (error) {
      if (context.mounted && valid()) {
        if (error is ApiException &&
            (error.status == 401 ||
                error.status == 403 ||
                error.status == 404)) {
          onUnavailable?.call();
        }
        GoMateSnackBar.show(
          context,
          message: 'Không cập nhật được bài viết: $error',
        );
      }
    } finally {
      _busy = false;
    }
  }

  static Widget _unguarded(Widget child) => child;
  static Future<String?> chooseOwnAction(
    BuildContext context,
    bool pinned, {
    Widget Function(Widget)? guard,
  }) async {
    return await GoMateBottomSheet.show<String>(
      context: context,
      child: (guard ?? _unguarded)(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ownAction(
              context,
              pinned ? LucideIcons.pin_off : LucideIcons.pin,
              pinned ? 'Bỏ ghim bài viết' : 'Ghim bài viết',
              'pin',
            ),
            const Divider(height: 1, color: AppColors.grayBorder),
            _ownAction(
              context,
              LucideIcons.earth,
              'Chỉnh sửa quyền riêng tư',
              'audience',
            ),
            const Divider(height: 1, color: AppColors.grayBorder),
            _ownAction(
              context,
              LucideIcons.trash,
              'Xoá',
              'delete',
              danger: true,
            ),
          ],
        ),
      ),
    );
  }

  static Future<bool?> confirmDelete(
    BuildContext context,
    bool real, {
    Widget Function(Widget)? guard,
  }) async {
    return await GoMateBottomSheet.show<bool>(
      context: context,
      child: (guard ?? _unguarded)(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Xoá bài viết?',
              style: TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              real
                  ? 'Bài viết sẽ bị xoá khỏi trang cá nhân.'
                  : 'Bài viết sẽ bị xoá khỏi bản xem thử.',
              style: const TextStyle(fontSize: 13, color: AppColors.grayText),
            ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Xác nhận xoá'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Huỷ'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _ownAction(
    BuildContext context,
    IconData icon,
    String title,
    String code, {
    bool danger = false,
  }) => InkWell(
    onTap: () => Navigator.of(context).pop(code),
    child: SizedBox(
      height: 55,
      child: Row(
        children: [
          Icon(
            icon,
            size: 23,
            color: danger ? AppColors.primaryIcon : AppColors.black,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: danger ? AppColors.primaryIcon : AppColors.black,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
