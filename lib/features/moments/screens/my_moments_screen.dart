import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/snackbar.dart';
import '../data/moments_repository.dart';
import '../models/moment_models.dart';
import '../widgets/moment_components.dart';
import '../widgets/moment_image_frame.dart';
import 'my_moment_detail_screen.dart';

class MyMomentsScreen extends StatefulWidget {
  final MomentsRepository repository;

  const MyMomentsScreen({
    super.key,
    required this.repository,
  });

  @override
  State<MyMomentsScreen> createState() => _MyMomentsScreenState();
}

class _MyMomentsScreenState extends State<MyMomentsScreen> {
  bool _selectionMode = false;
  final List<String> _selectionOrder = <String>[];

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_repositoryChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_repositoryChanged);
    super.dispose();
  }

  void _repositoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final groups = _buildGroups(widget.repository.myMoments);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            double c(double value, double min, double max) {
              return value.clamp(min, max).toDouble();
            }

            final horizontalPadding = c(width * 0.075, 24, 30);
            final headerHeight = c(width * 0.155, 54, 66);
            final iconSize = c(width * 0.064, 22, 25);
            final titleSize = c(width * 0.043, 15, 17);
            final bottomActionSpace = _selectionMode
                ? c(height * 0.105, 72, 88)
                : c(height * 0.025, 12, 20);

            return Column(
              children: [
                SizedBox(
                  height: headerHeight,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: horizontalPadding),
                          child: _HeaderIcon(
                            icon: LucideIcons.chevron_left,
                            size: iconSize,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                      Text(
                        'Khoảnh khắc của bạn',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: titleSize,
                          height: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.only(right: horizontalPadding),
                          child: _HeaderIcon(
                            icon: LucideIcons.copy,
                            size: iconSize,
                            color: _selectionMode
                                ? AppColors.black
                                : AppColors.grayText,
                            onTap: _toggleSelectionMode,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Stack(
                    children: [
                      ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          c(width * 0.025, 8, 12),
                          horizontalPadding,
                          bottomActionSpace,
                        ),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return _MomentGroup(
                            title: group.title,
                            items: group.items,
                            width: width,
                            selectionMode: _selectionMode,
                            selectionOrder: _selectionOrder,
                            trailing: index == 0 && _selectionMode
                                ? GestureDetector(
                                    onTap: _toggleSelectAll,
                                    child: Text(
                                      _selectionOrder.isEmpty
                                          ? 'Chọn tất cả'
                                          : '(${_selectionOrder.length}) Chọn tất cả',
                                      style: TextStyle(
                                        color: AppColors.primaryText,
                                        fontSize: c(width * 0.027, 9.5, 11),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                : null,
                            onTap: _onMomentTap,
                          );
                        },
                      ),

                      if (_selectionMode)
                        Positioned(
                          left: horizontalPadding,
                          right: horizontalPadding,
                          bottom: c(height * 0.022, 12, 18),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _RoundGradientButton(
                                size: c(width * 0.13, 46, 52),
                                icon: LucideIcons.download,
                                onTap: _downloadSelected,
                              ),
                              _RoundGradientButton(
                                size: c(width * 0.13, 46, 52),
                                icon: LucideIcons.trash,
                                onTap: _deleteSelected,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<_MomentGroupData> _buildGroups(List<MomentItem> moments) {
    final now = DateTime.now();
    final recent = <MomentItem>[];
    final byMonth = <String, List<MomentItem>>{};

    for (final moment in moments) {
      if (now.difference(moment.createdAt) < const Duration(hours: 24)) {
        recent.add(moment);
        continue;
      }

      final key = '${moment.createdAt.year}-${moment.createdAt.month}';
      byMonth.putIfAbsent(key, () => <MomentItem>[]).add(moment);
    }

    final result = <_MomentGroupData>[];
    if (recent.isNotEmpty) {
      result.add(_MomentGroupData(title: '24 giờ qua', items: recent));
    }

    for (final entry in byMonth.entries) {
      final month = entry.value.first.createdAt.month;
      result.add(_MomentGroupData(title: 'Tháng $month', items: entry.value));
    }

    return result;
  }

  void _toggleSelectionMode() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selectionOrder.clear();
    });
  }

  void _toggleSelectAll() {
    final ids = widget.repository.myMoments.map((item) => item.id).toList();
    setState(() {
      if (_selectionOrder.length == ids.length) {
        _selectionOrder.clear();
      } else {
        _selectionOrder
          ..clear()
          ..addAll(ids);
      }
    });
  }

  Future<void> _onMomentTap(MomentItem moment) async {
    if (_selectionMode) {
      setState(() {
        if (_selectionOrder.contains(moment.id)) {
          _selectionOrder.remove(moment.id);
        } else {
          _selectionOrder.add(moment.id);
        }
      });
      return;
    }

    final result = await Navigator.of(context).push<MyMomentDetailResult>(
      MaterialPageRoute(
        builder: (_) => MyMomentDetailScreen(
          repository: widget.repository,
          momentId: moment.id,
        ),
      ),
    );

    if (!mounted || result != MyMomentDetailResult.deleted) return;
    GoMateSnackBar.show(
      context,
      message: 'Đã xoá ảnh khoảnh khắc',
      bottomOffset: 16,
    );
  }

  Future<void> _deleteSelected() async {
    if (_selectionOrder.isEmpty) return;
    final count = _selectionOrder.length;

    final confirmed = await GoMateBottomSheet.show<bool>(
      context: context,
      size: GoMateBottomSheetSize.compact,
      child: MomentConfirmContent(
        title: 'Xoá ($count) ảnh khoảnh khắc',
        description: 'Ảnh khoảnh khắc này sẽ bị xoá vĩnh viễn khỏi kho lưu trữ.',
      ),
    );

    if (!mounted || confirmed != true) return;

    widget.repository.deleteMoments(_selectionOrder.toSet());
    setState(() {
      _selectionOrder.clear();
      _selectionMode = false;
    });

    GoMateSnackBar.show(
      context,
      message: 'Đã xoá $count ảnh khoảnh khắc',
      bottomOffset: 16,
    );
  }

  void _downloadSelected() {
    if (_selectionOrder.isEmpty) return;
    final count = _selectionOrder.length;

    GoMateSnackBar.show(
      context,
      message: 'Đã chọn $count ảnh để lưu vào thư viện',
      bottomOffset: 16,
      icon: LucideIcons.download,
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final VoidCallback onTap;

  const _HeaderIcon({
    required this.icon,
    required this.size,
    required this.onTap,
    this.color = AppColors.black,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: size + 18,
        height: size + 18,
        child: Center(
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}

class _MomentGroup extends StatelessWidget {
  final String title;
  final List<MomentItem> items;
  final double width;
  final bool selectionMode;
  final List<String> selectionOrder;
  final Widget? trailing;
  final ValueChanged<MomentItem> onTap;

  const _MomentGroup({
    required this.title,
    required this.items,
    required this.width,
    required this.selectionMode,
    required this.selectionOrder,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    double c(double value, double min, double max) {
      return value.clamp(min, max).toDouble();
    }

    final groupBottom = c(width * 0.043, 14, 18);
    final headerGap = c(width * 0.021, 7, 9);
    final gridGap = c(width * 0.037, 11, 14);

    return Padding(
      padding: EdgeInsets.only(bottom: groupBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: c(width * 0.035, 12.5, 14),
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          SizedBox(height: headerGap),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: gridGap,
              crossAxisSpacing: gridGap,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              final selectedIndex = selectionOrder.indexOf(item.id);

              return LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.maxWidth;
                  final badge = c(size * 0.22, 18, 22);

                  return GestureDetector(
                    onTap: () => onTap(item),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        MomentImageFrame(
                          size: size,
                          imageAsset: item.imageAsset,
                          showShadow: true,
                        ),
                        if (selectionMode)
                          Positioned(
                            right: size * 0.06,
                            top: size * 0.06,
                            child: Container(
                              width: badge,
                              height: badge,
                              decoration: BoxDecoration(
                                color: selectedIndex >= 0
                                    ? AppColors.primaryIcon
                                    : AppColors.grayBorder.withOpacity(0.72),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: selectedIndex >= 0
                                  ? Text(
                                      '${selectedIndex + 1}',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: c(size * 0.10, 8, 10),
                                        height: 1,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RoundGradientButton extends StatelessWidget {
  final double size;
  final IconData icon;
  final VoidCallback onTap;

  const _RoundGradientButton({
    required this.size,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: size * 0.50, color: Colors.white),
      ),
    );
  }
}

class _MomentGroupData {
  final String title;
  final List<MomentItem> items;

  const _MomentGroupData({required this.title, required this.items});
}
