import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class MapPlaceUi {
  final String id;
  final String name;
  final String subtitle;
  final String address;
  final String distanceText;
  final String openInfo;
  final String priceInfo;
  final double rating;
  final int reviewCount;
  final int likeCount;
  final List<String> tags;
  final String? imageAsset;

  const MapPlaceUi({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.address,
    required this.distanceText,
    required this.openInfo,
    required this.priceInfo,
    required this.rating,
    required this.reviewCount,
    required this.likeCount,
    required this.tags,
    this.imageAsset,
  });
}


/// Store UI tạm thời để chia sẻ thư mục Ưa thích giữa Map và Lịch trình.
/// Khi có backend, thay phần này bằng repository/provider/API.
class FavoritePlaceStore {
  FavoritePlaceStore._();

  static final Map<String, List<MapPlaceUi>> folders = {
    'Của tôi': <MapPlaceUi>[],
  };

  static List<String> get folderNames => folders.keys.toList();

  static List<MapPlaceUi> placesIn(String folder) {
    return List<MapPlaceUi>.from(
      folders[folder] ?? const <MapPlaceUi>[],
    );
  }

  static void ensureFolder(String folder) {
    folders.putIfAbsent(
      folder,
          () => <MapPlaceUi>[],
    );
  }

  static void addToFolder(
      String folder,
      MapPlaceUi place,
      ) {
    ensureFolder(folder);

    final list = folders[folder]!;

    final exists = list.any(
          (item) => item.id == place.id,
    );

    if (!exists) {
      list.add(place);
    }
  }

  static void removeFromFolder(
      String folder,
      MapPlaceUi place,
      ) {
    folders[folder]?.removeWhere(
          (item) => item.id == place.id,
    );
  }

  static bool contains(
      String folder,
      MapPlaceUi place,
      ) {
    return folders[folder]?.any(
          (item) => item.id == place.id,
    ) ??
        false;
  }

  static Set<String> foldersContaining(
      MapPlaceUi place,
      ) {
    return folders.entries
        .where(
          (entry) => entry.value.any(
            (item) => item.id == place.id,
      ),
    )
        .map((entry) => entry.key)
        .toSet();
  }
}

class PlaceDetailScreen extends StatefulWidget {
  final MapPlaceUi place;

