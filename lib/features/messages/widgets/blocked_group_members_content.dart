import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../profile/data/user_block_repository.dart';
import '../../profile/widgets/profile_ui_widgets.dart';

class BlockedGroupMembersContent extends StatefulWidget {
  const BlockedGroupMembersContent({
    super.key,
    required this.members,
    required this.repository,
  });
  final List<BlockedUser> members;
  final UserBlockRepository repository;
  @override
  State<BlockedGroupMembersContent> createState() =>
      _BlockedGroupMembersContentState();
}

class _BlockedGroupMembersContentState
    extends State<BlockedGroupMembersContent> {
  late final List<BlockedUser> members = List.of(widget.members);
  final Set<String> busy = {};
  String? error;
  Future<void> _unblock(BlockedUser user) async {
    if (!busy.add(user.id)) return;
    setState(() => error = null);
    try {
      await widget.repository.setBlocked(user.id, false);
      if (!mounted) return;
      setState(() => members.removeWhere((u) => u.id == user.id));
      if (members.isEmpty) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      busy.remove(user.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        members.length == 1
            ? 'Bạn đã chặn thành viên ${members.single.name}'
            : 'Bạn đã chặn các thành viên',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryText,
        ),
      ),
      const SizedBox(height: 12),
      ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .4,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final user in members)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    TextButton(
                      onPressed: busy.contains(user.id)
                          ? null
                          : () => _unblock(user),
                      child: Text(
                        busy.contains(user.id) ? 'Đang lưu…' : 'Bỏ chặn',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            error!,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      const SizedBox(height: 12),
      GoMateProfileGradientButton(
        label: 'Đóng',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}
