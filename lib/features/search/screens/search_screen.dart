import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../map/screens/place_detail_screen.dart';
import '../data/search_repository.dart';
import '../models/search_models.dart';
import '../widgets/search_filter_content.dart';
import '../widgets/search_widgets.dart';

class SearchScreen extends StatefulWidget {
  final SearchRepository? repository;

  /// Cho phép mở Search từ một context khác (ví dụ bấm hashtag trên post)
  /// mà không cần tạo một màn Search riêng.
  final String initialQuery;
  final SearchTab initialTab;
  final Set<String> initialHashtags;
  final bool startSubmitted;

  /// Khi Search được mở từ một nội dung cụ thể (ví dụ hashtag),
  /// nút Huỷ sẽ quay lại nội dung trước đó thay vì về Discovery.
  final bool cancelReturnsToPrevious;

  const SearchScreen({
    super.key,
    this.repository,
    this.initialQuery = '',
    this.initialTab = SearchTab.places,
    this.initialHashtags = const <String>{},
    this.startSubmitted = false,
    this.cancelReturnsToPrevious = false,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final SearchRepository _repository;

  final TextEditingController _queryController = TextEditingController();
  final FocusNode _queryFocusNode = FocusNode();

  List<SearchPlaceItem> _suggestedPlaces = const <SearchPlaceItem>[];
  List<String> _recentSearches = const <String>[];

  SearchBundle _liveBundle = const SearchBundle();
  SearchBundle _submittedBundle = const SearchBundle();

  final Set<SearchPlaceFilter> _placeFilters = <SearchPlaceFilter>{};
  final Set<String> _postHashtags = <String>{};

  SearchTab _selectedTab = SearchTab.places;

  bool _editing = false;
  bool _submitted = false;
  bool _loadingSuggestions = true;
  bool _loadingSearch = false;

  int _searchToken = 0;

  @override
  void initState() {
    super.initState();

    _repository = widget.repository ?? SearchRepository();

    _queryController.text = widget.initialQuery;
    _selectedTab = widget.initialTab;
    _postHashtags.addAll(widget.initialHashtags);

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait<dynamic>([
        _repository.getSuggestedPlaces(),
        _repository.getRecentSearches(),
      ]);

      if (!mounted) return;

      setState(() {
        _suggestedPlaces = results[0] as List<SearchPlaceItem>;
        _recentSearches = results[1] as List<String>;
        _loadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingSuggestions = false;
      });
    }

    if (!mounted) return;

    if (widget.startSubmitted && widget.initialQuery.trim().isNotEmpty) {
      await _loadInitialSubmittedSearch();
    }
  }

  Future<void> _loadInitialSubmittedSearch() async {
    final query = widget.initialQuery.trim();
    if (query.isEmpty) return;

    final token = ++_searchToken;

    setState(() {
      _editing = false;
      _submitted = true;
      _selectedTab = widget.initialTab;
      _loadingSearch = true;
    });

    final bundle = await _repository.search(
      query: query,
      placeFilters: _placeFilters,
      hashtags: _postHashtags,
    );

    if (!mounted || token != _searchToken) return;

    setState(() {
      _submittedBundle = bundle;
      _loadingSearch = false;
    });
  }

  void _beginEditing() {
    setState(() {
      _editing = true;
      _submitted = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _queryFocusNode.requestFocus();
      }
    });

    if (_queryController.text.trim().isNotEmpty) {
      _runLiveSearch(_queryController.text);
    }
  }

  Future<void> _cancelSearch() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (widget.cancelReturnsToPrevious) {
      Navigator.of(context).maybePop();
      return;
    }

    _queryController.clear();
    _placeFilters.clear();
    _postHashtags.clear();

    setState(() {
      _editing = false;
      _submitted = false;
      _selectedTab = SearchTab.places;
      _liveBundle = const SearchBundle();
      _submittedBundle = const SearchBundle();
      _loadingSearch = false;
    });

