import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../explore/screens/explore_screen.dart';
import '../../home/screens/home_screen.dart';
import '../../map/screens/map_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../trip/screens/trip_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    ExploreScreen(),
    MapScreen(),
    TripScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 3, 18, 8),
          child: SizedBox(
            height: 68,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SizedBox(
                    height: 60,
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildNavItem(
                            0,
                            Icons.home_rounded,
                          ),
                        ),
                        Expanded(
                          child: _buildNavItem(
                            1,
                            Icons.explore_outlined,
                          ),
                        ),
                        const SizedBox(width: 58),
                        Expanded(
                          child: _buildNavItem(
                            3,
                            Icons.calendar_month_outlined,
                          ),
                        ),
                        Expanded(
                          child: _buildNavItem(
                            4,
                            Icons.person_outline_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // MAPS - nút nổi trung tâm.
                Positioned(
                  bottom: 12,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentIndex = 2;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.blue500,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.blue500.withOpacity(0.28),
                            blurRadius: 16,
                            spreadRadius: 1,
                            offset: const Offset(0, 5),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.map_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
  ) {
    final active = _currentIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: SizedBox(
        height: 52,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? AppColors.blue50
                  : Colors.transparent,
            ),
            child: Icon(
              icon,
              size: 23,
              color: active
                  ? AppColors.blue500
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
