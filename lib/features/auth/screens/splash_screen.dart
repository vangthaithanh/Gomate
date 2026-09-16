import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'session_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _exitController;

  late final Animation<double> _logoScale;

  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;

  late final Animation<double> _sloganOpacity;
  late final Animation<Offset> _sloganSlide;

  late final Animation<Offset> _splashMoveUp;
  late final Animation<double> _textFadeOut;
  late final Animation<double> _splashFadeOut;

  @override
  void initState() {
    super.initState();

    // =========================================================
    // 1. LOGO NẢY
    // =========================================================
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.25,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.25,
          end: 0.88,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.88,
          end: 1.12,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.12,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
    ]).animate(_logoController);

    // =========================================================
    // 2. CHỮ HIỆN CHẬM HƠN
    // =========================================================
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // GoMate hiện trước
    _titleOpacity = CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );

    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _textController,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
          ),
        );

    // Slogan xuất hiện sau một nhịp
    _sloganOpacity = CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.40, 1.0, curve: Curves.easeOut),
    );

    _sloganSlide = Tween<Offset>(begin: const Offset(0, 0.28), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _textController,
            curve: const Interval(0.40, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    // =========================================================
    // 3. THOÁT SPLASH
    // =========================================================
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _splashMoveUp =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.72)).animate(
          CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
        );

    _textFadeOut = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _splashFadeOut = Tween<double>(
      begin: 1,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _exitController, curve: Curves.easeOut));

    _startSplash();
  }

  Future<void> _startSplash() async {
    // Logo nảy
    await _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 150));

    // GoMate + slogan hiện chậm
    await _textController.forward();

    // Giữ toàn màn hình một chút
    await Future.delayed(const Duration(milliseconds: 650));

    // Chuyển sang login
    await _exitController.forward();

    if (!mounted) return;

    _goToLogin();
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 80),
        reverseTransitionDuration: const Duration(milliseconds: 80),

        pageBuilder: (context, animation, secondaryAnimation) {
          return const SessionGate();
        },

        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _exitController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: Stack(
        children: [
          // =====================================================
          // ẢNH NỀN
          // =====================================================
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),

          // =====================================================
          // LỚP PHỦ MỜ TOÀN ẢNH
          // =====================================================
          Positioned.fill(
            child: Container(color: Colors.white.withOpacity(0.30)),
          ),

          // =====================================================
          // VÙNG SÁNG TẬP TRUNG SAU LOGO
          // =====================================================
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.05),
                  radius: 0.90,

                  colors: [
                    Colors.white.withOpacity(0.88),
                    Colors.white.withOpacity(0.58),
                    Colors.white.withOpacity(0.18),
                    Colors.transparent,
                  ],

                  stops: const [0.00, 0.35, 0.72, 1.00],
                ),
              ),
            ),
          ),

          // =====================================================
          // LỚP LOANG XANH NHẸ
          // =====================================================
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,

                  colors: [
                    AppColors.blue50.withOpacity(0.08),
                    AppColors.blue100.withOpacity(0.10),
                    Colors.white.withOpacity(0.16),
                  ],
                ),
              ),
            ),
          ),

          // =====================================================
          // LOGO + TEXT
          // =====================================================
          FadeTransition(
            opacity: _splashFadeOut,

            child: Center(
              child: SlideTransition(
                position: _splashMoveUp,

                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    // ===========================================
                    // LOGO
                    // ===========================================
                    ScaleTransition(
                      scale: _logoScale,

                      child: Container(
                        width: 140,
                        height: 140,

                        padding: const EdgeInsets.all(8),

                        decoration: BoxDecoration(
                          shape: BoxShape.circle,

                          color: Colors.white.withOpacity(0.97),

                          boxShadow: [
                            BoxShadow(
                              color: AppColors.blue500.withOpacity(0.22),
                              blurRadius: 30,
                              spreadRadius: 3,
                              offset: const Offset(0, 9),
                            ),

                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),

                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===========================================
                    // CHỮ
                    // ===========================================
                    FadeTransition(
                      opacity: _textFadeOut,

                      child: Column(
                        children: [
                          // GoMate
                          FadeTransition(
                            opacity: _titleOpacity,

                            child: SlideTransition(
                              position: _titleSlide,

                              child: const Text(
                                'GoMate',

                                style: TextStyle(
                                  fontSize: 29,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,

                                  color: Color(0xFF164F73),

                                  shadows: [
                                    Shadow(color: Colors.white, blurRadius: 10),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 7),

                          // Slogan
                          FadeTransition(
                            opacity: _sloganOpacity,

                            child: SlideTransition(
                              position: _sloganSlide,

                              child: const Text(
                                'Đổng hành trên mọi cung đường',

                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,

                                  color: Color(0xFF47778F),

                                  shadows: [
                                    Shadow(color: Colors.white, blurRadius: 8),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
