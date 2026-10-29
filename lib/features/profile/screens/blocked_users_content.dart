import 'package:flutter/material.dart';
import '../../../core/services/content_access_changes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/snackbar.dart';
import '../data/user_block_repository.dart';
import '../widgets/settings_shared_widgets.dart';
import 'public_profile_screen.dart';

/// Existing Settings blocked-users form, backed solely by the authenticated API.
class BlockedUsersContent extends StatefulWidget {
  const BlockedUsersContent({super.key, this.repository});
  final UserBlockRepository? repository;
  @override
  State<BlockedUsersContent> createState() => _BlockedUsersContentState();
}

class _BlockedUsersContentState extends State<BlockedUsersContent> {
  late final UserBlockRepository repo;
  final List<BlockedUser> items = [];
  final Set<String> busy = {};
  bool loading = false, more = true;
  int page = 0, revision = 0;
  String? error;
  int? _session;
  void _authChanged() {
    if (_session != repo.auth.sessionGeneration) {
      _session = repo.auth.sessionGeneration;
      _reload();
    }
  }

  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? UserBlockRepository.instance;
    _session = repo.auth.sessionGeneration;
    ContentAccessChanges.revision.addListener(_reload);
    repo.auth.addListener(_authChanged);
    _load(reset: true);
  }

  @override
  void dispose() {
    revision++;
    ContentAccessChanges.revision.removeListener(_reload);
    repo.auth.removeListener(_authChanged);
    super.dispose();
  }

  void _reload() {
    if (mounted) _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (!mounted || !reset && loading) return;
    final current = ++revision,
        owner = repo.auth.user?['id'],
        session = repo.auth.sessionGeneration;
    setState(() {
      loading = true;
      error = null;
      if (reset) {
        items.clear();
        page = 0;
        more = true;
      }
    });
    try {
      final result = await repo.page(page: page);
      if (!mounted ||
          current != revision ||
          owner != repo.auth.user?['id'] ||
          session != repo.auth.sessionGeneration)
        return;
      final rows = (result['items'] as List).map(
        (r) => BlockedUser.fromJson(r as Map),
      );
      setState(() {
        items.addAll(rows);
        page++;
        more = items.length < (result['total'] as num).toInt();
      });
    } catch (e) {
      if (mounted && current == revision) setState(() => error = e.toString());
    } finally {
      if (mounted && current == revision) setState(() => loading = false);
    }
  }

  Future<void> _unblock(BlockedUser user) async {
    if (!busy.add(user.id)) return;
    setState(() {});
    try {
      await repo.setBlocked(user.id, false);
      if (mounted) {
        setState(() => items.removeWhere((u) => u.id == user.id));
        GoMateSnackBar.show(context, message: 'Đã bỏ chặn ${user.name}');
      }
    } catch (e) {
      if (mounted) GoMateSnackBar.show(context, message: e.toString());
    } finally {
      busy.remove(user.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => SettingsPageShell(
    title: 'Người dùng đã chặn',
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        children: [
          if (items.isEmpty && !loading && error == null)
            const SizedBox(
              height: 220,
              child: SettingsEmpty('Chưa chặn người dùng nào'),
            ),
          for (final user in items)
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PublicProfileScreen(userId: user.id),
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 66),
                child: Row(
                  children: [
                    SettingsVisualAvatar(url: user.avatarUrl, size: 38),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '@${user.nickname}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.grayText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: busy.contains(user.id)
                          ? null
                          : () => _unblock(user),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 44),
                      ),
                      child: Text(
                        busy.contains(user.id) ? 'Đang lưu…' : 'Bỏ chặn',
                        style: const TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error != null)
            Column(
              children: [
                Text(
                  error!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grayText,
                  ),
                ),
                TextButton(
                  onPressed: () => _load(reset: true),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          if (more && !loading && error == null && items.isNotEmpty)
            TextButton(onPressed: _load, child: const Text('Xem thêm')),
        ],
      ),
    ),
  );
}
