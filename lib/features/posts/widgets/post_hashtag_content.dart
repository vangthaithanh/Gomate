import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gomate_search_field.dart';
import '../../search/data/search_repository.dart';
import '../../search/models/search_models.dart';

/// Search candidates are currently UI-preview data supplied by SearchRepository.
/// TODO(BACKEND-CREATE-POST): replace hashtag lookup with server search/creation.
class GoMatePostHashtagContent extends StatefulWidget {
  const GoMatePostHashtagContent({super.key});
  @override
  State<GoMatePostHashtagContent> createState() => _GoMatePostHashtagContentState();
}

class _GoMatePostHashtagContentState extends State<GoMatePostHashtagContent> {
  final _controller = TextEditingController();
  final _repository = SearchRepository();
  List<SearchHashtagItem> _suggestions = const [];
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _request++;
    _controller.dispose();
    super.dispose();
  }

  String _normalize(String raw) {
    final clean = raw.trim().replaceAll(RegExp(r'^#+'), '')
        .replaceAll(RegExp(r'\s+'), '');
    return clean.isEmpty ? '' : '#$clean';
  }

  Future<void> _search(String query) async {
    final request = ++_request;
    final list = await _repository.searchHashtags(query.trim().replaceAll('#', ''));
    if (!mounted || request != _request) return;
    setState(() => _suggestions = list);
  }

  void _finish([String? selected]) {
    final tag = _normalize(selected ?? _controller.text);
    if (tag.isEmpty) return;
    Navigator.of(context).pop(tag);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: (MediaQuery.sizeOf(context).height * .49).clamp(230.0, 440.0),
      child: Column(children: [
        Row(children: [
          Expanded(child: GoMateSearchField(
            controller: _controller, autofocus: true,
            hintText: 'Nhập hashtag', onChanged: _search,
          )),
          const SizedBox(width: 12),
          TextButton(onPressed: _finish, child: const Text('Hoàn tất',
            style: TextStyle(color: AppColors.primaryText, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        Expanded(child: ListView.separated(
          itemCount: _suggestions.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F1F1)),
          itemBuilder: (_, index) {
            final tag = _suggestions[index];
            return InkWell(
              onTap: () => _finish(tag.tag),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
                child: Row(children: [
                  Expanded(child: Text(_normalize(tag.tag),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  Text('${tag.postCount} bài viết',
                    style: const TextStyle(color: AppColors.grayText, fontSize: 11)),
                  const SizedBox(width: 5),
                  const Icon(LucideIcons.chevron_right, size: 16, color: AppColors.grayText),
                ])),
            );
          },
        )),
      ]),
    );
  }
}