  const PlaceDetailScreen({
    super.key,
    required this.place,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  late List<String> _favoriteFolders;
  late Set<String> _selectedFolders;

  MapPlaceUi get place => widget.place;

  @override
  void initState() {
    super.initState();

    _favoriteFolders = FavoritePlaceStore.folderNames;
    _selectedFolders =
        FavoritePlaceStore.foldersContaining(place);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildHero(),
              ),

              SliverPadding(
                padding:
                const EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  110,
                ),

                sliver: SliverList(
                  delegate:
                  SliverChildListDelegate(
                    [
                      _buildTitle(),

                      const SizedBox(height: 22),

                      _buildInfo(),

                      const SizedBox(height: 22),

                      _buildReviewSummary(),

                      const SizedBox(height: 20),

                      const Text(
                        'Đánh giá gần đây',

                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color:
                          AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 12),

                      ...List.generate(
                        3,
                        _buildReview,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SafeArea(
            child: Padding(
              padding:
              const EdgeInsets.fromLTRB(
                16,
                10,
                16,
                0,
              ),

              child: Row(
                children: [
                  _circleButton(
                    Icons.arrow_back_rounded,
                        () => Navigator.pop(context),
                  ),

                  const Spacer(),

                  _favoriteButton(),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        top: false,

        child: Padding(
          padding:
          const EdgeInsets.fromLTRB(
            20,
            8,
            20,
            18,
          ),

          child: SizedBox(
            height: 54,

            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },

              icon: const Icon(
                Icons.route_rounded,
              ),

              label: const Text(
                'Chỉ đường đến đây',

                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),

              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor:
                AppColors.blue500,
                foregroundColor: Colors.white,

                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(27),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HERO - IMAGE FADES INTO WHITE
  // ============================================================

  Widget _buildHero() {
    return SizedBox(
      height: 330,

      child: Stack(
        fit: StackFit.expand,

        children: [
          if (place.imageAsset != null)
            Image.asset(
              place.imageAsset!,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) =>
                  _heroFallback(),
            )
          else
            _heroFallback(),

          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,

                colors: [
                  Colors.transparent,
                  Color(0x33FFFFFF),
                  Color(0xCCFFFFFF),
                  Colors.white,
                ],

                stops: [
                  0,
                  0.48,
                  0.82,
                  1,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,

          colors: [
            AppColors.blue100,
            AppColors.blue300,
          ],
        ),
      ),

      child: const Icon(
        Icons.place_rounded,
        size: 70,
        color: Colors.white,
      ),
    );
  }

  // ============================================================
  // INFO
  // ============================================================

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        Text(
          place.name,

          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            const Icon(
              Icons.star_rounded,
              size: 20,
              color: Color(0xFFFFB547),
            ),

            const SizedBox(width: 5),

            Text(
              place.rating.toStringAsFixed(1),

              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(width: 8),

            Text(
              '${place.reviewCount} lượt đánh giá',

              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Text(
          place.subtitle,

          style: const TextStyle(
            fontSize: 14.5,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfo() {
    final data = [
      (
      Icons.place_outlined,
      'Địa chỉ',
      place.address,
      ),
      (
      Icons.route_outlined,
      'Khoảng cách',
      place.distanceText,
      ),
      (
      Icons.schedule_outlined,
      'Thời gian',
      place.openInfo,
      ),
      (
      Icons.attach_money_rounded,
      'Chi phí',
      place.priceInfo,
      ),
      (
      Icons.local_offer_outlined,
      'Phù hợp',
      place.tags.join(' • '),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),

        border: Border.all(
          color:
          AppColors.blue100.withOpacity(0.55),
        ),
      ),

      child: Column(
        children: List.generate(
          data.length,

              (index) {
            final item = data[index];

            return Padding(
              padding: EdgeInsets.only(
                bottom:
                index == data.length - 1
                    ? 0
                    : 14,
              ),

              child: _infoRow(
                item.$1,
                item.$2,
                item.$3,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoRow(
      IconData icon,
      String title,
      String value,
      ) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        Container(
          width: 38,
          height: 38,

          decoration: BoxDecoration(
            color: AppColors.blue50,
            borderRadius:
            BorderRadius.circular(12),
          ),

          child: Icon(
            icon,
            size: 20,
            color: AppColors.blue500,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              Text(
                title,

                style: const TextStyle(
                  fontSize: 12.5,
                  color:
                  AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                value,

                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color:
                  AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // REVIEWS
  // ============================================================

  Widget _buildReviewSummary() {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color:
        AppColors.blue50.withOpacity(0.40),
        borderRadius: BorderRadius.circular(22),
      ),

      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                const Text(
                  'Đánh giá nổi bật',

                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color:
                    AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  '${place.rating.toStringAsFixed(1)} • ${place.reviewCount} lượt đánh giá',

                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color:
                    AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '${place.likeCount} bài viết • ${place.likeCount * 2} lượt thích',

                  style: const TextStyle(
                    fontSize: 13,
                    color:
                    AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          ElevatedButton(
            onPressed: () {},

            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor:
              AppColors.blue500,
              foregroundColor: Colors.white,

              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(15),
              ),
            ),

            child: const Text(
              'Đánh giá',

              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReview(int index) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),

      child: Container(
        padding: const EdgeInsets.all(15),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),

          border: Border.all(
            color:
            AppColors.blue100.withOpacity(0.40),
          ),
        ),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 21,
                  backgroundColor:
                  AppColors.blue200,

                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(width: 11),

                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      Text(
                        'Buji',

                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                          FontWeight.w800,
                          color:
                          AppColors.textPrimary,
                        ),
                      ),

                      Text(
                        'Ngày tháng',

                        style: TextStyle(
                          fontSize: 12,
                          color:
                          AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: AppColors.blue500,
                ),

                const SizedBox(width: 4),

                Text(
                  place.rating.toStringAsFixed(1),

                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 11),

            const Text(
              'Caption, viết đánh giá',

              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),

            if (index == 0) ...[
              const SizedBox(height: 11),

              Row(
                children: [
                  Expanded(
                    child:
                    _reviewImagePlaceholder(),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child:
                    _reviewImagePlaceholder(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reviewImagePlaceholder() {
    return Container(
      height: 100,

      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: BorderRadius.circular(14),
      ),

      child: const Icon(
        Icons.image_outlined,
        color: AppColors.blue500,
      ),
    );
  }

  Widget _favoriteButton() {
    final isFavorite = _selectedFolders.isNotEmpty;

    return InkWell(
      onTap: _openFavoriteFolders,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          size: 20,
          color: isFavorite
              ? AppColors.blue500
              : AppColors.textPrimary,
        ),
      ),
    );
  }

  Future<void> _openFavoriteFolders() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _FavoriteFolderSheet(
          folders: List<String>.from(_favoriteFolders),
          selectedFolders: Set<String>.from(_selectedFolders),
        );
      },
    );

    if (result == null) return;

    setState(() {
      final oldFolders = Set<String>.from(_selectedFolders);

      _selectedFolders = result;

      for (final folder in result) {
        FavoritePlaceStore.ensureFolder(folder);
        FavoritePlaceStore.addToFolder(
          folder,
          place,
        );
      }

      for (final folder in oldFolders.difference(result)) {
        FavoritePlaceStore.removeFromFolder(
          folder,
          place,
        );
      }

      _favoriteFolders =
          FavoritePlaceStore.folderNames;
    });
  }

  Widget _circleButton(
      IconData icon,
      VoidCallback onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),

      child: Container(
        width: 42,
        height: 42,

        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          shape: BoxShape.circle,

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),

        child: Icon(
          icon,
          size: 20,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}


class _FavoriteFolderSheet extends StatefulWidget {
  final List<String> folders;
  final Set<String> selectedFolders;

  const _FavoriteFolderSheet({
    required this.folders,
    required this.selectedFolders,
  });

  @override
  State<_FavoriteFolderSheet> createState() => _FavoriteFolderSheetState();
}

class _FavoriteFolderSheetState extends State<_FavoriteFolderSheet> {
  late List<String> _folders;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _folders = List<String>.from(widget.folders);
    _selected = Set<String>.from(widget.selectedFolders);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.54,
      minChildSize: 0.36,
      maxChildSize: 0.82,
      snap: true,
      snapSizes: const [0.36, 0.54, 0.82],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.blue100,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thêm vào Ưa thích',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Chọn một hoặc nhiều thư mục.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    18,
                  ),
                  children: [
                    ..._folders.map(
                          (folder) => _folderTile(folder),
                    ),

                    const SizedBox(height: 8),

                    InkWell(
                      onTap: _createFolder,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.blue50.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.blue100,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.create_new_folder_outlined,
                              color: AppColors.blue500,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tạo thư mục mới',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.blue500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.add_rounded,
                              color: AppColors.blue500,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  18,
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          Set<String>.from(_selected),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppColors.blue500,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Xong',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _folderTile(String folder) {
    final selected = _selected.contains(folder);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          setState(() {
            if (selected) {
              _selected.remove(folder);
            } else {
              _selected.add(folder);
            }
          });
        },
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.blue50
                : const Color(0xFFF8FAFB),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppColors.blue300
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  selected
                      ? Icons.folder_rounded
                      : Icons.folder_outlined,
                  color: AppColors.blue500,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  folder,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: selected
                    ? const Icon(
                  Icons.check_circle_rounded,
                  key: ValueKey('selected'),
                  color: AppColors.blue500,
                )
                    : const Icon(
                  Icons.circle_outlined,
                  key: ValueKey('empty'),
                  color: AppColors.blue200,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Tạo thư mục mới'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Tên thư mục',
            ),
            onSubmitted: (value) {
              final result = value.trim();

              if (result.isNotEmpty) {
                Navigator.pop(
                  dialogContext,
                  result,
                );
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Huỷ'),
            ),
            TextButton(
              onPressed: () {
                final result = controller.text.trim();

                if (result.isNotEmpty) {
                  Navigator.pop(
                    dialogContext,
                    result,
                  );
                }
              },
              child: const Text('Tạo'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (name == null ||
        name.isEmpty ||
        _folders.contains(name)) {
      return;
    }

    setState(() {
      _folders.add(name);
      _selected.add(name);
    });
  }
}
