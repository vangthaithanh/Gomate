import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/services/content_access_changes.dart';
import '../../posts/data/post_repository.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../../map/screens/place_detail_screen.dart';
import '../../profile/screens/public_profile_screen.dart';
import '../data/search_repository.dart';
import '../models/search_models.dart';
import '../widgets/search_filter_content.dart';
import '../widgets/search_widgets.dart';
import '../../profile/screens/profile_post_feed_screen.dart';

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

class _SearchScreenState extends State<SearchScreen>
    with WidgetsBindingObserver {
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
  String? _searchError;
  String? _suggestionError;

  String? _actor;
  bool _loadingNext = false;
  int _searchToken = 0;
  Timer? _liveSearchDebounce;

  @override
  void initState() {
    super.initState();

    _repository = widget.repository ?? SearchRepository();
    _actor = _repository.auth.user?['id']?.toString();
    _repository.auth.addListener(_authChanged);
    ContentAccessChanges.revision.addListener(_accessChanged);
    PostChanges.revision.addListener(_accessChanged);
    WidgetsBinding.instance.addObserver(this);

    _queryController.text = widget.initialQuery;
    _selectedTab = widget.initialTab;
    _postHashtags.addAll(widget.initialHashtags);

    _loadInitialData();
  }

  Future<void> _openPostFeed(List<SearchPostItem> source, int index) async {
    if (index < 0 || index >= source.length) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GoMateProfilePostFeedScreen(
          posts: const [],
          remote: true,
          postId: source[index].id,
          repository: PostRepository(auth: _repository.auth),
        ),
      ),
    );
    if (mounted) _accessChanged();
  }

  void _authChanged() {
    if (_actor == _repository.auth.user?['id']?.toString()) return;
    _actor = _repository.auth.user?['id']?.toString();
    ++_searchToken;
    _liveSearchDebounce?.cancel();
    setState(() {
      _liveBundle = const SearchBundle();
      _submittedBundle = const SearchBundle();
      _suggestedPlaces = const [];
      _recentSearches = const [];
      _queryController.clear();
      _postHashtags.clear();
      _placeFilters.clear();
      _editing = false;
      _submitted = false;
      _loadingSearch = false;
      _loadingSuggestions = false;
      _loadingNext = false;
    });
  }

  void _accessChanged() {
    if (!mounted) return;
    if (_submitted) {
      _refreshSubmittedResults();
    } else if (_editing && _queryController.text.trim().isNotEmpty) {
      _runLiveSearch(_queryController.text.trim());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _accessChanged();
  }

  String _error(Object error) => error is ApiException
      ? error.message
      : error is StateError
      ? error.message.toString()
      : 'Không tải được kết quả. Kiểm tra kết nối máy chủ.';

  Future<void> _loadInitialData() async {
    final actor = _actor;
    String? suggestionError;
    try {
      final results = await Future.wait<dynamic>([
        _repository.getSuggestedPlaces().catchError((Object error) {
          suggestionError = _error(error);
          return <SearchPlaceItem>[];
        }),
        _repository.getRecentSearches().catchError((Object error) {
          return <String>[];
        }),
      ]);

      if (!mounted || actor != _actor) return;

      setState(() {
        _suggestionError = suggestionError;
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

    if (widget.startSubmitted &&
        (widget.initialQuery.trim().isNotEmpty || _postHashtags.isNotEmpty)) {
      await _loadInitialSubmittedSearch();
    }
  }

  Future<void> _loadInitialSubmittedSearch() async {
    final query = widget.initialQuery.trim();
    if (query.isEmpty && _postHashtags.isEmpty) return;

    final token = ++_searchToken;

    setState(() {
      _editing = false;
      _submitted = true;
      _selectedTab = widget.initialTab;
      _loadingSearch = true;
    });

    SearchBundle bundle;
    try {
      bundle = await _repository.search(
        query: query,
        placeFilters: Set.of(_placeFilters),
        hashtags: Set.of(_postHashtags),
      );
    } catch (error) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _submittedBundle = const SearchBundle();
        _loadingSearch = false;
        _searchError = _error(error);
      });
      return;
    }

    if (!mounted || token != _searchToken) return;

    setState(() {
      _submittedBundle = bundle;
      _loadingSearch = false;
      _searchError = null;
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
    ++_searchToken;
    _liveSearchDebounce?.cancel();
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

    List<String> recents;
    try {
      recents = await _repository.getRecentSearches();
    } catch (_) {
      recents = const [];
    }
    if (!mounted) return;

    setState(() {
      _recentSearches = recents;
    });
  }

  void _onQueryChanged(String value) {
    ++_searchToken;
    _liveSearchDebounce?.cancel();
    _loadingNext = false;
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
        _searchError = null;
      });
      return;
    }

    _liveSearchDebounce?.cancel();
    _liveSearchDebounce = Timer(
      const Duration(milliseconds: 320),
      () => _runLiveSearch(query),
    );
  }

  Future<void> _runLiveSearch(String query) async {
    final token = ++_searchToken;

    setState(() {
      _loadingSearch = true;
      _searchError = null;
    });

    SearchBundle bundle;
    try {
      bundle = await _repository.search(
        query: query,
        placeFilters: Set.of(_placeFilters),
        hashtags: Set.of(_postHashtags),
      );
    } catch (error) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _liveBundle = const SearchBundle();
        _loadingSearch = false;
        _searchError = _error(error);
      });
      return;
    }

    if (!mounted || token != _searchToken) return;

    setState(() {
      _liveBundle = bundle;
      _loadingSearch = false;
      _searchError = null;
    });
  }

  Future<void> _submitSearch(String rawQuery) async {
    final query = rawQuery.trim();

    if (query.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();
    _liveSearchDebounce?.cancel();
    final token = ++_searchToken;

    setState(() {
      _editing = false;
      _submitted = true;
      _selectedTab = widget.cancelReturnsToPrevious
          ? widget.initialTab
          : SearchTab.places;
      _loadingSearch = true;
      _searchError = null;
    });

    SearchBundle bundle;
    try {
      await _repository.saveRecentSearch(query);
      if (!mounted || token != _searchToken) return;
      bundle = await _repository.search(
        query: query,
        placeFilters: Set.of(_placeFilters),
        hashtags: Set.of(_postHashtags),
      );
    } catch (error) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _submittedBundle = const SearchBundle();
        _loadingSearch = false;
        _searchError = _error(error);
      });
      return;
    }

    if (!mounted || token != _searchToken) return;

    List<String> recents;
    try {
      recents = await _repository.getRecentSearches();
    } catch (_) {
      recents = _recentSearches;
    }

    if (!mounted || token != _searchToken) return;

    setState(() {
      _submittedBundle = bundle;
      _recentSearches = recents;
      _loadingSearch = false;
      _searchError = null;
    });
  }

  Future<void> _useRecent(String query) async {
    _queryController.text = query;
    _queryController.selection = TextSelection.collapsed(offset: query.length);

    await _submitSearch(query);
  }

  Future<void> _removeRecent(String query) async {
    try {
      await _repository.removeRecentSearch(query);
      final recents = await _repository.getRecentSearches();
      if (mounted) setState(() => _recentSearches = recents);
    } catch (_) {
      if (mounted)
        GoMateSnackBar.show(
          context,
          message: 'Không xóa được lịch sử. Hãy thử lại.',
        );
    }
  }

  Future<void> _openPlaceFilter() async {
    final filter = await GoMateBottomSheet.show<SearchPlaceFilter>(
      context: context,
      size: GoMateBottomSheetSize.compact,
      child: PlaceFilterContent(selected: _placeFilters),
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
      _searchError = null;
    });

    SearchBundle bundle;
    try {
      bundle = await _repository.search(
        query: query,
        placeFilters: Set.of(_placeFilters),
        hashtags: Set.of(_postHashtags),
      );
    } catch (error) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _loadingSearch = false;
        _searchError = _error(error);
      });
      return;
    }

    if (!mounted || token != _searchToken) return;

    setState(() {
      _submittedBundle = bundle;
      _loadingSearch = false;
      _searchError = null;
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

  Future<void> _openUser(SearchUserItem user) async {
    if (user.id.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PublicProfileScreen(userId: user.id, repository: _repository),
      ),
    );
    if (!mounted) return;
    await _refreshSubmittedResults();
    if (_queryController.text.trim().isNotEmpty && _editing) {
      await _runLiveSearch(_queryController.text.trim());
    }
  }

  Future<void> _toggleUserFollow(SearchUserItem user) async {
    if (user.id.isEmpty) return;
    try {
      if (user.relation == SearchUserRelation.none ||
          user.relation == SearchUserRelation.followsYou) {
        final relation = await _repository.followUser(user.id);
        if (!mounted) return;
        GoMateSnackBar.show(
          context,
          message: relation == SearchUserRelation.pending
              ? 'Đã gửi yêu cầu theo dõi ${user.name}'
              : 'Đã theo dõi ${user.name}',
        );
      } else {
        await _repository.unfollowUser(user.id);
        if (!mounted) return;
        GoMateSnackBar.show(
          context,
          message: user.relation == SearchUserRelation.pending
              ? 'Đã hủy yêu cầu theo dõi'
              : 'Đã bỏ theo dõi',
        );
      }
      await _repository.auth.loadProfile().catchError((_) {});
      await _refreshSubmittedResults();
      if (_queryController.text.trim().isNotEmpty && _editing) {
        await _runLiveSearch(_queryController.text.trim());
      }
    } catch (_) {
      if (!mounted) return;
      GoMateSnackBar.show(
        context,
        message: 'Không thể cập nhật quan hệ lúc này.',
      );
    }
  }

  @override
  void dispose() {
    _repository.auth.removeListener(_authChanged);
    ContentAccessChanges.revision.removeListener(_accessChanged);
    PostChanges.revision.removeListener(_accessChanged);
    WidgetsBinding.instance.removeObserver(this);
    _liveSearchDebounce?.cancel();
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
              else if (_suggestionError != null)
                SearchEmptyState(text: _suggestionError!)
              else if (_suggestedPlaces.isEmpty)
                const SearchEmptyState(text: 'Chưa có gợi ý phù hợp.')
              else
                _buildPlaceGrid(items: _suggestedPlaces, ui: ui),
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
          child: query.isEmpty ? _buildRecent(ui) : _buildLivePreview(ui),
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
    if (_searchError != null) {
      return SearchEmptyState(text: _searchError!);
    }

    if (_loadingSearch && _liveBundle.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.2));
    }

    if (_liveBundle.isEmpty) {
      return const SearchEmptyState(text: 'Không có kết quả phù hợp');
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(top: ui.sectionGap, bottom: ui.bottomPadding),
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
                  onTap: () => _openUser(_liveBundle.users[index]),
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
            auth: _repository.auth,
            items: _liveBundle.posts,
            maxItems: 2,
            onTapIndex: (index) => _openPostFeed(_liveBundle.posts, index),
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
                : NotificationListener<ScrollNotification>(
                    onNotification: (notice) {
                      if (notice.metrics.axis == Axis.vertical &&
                          notice.metrics.extentAfter < 250)
                        _loadNext();
                      return false;
                    },
                    child: _buildSelectedResult(ui),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _loadNext() async {
    final current = _submittedBundle;
    final tab = _selectedTab;
    final hasMore = switch (tab) {
      SearchTab.places => current.placeCursor != null,
      SearchTab.users => current.userNextPage != null,
      SearchTab.posts => current.postCursor != null,
    };
    if (!hasMore || _loadingNext || _loadingSearch || !_submitted) return;
    _loadingNext = true;
    final token = _searchToken;
    try {
      final next = await _repository.nextPage(
        query: _queryController.text.trim(),
        tab: tab,
        current: current,
        placeFilters: Set.of(_placeFilters),
        hashtags: Set.of(_postHashtags),
      );
      if (!mounted || token != _searchToken) return;
      setState(() {
        final live = _submittedBundle;
        _submittedBundle = SearchBundle(
          placeError: live.placeError,
          latitude: live.latitude,
          longitude: live.longitude,
          places: tab == SearchTab.places
              ? {
                  for (final p in [...live.places, ...next.places]) p.id: p,
                }.values.toList()
              : live.places,
          users: tab == SearchTab.users
              ? {
                  for (final u in [...live.users, ...next.users]) u.id: u,
                }.values.toList()
              : live.users,
          posts: tab == SearchTab.posts
              ? {
                  for (final p in [...live.posts, ...next.posts]) p.id: p,
                }.values.toList()
              : live.posts,
          placeCursor: tab == SearchTab.places
              ? next.placeCursor
              : live.placeCursor,
          postCursor: tab == SearchTab.posts
              ? next.postCursor
              : live.postCursor,
          userNextPage: tab == SearchTab.users
              ? next.userNextPage
              : live.userNextPage,
        );
      });
    } catch (error) {
      if (mounted && token == _searchToken)
        GoMateSnackBar.show(context, message: _error(error));
    } finally {
      _loadingNext = false;
    }
  }

  Widget _buildSelectedResult(_SearchMetrics ui) {
    if (_searchError != null) {
      return SearchEmptyState(text: _searchError!);
    }

    switch (_selectedTab) {
      case SearchTab.places:
        if (_submittedBundle.placeError != null)
          return SearchEmptyState(text: _submittedBundle.placeError!);
        if (_submittedBundle.places.isEmpty) {
          return const SearchEmptyState(text: 'Không có địa điểm phù hợp');
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            ui.horizontalPadding,
            ui.resultContentTopGap,
            ui.horizontalPadding,
            ui.bottomPadding,
          ),
          children: [_buildPlaceGrid(items: _submittedBundle.places, ui: ui)],
        );

      case SearchTab.users:
        if (_submittedBundle.users.isEmpty) {
          return const SearchEmptyState(text: 'Không có người dùng phù hợp');
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
              onTap: () => _openUser(_submittedBundle.users[index]),
              onAction: () => _toggleUserFollow(_submittedBundle.users[index]),
            );
          },
        );

      case SearchTab.posts:
        if (_submittedBundle.posts.isEmpty) {
          return const SearchEmptyState(text: 'Không có bài viết phù hợp');
        }

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(0, 0, 0, ui.bottomPadding),
          children: [
            SearchPostGrid(
              auth: _repository.auth,
              items: _submittedBundle.posts,
              onTapIndex: (index) =>
                  _openPostFeed(_submittedBundle.posts, index),
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
