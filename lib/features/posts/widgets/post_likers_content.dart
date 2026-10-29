import '../../../core/services/content_access_changes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../profile/screens/public_profile_screen.dart';
import '../../profile/widgets/profile_ui_widgets.dart';
import '../data/post_repository.dart';

Future<void> showPostLikers(
  BuildContext context, {
  required int postId,
  required PostRepository repository,
}) async {
  final actor = repository.auth.user?['id'];
  final user = await GoMateBottomSheet.show<String>(
    context: context,
    size: GoMateBottomSheetSize.expanded,
    child: PostLikersContent(postId: postId, repository: repository),
  );
  if (!context.mounted || user == null || actor != repository.auth.user?['id'])
    return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => PublicProfileScreen(userId: user)),
  );
}

class PostLikersContent extends StatefulWidget {
  final int postId;
  final PostRepository repository;
  const PostLikersContent({
    super.key,
    required this.postId,
    required this.repository,
  });
  @override
  State<PostLikersContent> createState() => _PostLikersContentState();
}

class _PostLikersContentState extends State<PostLikersContent>
    with WidgetsBindingObserver {
  final _items = <Map<String, dynamic>>[];
  late final _actor = widget.repository.auth.user?['id'];
  String? _cursor, _error;
  int _revision = 0;
  bool _busy = false;
  bool _denied = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.repository.auth.addListener(_session);
    ContentAccessChanges.revision.addListener(_accessChanged);
    unawaited(_load());
  }

  void _accessChanged() {
    if (mounted) unawaited(_load());
  }

  void _session() {
    if (_actor == widget.repository.auth.user?['id'] || !mounted) return;
    _revision++;
    setState(() {
      _items.clear();
      _cursor = null;
      _busy = false;
      _denied = true;
      _error = 'Tài khoản đã thay đổi';
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_denied) unawaited(_load());
  }

  @override
  void dispose() {
    _revision++;
    WidgetsBinding.instance.removeObserver(this);
    widget.repository.auth.removeListener(_session);
    ContentAccessChanges.revision.removeListener(_accessChanged);
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (_denied ||
        _actor != widget.repository.auth.user?['id'] ||
        (more && (_busy || _cursor == null)))
      return;
    final revision = ++_revision;
    setState(() {
      _busy = true;
      _error = null;
      if (!more) {
        _items.clear();
        _cursor = null;
      }
    });
    try {
      final page = await widget.repository.likers(
        widget.postId,
        cursor: more ? _cursor : null,
      );
      if (!mounted ||
          revision != _revision ||
          _actor != widget.repository.auth.user?['id'])
        return;
      setState(() {
        _items.addAll(
          (page['items'] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .where((r) => !_items.any((old) => old['userId'] == r['userId'])),
        );
        _cursor = page['nextCursor'] as String?;
      });
    } catch (failure) {
      if (!mounted || revision != _revision) return;
      setState(() {
        final denied =
            failure is ApiException &&
            (failure.status == 403 || failure.status == 404);
        if (denied) {
          _items.clear();
          _cursor = null;
          _denied = true;
        }
        _error = denied
            ? 'Bài viết không còn khả dụng'
            : 'Không tải được người thích. Vui lòng thử lại.';
      });
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        'Người đã thích',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryText,
        ),
      ),
      const SizedBox(height: 16),
      for (final user in _items)
        ListTile(
          key: ValueKey('post-liker-${user['userId']}'),
          contentPadding: EdgeInsets.zero,
          leading: GoMateProfileAvatar(
            imageUrl: user['avatarUrl'] as String?,
            size: 42,
          ),
          title: Text(
            (user['displayName'] ?? user['nickname'] ?? 'Người dùng')
                .toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: user['nickname'] == null
              ? null
              : Text(
                  '@${user['nickname']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.grayText,
                  ),
                ),
          trailing: const Icon(
            LucideIcons.chevron_right,
            size: 18,
            color: AppColors.grayText,
          ),
          onTap: () => Navigator.of(context).pop(user['userId'] as String),
        ),
      if (_busy)
        const Padding(
          padding: EdgeInsets.all(18),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryIcon,
          ),
        ),
      if (_error != null) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.grayText),
          ),
        ),
        if (!_denied)
          TextButton(
            onPressed: () => _load(more: _items.isNotEmpty),
            child: const Text('Thử lại'),
          ),
      ] else if (!_busy && _items.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Chưa có lượt thích',
            style: TextStyle(color: AppColors.grayText),
          ),
        )
      else if (!_busy && _cursor != null)
        TextButton(
          onPressed: () => _load(more: true),
          child: const Text('Xem thêm'),
        ),
    ],
  );
}
