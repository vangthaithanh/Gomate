import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../models/search_models.dart';
import 'search_widgets.dart';

class PlaceFilterContent extends StatelessWidget {
  final Set<SearchPlaceFilter> selected;

  const PlaceFilterContent({
    super.key,
    this.selected = const <SearchPlaceFilter>{},
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Bộ lọc địa điểm',
          style: TextStyle(
            fontSize: searchFont(width, 16),
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
        SizedBox(height: width * 0.045),
        for (final filter in SearchPlaceFilter.values)
          _FilterOptionRow(
            label: filter.label,
            selected: selected.contains(filter),
            onTap: () => Navigator.of(context).pop(filter),
          ),
      ],
    );
  }
}

class HashtagFilterContent extends StatefulWidget {
  final Future<List<SearchHashtagItem>> Function(String query) onSearch;
  final Set<String> selected;

  const HashtagFilterContent({
    super.key,
    required this.onSearch,
    this.selected = const <String>{},
  });

  @override
  State<HashtagFilterContent> createState() => _HashtagFilterContentState();
}

class _HashtagFilterContentState extends State<HashtagFilterContent> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<SearchHashtagItem> _items = const <SearchHashtagItem>[];
  bool _loading = true;
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  Future<void> _load(String query) async {
    final token = ++_requestToken;

    setState(() {
      _loading = true;
    });

    final items = await widget.onSearch(query);

    if (!mounted || token != _requestToken) return;

    setState(() {
      _items = items;
      _loading = false;
    });
  }

  void _cancelQuery() {
    _controller.clear();
    _focusNode.requestFocus();
    _load('');
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final height = (screen.height * 0.56).clamp(360.0, 470.0);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Column(
        children: [
          SearchQueryBar(
            controller: _controller,
            focusNode: _focusNode,
            showCancel: true,
            hintText: 'Tìm hashtag',
            onChanged: _load,
            onSubmitted: _load,
            onCancel: _cancelQuery,
          ),
          SizedBox(height: screen.width * 0.035),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : _items.isEmpty
                    ? const SearchEmptyState(
                        text: 'Không có hashtag phù hợp',
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];

                          return _HashtagRow(
                            item: item,
                            selected: widget.selected.contains(item.tag),
                            onTap: () {
                              Navigator.of(context).pop(item.tag);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterOptionRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final rowHeight = (width * 0.145).clamp(52.0, 58.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: rowHeight,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: searchFont(width, 12.5),
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.primaryText
                        : AppColors.black,
                  ),
                ),
              ),
              Icon(
                selected
                    ? LucideIcons.circle_check
                    : LucideIcons.chevron_right,
                size: (width * 0.058).clamp(20.0, 23.0),
                color: selected
                    ? AppColors.primaryIcon
                    : AppColors.grayText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HashtagRow extends StatelessWidget {
  final SearchHashtagItem item;
  final bool selected;
  final VoidCallback onTap;

  const _HashtagRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: width * 0.026,
          horizontal: width * 0.010,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.tag,
                style: TextStyle(
                  fontSize: searchFont(width, 12),
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.primaryText
                      : AppColors.black,
                ),
              ),
            ),
            Text(
              '${item.postCount} bài viết',
              style: TextStyle(
                fontSize: searchFont(width, 10),
                fontWeight: FontWeight.w400,
                color: AppColors.grayText,
              ),
            ),
            SizedBox(width: width * 0.020),
            Icon(
              selected
                  ? LucideIcons.circle_check
                  : LucideIcons.chevron_right,
              size: (width * 0.050).clamp(18.0, 21.0),
              color: selected
                  ? AppColors.primaryIcon
                  : AppColors.grayText,
            ),
          ],
        ),
      ),
    );
  }
}