    final recents = await _repository.getRecentSearches();
    if (!mounted) return;

    setState(() {
      _recentSearches = recents;
    });
  }

  void _onQueryChanged(String value) {
    if (!_editing || _submitted) {
      setState(() {
        _editing = true;
        _submitted = false;
      });
    }

    final query = value.trim();

    if (query.isEmpty) {
      _searchToken++;

      setState(() {
        _liveBundle = const SearchBundle();
        _loadingSearch = false;
      });
      return;
    }

    _runLiveSearch(query);
  }

  Future<void> _runLiveSearch(String query) async {
    final token = ++_searchToken;

    setState(() {
      _loadingSearch = true;
    });

    final bundle = await _repository.search(
      query: query,
      placeFilters: _placeFilters,
      hashtags: _postHashtags,
    );

    if (!mounted || token != _searchToken) return;

    setState(() {
      _liveBundle = bundle;
      _loadingSearch = false;
    });
  }

  Future<void> _submitSearch(String rawQuery) async {
    final query = rawQuery.trim();

    if (query.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();
    await _repository.saveRecentSearch(query);

    final token = ++_searchToken;

    setState(() {
      _editing = false;
      _submitted = true;
      _selectedTab = widget.cancelReturnsToPrevious
          ? widget.initialTab
          : SearchTab.places;
      _loadingSearch = true;
    });

    final bundle = await _repository.search(
      query: query,
      placeFilters: _placeFilters,
      hashtags: _postHashtags,
    );

    if (!mounted || token != _searchToken) return;

    final recents = await _repository.getRecentSearches();

    if (!mounted || token != _searchToken) return;

    setState(() {
      _submittedBundle = bundle;
      _recentSearches = recents;
      _loadingSearch = false;
    });
  }

  Future<void> _useRecent(String query) async {
    _queryController.text = query;
    _queryController.selection = TextSelection.collapsed(
      offset: query.length,
    );

    await _submitSearch(query);
  }

  Future<void> _removeRecent(String query) async {
    await _repository.removeRecentSearch(query);
    final recents = await _repository.getRecentSearches();

    if (!mounted) return;

    setState(() {
      _recentSearches = recents;
    });
  }

  Future<void> _openPlaceFilter() async {
    final filter = await GoMateBottomSheet.show<SearchPlaceFilter>(
      context: context,
      size: GoMateBottomSheetSize.compact,
      child: PlaceFilterContent(
        selected: _placeFilters,
      ),
    );

    if (!mounted || filter == null) return;

    setState(() {
      if (_placeFilters.contains(filter)) {
        _placeFilters.remove(filter);
      } else {
        _placeFilters.add(filter);
      }
    });

    await _refreshSubmittedResults();
  }

  Future<void> _openHashtagFilter() async {
    final hashtag = await GoMateBottomSheet.show<String>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      child: HashtagFilterContent(
        selected: _postHashtags,
        onSearch: _repository.searchHashtags,
      ),
    );

    if (!mounted || hashtag == null) return;

    setState(() {
      if (_postHashtags.contains(hashtag)) {
        _postHashtags.remove(hashtag);
      } else {
        _postHashtags.add(hashtag);
      }
    });

    await _refreshSubmittedResults();
  }

  Future<void> _refreshSubmittedResults() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    final token = ++_searchToken;

    setState(() {
      _loadingSearch = true;
    });

    final bundle = await _repository.search(
      query: query,
      placeFilters: _placeFilters,
      hashtags: _postHashtags,
    );

    if (!mounted || token != _searchToken) return;

    setState(() {
      _submittedBundle = bundle;
      _loadingSearch = false;
    });
  }

  Future<void> _removePlaceFilter(String label) async {
    final filter = SearchPlaceFilter.values.where(
          (item) => item.label == label,
    );

    if (filter.isEmpty) return;

    setState(() {
      _placeFilters.remove(filter.first);
    });

    await _refreshSubmittedResults();
  }

  Future<void> _removePostHashtag(String tag) async {
    setState(() {
      _postHashtags.remove(tag);
    });

    await _refreshSubmittedResults();
  }

  Future<void> _openPlace(SearchPlaceItem place) async {
    if (place.id <= 0) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceDetailScreen(
          place: MapPlaceUi(
            id: place.id.toString(),
            name: place.name,
            subtitle: place.description ?? '',
            address: place.address ?? place.location,
            distanceText: 'Xem trên bản đồ',
            openInfo: 'Đang cập nhật',
            priceInfo: 'Đang cập nhật',
            rating: place.rating,
            reviewCount: place.reviewCount,
            likeCount: place.saveCount,
            tags: <String>[
              if (place.category != null && place.category!.isNotEmpty)
                place.category!,
              place.location,
            ],
            imageUrl: place.imageUrl,
            mediaUrls: <String>[
              if (place.imageUrl != null && place.imageUrl!.isNotEmpty)
                place.imageUrl!,
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final ui = _SearchMetrics.fromWidth(constraints.maxWidth);

            if (_submitted) {
              return _buildSubmitted(ui);
            }

            if (_editing) {
              return _buildEditing(ui);
            }

            return _buildDiscovery(ui);
          },
        ),
      ),
    );
  }

  Widget _buildDiscovery(_SearchMetrics ui) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
            ui.horizontalPadding,
            ui.topPadding,
            ui.horizontalPadding,
            ui.fixedHeaderBottomGap,
          ),
          child: SearchQueryBar(
            controller: _queryController,
            readOnly: true,
            showBack: true,
            onBack: () => Navigator.of(context).maybePop(),
            onTap: _beginEditing,
          ),
        ),
        Expanded(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              ui.horizontalPadding,
              ui.discoveryContentTopGap,
              ui.horizontalPadding,
              ui.bottomPadding,
            ),
            children: [
              const SearchSectionTitle(title: 'Gợi ý cho bạn'),
              SizedBox(height: ui.itemGap),
              if (_loadingSuggestions)
                SizedBox(
                  height: ui.width * 0.45,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                )
              else if (_suggestedPlaces.isEmpty)
                const SearchEmptyState(
                  text: 'Chưa có gợi ý phù hợp.',
                )
              else
                _buildPlaceGrid(
                  items: _suggestedPlaces,
                  ui: ui,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditing(_SearchMetrics ui) {
    final query = _queryController.text.trim();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            ui.horizontalPadding,
            ui.topPadding,
            ui.horizontalPadding,
            0,
          ),
          child: SearchQueryBar(
            controller: _queryController,
            focusNode: _queryFocusNode,
            showCancel: true,
            onChanged: _onQueryChanged,
            onSubmitted: _submitSearch,
            onCancel: _cancelSearch,
          ),
        ),
        Expanded(
          child: query.isEmpty
              ? _buildRecent(ui)
              : _buildLivePreview(ui),
        ),
      ],
    );
  }

  Widget _buildRecent(_SearchMetrics ui) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        ui.horizontalPadding,
        ui.sectionGap,
        ui.horizontalPadding,
        ui.bottomPadding,
      ),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          const SearchSectionTitle(title: 'Gần đây'),
          SizedBox(height: ui.smallGap),
          for (final recent in _recentSearches)
            SearchRecentRow(
              text: recent,
              onTap: () => _useRecent(recent),
              onRemove: () => _removeRecent(recent),
            ),
        ],
      ],
    );
  }

  Widget _buildLivePreview(_SearchMetrics ui) {
    if (_loadingSearch && _liveBundle.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.2),
      );
    }

    if (_liveBundle.isEmpty) {
      return const SearchEmptyState(
        text: 'Không có kết quả phù hợp',
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        top: ui.sectionGap,
        bottom: ui.bottomPadding,
      ),
      children: [
        if (_liveBundle.places.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: ui.horizontalPadding),
            child: const SearchSectionTitle(title: 'Địa điểm'),
          ),
          SizedBox(height: ui.itemGap),
          SizedBox(
            height: ui.previewPlaceHeight,
            child: ListView.separated(
              clipBehavior: Clip.none,
              padding: EdgeInsets.symmetric(horizontal: ui.horizontalPadding),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _liveBundle.places.length,
              separatorBuilder: (_, __) => SizedBox(width: ui.itemGap),
              itemBuilder: (context, index) {
                final item = _liveBundle.places[index];

                return SearchPlaceCard(
                  item: item,
                  width: ui.previewPlaceWidth,
                  height: ui.previewPlaceHeight,
                  onTap: () => _openPlace(item),
                );
              },
            ),
          ),
          SizedBox(height: ui.sectionGap),
        ],
        if (_liveBundle.users.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: ui.horizontalPadding),
            child: const SearchSectionTitle(title: 'Người dùng'),
          ),
          SizedBox(height: ui.itemGap),
          SizedBox(
            height: ui.width * 0.12,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: ui.horizontalPadding),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _liveBundle.users.length,
              separatorBuilder: (_, __) => SizedBox(width: ui.itemGap),
              itemBuilder: (context, index) {
                return SearchUserPreviewItem(
                  item: _liveBundle.users[index],
                );
              },
            ),
          ),
          SizedBox(height: ui.sectionGap),
        ],
        if (_liveBundle.posts.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: ui.horizontalPadding),
            child: const SearchSectionTitle(title: 'Bài viết'),
          ),
          SizedBox(height: ui.itemGap),

          // Full-bleed ngang như mockup/Home.
          SearchPostGrid(
            items: _liveBundle.posts,
            maxItems: 2,
          ),
        ],
      ],
    );
  }

  Widget _buildSubmitted(_SearchMetrics ui) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            ui.horizontalPadding,
            ui.topPadding,
            ui.horizontalPadding,
            0,
          ),
          child: SearchQueryBar(
            controller: _queryController,
            focusNode: _queryFocusNode,
            showCancel: true,
            onChanged: _onQueryChanged,
            onSubmitted: _submitSearch,
            onCancel: _cancelSearch,
          ),
        ),
        SizedBox(height: ui.smallGap),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: ui.horizontalPadding),
          child: SearchTabs(
            selected: _selectedTab,
            onChanged: (tab) {
              setState(() {
                _selectedTab = tab;
              });
            },
          ),
        ),
        if (_selectedTab == SearchTab.places)
          Padding(
            padding: EdgeInsets.fromLTRB(
              ui.horizontalPadding,
              ui.smallGap,
              ui.horizontalPadding,
              0,
            ),
            child: SearchFilterBar(
              chips: _placeFilters
                  .map((filter) => filter.label)
                  .toList(growable: false),
              onOpenFilter: _openPlaceFilter,
              onRemoveChip: _removePlaceFilter,
            ),
          ),
        if (_selectedTab == SearchTab.posts)
          Padding(
            padding: EdgeInsets.fromLTRB(
              ui.horizontalPadding,
              ui.smallGap,
              ui.horizontalPadding,
              0,
            ),
            child: SearchFilterBar(
              chips: _postHashtags.toList(growable: false),
              onOpenFilter: _openHashtagFilter,
              onRemoveChip: _removePostHashtag,
            ),
          ),
        SizedBox(height: ui.smallGap),
        Expanded(
          child: ClipRect(
            child: _loadingSearch
                ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
                : _buildSelectedResult(ui),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedResult(_SearchMetrics ui) {
    switch (_selectedTab) {
      case SearchTab.places:
        if (_submittedBundle.places.isEmpty) {
          return const SearchEmptyState(
            text: 'Không có địa điểm phù hợp',
          );
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            ui.horizontalPadding,
            ui.resultContentTopGap,
            ui.horizontalPadding,
            ui.bottomPadding,
          ),
          children: [
            _buildPlaceGrid(
              items: _submittedBundle.places,
              ui: ui,
            ),
          ],
        );

      case SearchTab.users:
        if (_submittedBundle.users.isEmpty) {
          return const SearchEmptyState(
            text: 'Không có người dùng phù hợp',
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            ui.horizontalPadding,
            0,
            ui.horizontalPadding,
            ui.bottomPadding,
          ),
          itemCount: _submittedBundle.users.length,
          itemBuilder: (context, index) {
            return SearchUserTile(
              item: _submittedBundle.users[index],
              onAction: () {
                // UI-only. Sau này nối follow/friend backend tại đây.
              },
            );
          },
        );

      case SearchTab.posts:
        if (_submittedBundle.posts.isEmpty) {
          return const SearchEmptyState(
            text: 'Không có bài viết phù hợp',
          );
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            0,
            0,
            0,
            ui.bottomPadding,
          ),
          children: [
            SearchPostGrid(
              items: _submittedBundle.posts,
            ),
          ],
        );
    }
  }

  Widget _buildPlaceGrid({
    required List<SearchPlaceItem> items,
    required _SearchMetrics ui,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      clipBehavior: Clip.none,
      padding: EdgeInsets.zero,
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: ui.gridGap,
        mainAxisSpacing: ui.gridGap,
        childAspectRatio: ui.placeCardWidth / ui.placeCardHeight,
      ),
      itemBuilder: (context, index) {
        final item = items[index];

        return SearchPlaceCard(
          item: item,
          width: ui.placeCardWidth,
          height: ui.placeCardHeight,
          onTap: () => _openPlace(item),
        );
      },
    );
  }
}

