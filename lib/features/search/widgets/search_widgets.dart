import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../models/search_models.dart';

double searchFont(double width, double baseAt360) {
  final value = baseAt360 * (width / 360);
  return value.clamp(baseAt360 * 0.93, baseAt360 * 1.12).toDouble();
}

class SearchQueryBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool showBack;
  final bool showCancel;
  final String hintText;
  final VoidCallback? onTap;
  final VoidCallback? onBack;
  final VoidCallback? onCancel;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const SearchQueryBar({
    super.key,
    required this.controller,
    this.focusNode,
    this.readOnly = false,
    this.showBack = false,
    this.showCancel = false,
    this.hintText = 'Tìm kiếm ....',
    this.onTap,
    this.onBack,
    this.onCancel,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final barHeight = (width * 0.095).clamp(35.0, 40.0);
    final iconSize = (width * 0.058).clamp(20.0, 23.0);
    final sideButtonSize = (width * 0.105).clamp(38.0, 44.0);

    return Row(
      children: [
        if (showBack) ...[
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              width: sideButtonSize,
              height: sideButtonSize,
              child: Center(
                child: Icon(
                  LucideIcons.chevron_left,
                  size: iconSize,
                  color: AppColors.black,
                ),
              ),
            ),
          ),
          SizedBox(width: width * 0.010),
        ],
        Expanded(
          child: Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(barHeight * 0.50),
            ),
            padding: EdgeInsets.only(
              left: width * 0.030,
              right: showCancel ? width * 0.012 : width * 0.030,
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.search,
                  size: iconSize,
                  color: AppColors.grayText,
                ),
                SizedBox(width: width * 0.020),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    readOnly: readOnly,
                    textInputAction: TextInputAction.search,
                    onTap: onTap,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    cursorColor: AppColors.primaryIcon,
                    style: TextStyle(
                      fontSize: searchFont(width, 14),
                      fontWeight: FontWeight.w500,
                      color: AppColors.black,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: hintText,
                      hintStyle: TextStyle(
                        fontSize: searchFont(width, 14),
                        fontWeight: FontWeight.w500,
                        color: AppColors.grayText,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (showCancel)
                  InkWell(
                    onTap: onCancel,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: width * 0.018,
                        vertical: width * 0.010,
                      ),
                      child: Text(
                        'Huỷ',
                        style: TextStyle(
                          fontSize: searchFont(width, 13.5),
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SearchTabs extends StatelessWidget {
  final SearchTab selected;
  final ValueChanged<SearchTab> onChanged;

  const SearchTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Row(
      children: SearchTab.values.map((tab) {
        final selectedTab = selected == tab;
        final label = switch (tab) {
          SearchTab.places => 'Địa điểm',
          SearchTab.users => 'Người dùng',
          SearchTab.posts => 'Bài viết',
        };

        return Expanded(
          child: InkWell(
            onTap: () => onChanged(tab),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: width * 0.020),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: searchFont(width, 13),
                  fontWeight: FontWeight.w600,
                  color: selectedTab
                      ? AppColors.primaryText
                      : AppColors.grayText,
                ),
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class SearchSectionTitle extends StatelessWidget {
  final String title;

  const SearchSectionTitle({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Text(
      title,
      style: TextStyle(
        fontSize: searchFont(width, 13),
        fontWeight: FontWeight.w700,
        color: AppColors.black,
      ),
    );
  }
}

class SearchFilterBar extends StatelessWidget {
  final List<String> chips;
  final VoidCallback onOpenFilter;
  final ValueChanged<String> onRemoveChip;

  const SearchFilterBar({
    super.key,
    required this.chips,
    required this.onOpenFilter,
    required this.onRemoveChip,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final iconSize = (width * 0.060).clamp(21.0, 24.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(
            spacing: width * 0.030,
            runSpacing: width * 0.018,
            children: chips
                .map(
                  (chip) => SearchFilterChip(
                label: chip,
                onRemove: () => onRemoveChip(chip),
              ),
            )
                .toList(growable: false),
          ),
        ),
        InkWell(
          onTap: onOpenFilter,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.all(width * 0.015),
            child: Icon(
              LucideIcons.sliders_horizontal,
              size: iconSize,
              color: AppColors.primaryIcon,
            ),
          ),
        ),
      ],
    );
  }
}

class SearchFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const SearchFilterChip({
    super.key,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final closeSize = (width * 0.033).clamp(11.0, 13.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: searchFont(width, 13),
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        SizedBox(width: width * 0.004),
        InkWell(
          onTap: onRemove,
          customBorder: const CircleBorder(),
          child: Container(
            width: closeSize + 5,
            height: closeSize + 5,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryIcon,
            ),
            alignment: Alignment.center,
            child: Icon(
              LucideIcons.x,
              size: closeSize,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class SearchPlaceCard extends StatelessWidget {
  final SearchPlaceItem item;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const SearchPlaceCard({
    super.key,
    required this.item,
    required this.width,
    required this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = (width * 0.13).clamp(16.0, 21.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: AppColors.elevatedShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _SearchNetworkImage(url: item.imageUrl),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.45, 0.72, 1],
                    colors: [
                      Colors.transparent,
                      Color(0x18000000),
                      Color(0xA8000000),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: width * 0.055,
                right: width * 0.055,
                child: _SearchRatingBadge(
                  rating: item.rating,
                  width: width,
                ),
              ),
              Positioned(
                left: width * 0.075,
                right: width * 0.075,
                bottom: width * 0.075,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: (width * 0.073).clamp(9.5, 11.0),
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: width * 0.018),
                    Text(
                      item.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: (width * 0.064).clamp(9.0, 10.5),
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchUserTile extends StatelessWidget {
  final SearchUserItem item;
  final VoidCallback? onTap;
  final VoidCallback? onAction;

  const SearchUserTile({
    super.key,
    required this.item,
    this.onTap,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final avatarSize = (width * 0.095).clamp(34.0, 40.0);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: width * 0.020),
        child: Row(
          children: [
            SearchUserAvatar(
              item: item,
              size: avatarSize,
            ),
            SizedBox(width: width * 0.030),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: searchFont(width, 13),
                      fontWeight: FontWeight.w500,
                      color: AppColors.black,
                    ),
                  ),
                  SizedBox(height: width * 0.006),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: searchFont(width, 11.5),
                      fontWeight: FontWeight.w400,
                      color: AppColors.grayText,
                    ),
                  ),
                ],
              ),
            ),
            if (item.actionLabel != null)
              InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.018,
                    vertical: width * 0.014,
                  ),
                  child: Text(
                    item.actionLabel!,
                    style: TextStyle(
                      fontSize: searchFont(width, 10),
                      fontWeight: FontWeight.w500,
                      color: (item.relation == SearchUserRelation.friend ||
                          item.relation == SearchUserRelation.following)
                          ? AppColors.grayText
                          : AppColors.primaryText,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SearchUserPreviewItem extends StatelessWidget {
  final SearchUserItem item;

  const SearchUserPreviewItem({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final avatar = (width * 0.090).clamp(32.0, 38.0);

    return SizedBox(
      width: (width * 0.38).clamp(132.0, 158.0),
      child: Row(
        children: [
          SearchUserAvatar(item: item, size: avatar),
          SizedBox(width: width * 0.018),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: searchFont(width, 12.5),
                    fontWeight: FontWeight.w500,
                    color: AppColors.black,
                  ),
                ),
                SizedBox(height: width * 0.005),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: searchFont(width, 10.5),
                    color: AppColors.grayText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SearchUserAvatar extends StatelessWidget {
  final SearchUserItem item;
  final double size;

  const SearchUserAvatar({
    super.key,
    required this.item,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (item.avatarAsset != null && item.avatarAsset!.isNotEmpty) {
      child = Image.asset(
        item.avatarAsset!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _avatarFallback(),
      );
    } else if (item.avatarUrl != null && item.avatarUrl!.isNotEmpty) {
      child = Image.network(
        item.avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _avatarFallback(),
      );
    } else {
      child = _avatarFallback();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE7EBF3),
        border: Border.all(color: AppColors.grayBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _avatarFallback() {
    return Center(
      child: Icon(
        LucideIcons.user,
        size: size * 0.60,
        color: Colors.white,
      ),
    );
  }
}

class SearchPostGrid extends StatelessWidget {
  final List<SearchPostItem> items;
  final int maxItems;

  const SearchPostGrid({
    super.key,
    required this.items,
    this.maxItems = 999,
  });

  @override
  Widget build(BuildContext context) {
    final visible = items.take(maxItems).toList(growable: false);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: visible.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final post = visible[index];

        return Image.asset(
          post.imageAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              color: const Color(0xFFE7EBF3),
              alignment: Alignment.center,
              child: const Icon(
                LucideIcons.image,
                color: AppColors.grayText,
              ),
            );
          },
        );
      },
    );
  }
}

class SearchRecentRow extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const SearchRecentRow({
    super.key,
    required this.text,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: width * 0.020),
        child: Row(
          children: [
            Icon(
              LucideIcons.clock,
              size: (width * 0.058).clamp(20.0, 23.0),
              color: AppColors.black,
            ),
            SizedBox(width: width * 0.038),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: searchFont(width, 13),
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),
            ),
            InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: EdgeInsets.all(width * 0.012),
                child: Icon(
                  LucideIcons.x,
                  size: (width * 0.040).clamp(14.0, 16.0),
                  color: AppColors.grayText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchEmptyState extends StatelessWidget {
  final String text;

  const SearchEmptyState({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: width * 0.12),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: searchFont(width, 12),
            color: AppColors.grayText,
          ),
        ),
      ),
    );
  }
}

class _SearchRatingBadge extends StatelessWidget {
  final double rating;
  final double width;

  const _SearchRatingBadge({
    required this.rating,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.045,
        vertical: width * 0.026,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(width * 0.09),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: width * 0.10,
            color: AppColors.primaryIcon,
          ),
          SizedBox(width: width * 0.018),
          Text(
            rating.toStringAsFixed(1).replaceAll('.', ','),
            style: TextStyle(
              fontSize: width * 0.075,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchNetworkImage extends StatelessWidget {
  final String? url;

  const _SearchNetworkImage({
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    final source = url?.trim();

    if (source == null || source.isEmpty) {
      return _fallback();
    }

    return Image.network(
      source,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallback(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            _fallback(),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFE7EBF3),
      alignment: Alignment.center,
      child: const Icon(
        LucideIcons.image,
        color: AppColors.grayText,
      ),
    );
  }
}
