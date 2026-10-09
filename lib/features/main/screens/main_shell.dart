import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../messages/screens/message_screen.dart';
import '../../home/screens/home_screen.dart';
import '../../map/screens/map_screen.dart';
import '../../map/state/map_ui_session.dart';
import '../../profile/screens/profile_screen.dart';
import '../../trip/screens/trip_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    GoMateMapUiSession.requestedMainTab.addListener(
      _handleRequestedTab,
    );

    GoMateMapUiSession.revision.addListener(
      _handleMapUiRevision,
    );
  }

  @override
  void dispose() {
    GoMateMapUiSession.requestedMainTab.removeListener(
      _handleRequestedTab,
    );

    GoMateMapUiSession.revision.removeListener(
      _handleMapUiRevision,
    );

    super.dispose();
  }

  void _handleRequestedTab() {
    final requested =
        GoMateMapUiSession.requestedMainTab.value;

    if (requested == null ||
        requested < 0 ||
        requested > 4) {
      return;
    }

    if (mounted && _currentIndex != requested) {
      _switchTab(requested);
    }

    GoMateMapUiSession.clearRequestedMainTab();
  }

  void _handleMapUiRevision() {
    if (mounted) {
      setState(() {});
    }
  }

  void _switchTab(int index) {
    if (index == _currentIndex) {
      return;
    }

    // Nếu rời Map khi đang có pinned trip,
    // selected trip tạm thời phải quay về pinned trip.
    if (_currentIndex == 2 && index != 2) {
      GoMateMapUiSession.handleLeavingMapTab();
    }

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final bottomSafe = mediaQuery.padding.bottom;

    final metrics = _NavMetrics.fromWidth(
      screenWidth,
      bottomSafe,
    );

    final hideBottomNav =
        _currentIndex == 2 &&
        GoMateMapUiSession.hideMapBottomNav;

    final pages = <Widget>[
      const HomeScreen(),
      const MessageScreen(),
      GoMateMapScreen(
        bottomNavigationInset:
            hideBottomNav ? 0 : metrics.totalHeight + 8,
      ),
      const TripScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      // QUAN TRỌNG:
      // Không dùng background xám nữa.
      backgroundColor: Colors.white,

      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // ============================================================
          // CONTENT FULL BLEED
          //
          // Không left/right margin.
          // Không khung trắng inset.
          // Không shadow ngoài màn hình.
          // ============================================================
          Positioned.fill(
            child: ColoredBox(
              color: Colors.white,
              child: IndexedStack(
                index: _currentIndex,
                children: pages,
              ),
            ),
          ),

          // ============================================================
          // NAVBAR FULL WIDTH
          //
          // Chạy sát 2 mép màn hình.
          // ============================================================
          if (!hideBottomNav)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: metrics.totalHeight,
                child: _BottomNavigationArea(
                  currentIndex: _currentIndex,
                  metrics: metrics,
                  onTap: _switchTab,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// RESPONSIVE NAV METRICS
// ============================================================================

class _NavMetrics {
  final double width;
  final double visualHeight;
  final double totalHeight;
  final double bottomSafe;
  final double barTop;
  final double bubbleSize;
  final double notchMargin;
  final double iconSize;

  const _NavMetrics({
    required this.width,
    required this.visualHeight,
    required this.totalHeight,
    required this.bottomSafe,
    required this.barTop,
    required this.bubbleSize,
    required this.notchMargin,
    required this.iconSize,
  });

  factory _NavMetrics.fromWidth(
      double width,
      double bottomSafe,
      ) {
    double c(
        double value,
        double min,
        double max,
        ) {
      return value.clamp(min, max).toDouble();
    }

    final bubbleSize = c(
      width * 0.118,
      44,
      52,
    );

    final barTop = c(
      bubbleSize * 0.42,
      18,
      22,
    );

    final notchMargin = c(
      bubbleSize * 0.15,
      6,
      8,
    );

    final visualHeight = c(
      width * 0.205,
      76,
      88,
    );

    return _NavMetrics(
      width: width,
      visualHeight: visualHeight,
      totalHeight: visualHeight + bottomSafe,
      bottomSafe: bottomSafe,
      barTop: barTop,
      bubbleSize: bubbleSize,
      notchMargin: notchMargin,
      iconSize: c(
        bubbleSize * 0.47,
        20,
        24,
      ),
    );
  }
}

// ============================================================================
// COMPLETE BOTTOM AREA
// ============================================================================

class _BottomNavigationArea extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final _NavMetrics metrics;

  const _BottomNavigationArea({
    required this.currentIndex,
    required this.onTap,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Phần safe-area dưới cùng luôn trắng.
        if (metrics.bottomSafe > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: metrics.bottomSafe,
            child: const ColoredBox(
              color: Colors.white,
            ),
          ),

        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: metrics.visualHeight,
          child: _GoMateBottomNavBar(
            currentIndex: currentIndex,
            onTap: onTap,
            metrics: metrics,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// BOTTOM NAVIGATION BAR
// ============================================================================

class _GoMateBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final _NavMetrics metrics;

  const _GoMateBottomNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.metrics,
  });

  @override
  State<_GoMateBottomNavBar> createState() =>
      _GoMateBottomNavBarState();
}

class _GoMateBottomNavBarState
    extends State<_GoMateBottomNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  double _fromIndex = 0;
  double _toIndex = 0;

  static const List<IconData> _icons = [
    LucideIcons.house,
    LucideIcons.message_circle,
    LucideIcons.map,
    LucideIcons.calendar,
    LucideIcons.user_round,
  ];

  @override
  void initState() {
    super.initState();

    _fromIndex = widget.currentIndex.toDouble();
    _toIndex = widget.currentIndex.toDouble();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 320,
      ),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(
      covariant _GoMateBottomNavBar oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentIndex != widget.currentIndex) {
      final currentPosition = _animatedIndex(
        _controller.value,
      );

      _fromIndex = currentPosition;
      _toIndex = widget.currentIndex.toDouble();

      _controller.forward(from: 0);
    }
  }

  double _animatedIndex(double value) {
    final curved = Curves.easeOutCubic.transform(
      value,
    );

    return _fromIndex +
        ((_toIndex - _fromIndex) * curved);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = width / _icons.length;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final currentAnimatedIndex =
            _animatedIndex(_controller.value);

            final bubbleCenterX =
                itemWidth * (currentAnimatedIndex + 0.5);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // ========================================================
                // NAVBAR WHITE SHAPE
                //
                // Full-width, no rounded outside corners.
                // Only the moving notch is cut out.
                // ========================================================
                Positioned.fill(
                  child: ClipPath(
                    clipper: _MovingNotchClipper(
                      notchCenterX: bubbleCenterX,
                      barTop: metrics.barTop,
                      bubbleSize: metrics.bubbleSize,
                      notchMargin: metrics.notchMargin,
                    ),
                    child: const ColoredBox(
                      color: Colors.white,
                    ),
                  ),
                ),

                // Shadow nhẹ trên mép navbar như mẫu.
                Positioned(
                  left: 0,
                  right: 0,
                  top: metrics.barTop,
                  child: IgnorePointer(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              0.06,
                            ),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ========================================================
                // NORMAL ICONS
                // ========================================================
                Positioned(
                  left: 0,
                  right: 0,
                  top: metrics.barTop,
                  bottom: 0,
                  child: Row(
                    children: List.generate(
                      _icons.length,
                          (index) {
                        final selected =
                            widget.currentIndex == index;

                        return Expanded(
                          child: InkWell(
                            onTap: () {
                              widget.onTap(index);
                            },
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            child: Center(
                              child: AnimatedOpacity(
                                duration: const Duration(
                                  milliseconds: 120,
                                ),
                                opacity: selected ? 0 : 1,
                                child: Icon(
                                  _icons[index],
                                  size: metrics.iconSize,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ========================================================
                // MOVING ACTIVE BUBBLE
                // ========================================================
                Positioned(
                  left:
                  bubbleCenterX - metrics.bubbleSize / 2,
                  top: 0,
                  child: Container(
                    width: metrics.bubbleSize,
                    height: metrics.bubbleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                        ),
                        BoxShadow(
                          color: const Color(0xFF0B3E8A)
                              .withOpacity(0.12),
                          offset: const Offset(0, 8),
                          blurRadius: 28,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        _icons[widget.currentIndex],
                        size: metrics.iconSize,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// TRANSPARENT MOVING NOTCH
// ============================================================================

class _MovingNotchClipper extends CustomClipper<Path> {
  final double notchCenterX;
  final double barTop;
  final double bubbleSize;
  final double notchMargin;

  const _MovingNotchClipper({
    required this.notchCenterX,
    required this.barTop,
    required this.bubbleSize,
    required this.notchMargin,
  });

  @override
  Path getClip(Size size) {
    // Thanh trắng bắt đầu từ barTop và chạy thẳng đến đáy.
    // Không bo góc ngoài.
    final host = Rect.fromLTRB(
      0,
      barTop,
      size.width,
      size.height,
    );

    // Vùng khoét lớn hơn bubble một chút để tạo khoảng
    // trong suốt bao quanh nút active.
    final guest = Rect.fromCircle(
      center: Offset(
        notchCenterX,
        bubbleSize / 2,
      ),
      radius: (bubbleSize / 2) + notchMargin,
    );

    return const CircularNotchedRectangle()
        .getOuterPath(
      host,
      guest,
    );
  }

  @override
  bool shouldReclip(
      covariant _MovingNotchClipper oldClipper,
      ) {
    return oldClipper.notchCenterX != notchCenterX ||
        oldClipper.barTop != barTop ||
        oldClipper.bubbleSize != bubbleSize ||
        oldClipper.notchMargin != notchMargin;
  }
}
