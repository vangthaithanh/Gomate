import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../profile/widgets/settings_shared_widgets.dart';
import '../../home/widgets/report_reason_content.dart';
import '../data/post_repository.dart';
import '../widgets/post_session_gate.dart';

class PostReportsScreen extends StatefulWidget {
  final PostRepository? repository;
  const PostReportsScreen({super.key, this.repository});
  @override
  State<PostReportsScreen> createState() => _PostReportsScreenState();
}

class _PostReportsScreenState extends State<PostReportsScreen> {
  late final _repo = widget.repository ?? PostRepository();
  late final _actor = _repo.auth.user?['id'];
  final _items = <Map<String, dynamic>>[];
  String? _cursor, _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _repo.auth.addListener(_session);
    _load();
  }

  void _session() {
    if (mounted && _actor != _repo.auth.user?['id'])
      setState(() {
        _items.clear();
        _error = 'Tài khoản đã thay đổi';
        _cursor = null;
      });
  }

  @override
  void dispose() {
    _repo.auth.removeListener(_session);
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (_busy || _actor != _repo.auth.user?['id']) return;
    setState(() => _busy = true);
    try {
      final page = await _repo.reports(cursor: more ? _cursor : null);
      if (!mounted || _actor != _repo.auth.user?['id']) return;
      setState(() {
        if (!more) _items.clear();
        _items.addAll(
          (page['items'] as List).map(
            (r) => Map<String, dynamic>.from(r as Map),
          ),
        );
        _cursor = page['nextCursor'] as String?;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _label(Map<String, dynamic> item) =>
      ReportReason.values
          .where((r) => r.code == item['reasonCode'])
          .firstOrNull
          ?.label ??
      item['reasonCode'].toString();
  @override
  Widget build(BuildContext context) => SettingsPageShell(
    title: 'Nội dung đã báo cáo',
    body: _items.isEmpty
        ? (_busy
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: TextButton(
                    onPressed: _load,
                    child: Text('$_error\nThử lại'),
                  ),
                )
              : const SettingsEmpty('Chưa có nội dung đã báo cáo'))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
              itemCount: _items.length + 1,
              itemBuilder: (context, i) {
                if (i == _items.length)
                  return _cursor == null
                      ? const SizedBox.shrink()
                      : TextButton(
                          onPressed: _busy ? null : () => _load(more: true),
                          child: const Text('Xem thêm'),
                        );
                final item = _items[i];
                return InkWell(
                  onTap: () => GoMateBottomSheet.show<void>(
                    context: context,
                    child: PostSessionGate(
                      auth: _repo.auth,
                      actor: _actor?.toString(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _label(item),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Đang chờ xử lý',
                            style: TextStyle(color: AppColors.primaryText),
                          ),
                          if ((item['details'] as String? ?? '').isNotEmpty)
                            Text(item['details'] as String),
                          Text(
                            DateTime.tryParse(
                                  item['createdAt'].toString(),
                                )?.toLocal().toString() ??
                                '',
                            style: const TextStyle(
                              color: AppColors.grayText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _label(item),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Icon(
                          LucideIcons.message_square_warning,
                          color: AppColors.grayText,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
  );
}