class _SearchMetrics {
  final double width;
  final double horizontalPadding;
  final double topPadding;
  final double bottomPadding;
  final double fixedHeaderBottomGap;
  final double discoveryContentTopGap;
  final double resultContentTopGap;
  final double smallGap;
  final double itemGap;
  final double sectionGap;
  final double gridGap;
  final double placeCardWidth;
  final double placeCardHeight;
  final double previewPlaceWidth;
  final double previewPlaceHeight;

  const _SearchMetrics({
    required this.width,
    required this.horizontalPadding,
    required this.topPadding,
    required this.bottomPadding,
    required this.fixedHeaderBottomGap,
    required this.discoveryContentTopGap,
    required this.resultContentTopGap,
    required this.smallGap,
    required this.itemGap,
    required this.sectionGap,
    required this.gridGap,
    required this.placeCardWidth,
    required this.placeCardHeight,
    required this.previewPlaceWidth,
    required this.previewPlaceHeight,
  });

  factory _SearchMetrics.fromWidth(double width) {
    double c(double value, double min, double max) {
      return value.clamp(min, max).toDouble();
    }

    final horizontalPadding = c(width * 0.070, 20, 30);
    final gridGap = c(width * 0.050, 16, 20);

    final cardWidth = (width - (horizontalPadding * 2) - gridGap) / 2;
    final safeCardWidth = c(cardWidth, 132, 180);

    final previewWidth = c(width * 0.40, 140, 160);

    return _SearchMetrics(
      width: width,
      horizontalPadding: horizontalPadding,
      topPadding: c(width * 0.035, 12, 16),
      bottomPadding: c(width * 0.10, 34, 44),
      fixedHeaderBottomGap: c(width * 0.020, 7, 9),
      discoveryContentTopGap: c(width * 0.025, 9, 11),
      resultContentTopGap: c(width * 0.040, 14, 17),
      smallGap: c(width * 0.020, 7, 9),
      itemGap: c(width * 0.035, 12, 15),
      sectionGap: c(width * 0.055, 19, 23),
      gridGap: gridGap,
      placeCardWidth: safeCardWidth,
      placeCardHeight: safeCardWidth * (250 / 150),
      previewPlaceWidth: previewWidth,
      previewPlaceHeight: previewWidth * (230 / 150),
    );
  }
}
