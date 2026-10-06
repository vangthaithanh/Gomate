import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/google_auth.dart';
import '../../../core/theme/app_colors.dart';
import '../navigation/auth_flow.dart';
import '../services/auth_api.dart';
import '../widgets/auth_text_field.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _backgroundOpacity;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _cardOpacity;
  late final Animation<Offset> _cardMove;

  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleMove;
  late final Animation<double> _emailOpacity;
  late final Animation<Offset> _emailMove;
  late final Animation<double> _passwordOpacity;
  late final Animation<Offset> _passwordMove;
  late final Animation<double> _optionsOpacity;
  late final Animation<Offset> _optionsMove;
  late final Animation<double> _loginButtonOpacity;
  late final Animation<Offset> _loginButtonMove;
  late final Animation<double> _dividerOpacity;
  late final Animation<Offset> _dividerMove;
  late final Animation<double> _googleOpacity;
  late final Animation<Offset> _googleMove;
  late final Animation<double> _registerOpacity;
  late final Animation<Offset> _registerMove;

  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool rememberMe = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  String? _accountError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _backgroundOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.16, curve: Curves.easeOut),
    );

    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.06, 0.24, curve: Curves.easeOut),
    );

    _logoScale =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.82, end: 1.08),
            weight: 60,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.08, end: 0.98),
            weight: 20,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 0.98, end: 1),
            weight: 20,
          ),
        ]).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.06, 0.30, curve: Curves.easeOut),
          ),
        );

    _cardOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.16, 0.30, curve: Curves.easeOut),
    );

    _cardMove = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.16, 0.42, curve: Curves.easeOutCubic),
      ),
    );

    _titleOpacity = _opacity(0.28, 0.40);
    _titleMove = _move(0.28, 0.40);

    _emailOpacity = _opacity(0.37, 0.49);
    _emailMove = _move(0.37, 0.49);

    _passwordOpacity = _opacity(0.46, 0.58);
    _passwordMove = _move(0.46, 0.58);

    _optionsOpacity = _opacity(0.55, 0.67);
    _optionsMove = _move(0.55, 0.67);

    _loginButtonOpacity = _opacity(0.64, 0.76);
    _loginButtonMove = _move(0.64, 0.76);

    _dividerOpacity = _opacity(0.72, 0.82);
    _dividerMove = _move(0.72, 0.82);

    _googleOpacity = _opacity(0.80, 0.91);
    _googleMove = _move(0.80, 0.91);

    _registerOpacity = _opacity(0.88, 1.00);
    _registerMove = _move(0.88, 1.00);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        _controller.forward(from: 0);
      });
    });
  }

  // ============================================================
  // VALIDATION - GIỮ NGUYÊN LOGIC
  // ============================================================

  bool _isEmail(String value) {
    final emailRegex = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    );

    return emailRegex.hasMatch(value);
  }

  bool _isVietnamesePhone(String value) {
    final normalized = value.replaceAll(RegExp(r'[\s.-]'), '');

    final phoneRegex = RegExp(r'^(?:\+84|84|0)(3|5|7|8|9)[0-9]{8}$');

    return phoneRegex.hasMatch(normalized);
  }

  bool _validateLogin() {
    final account = _accountController.text.trim();
    final password = _passwordController.text;

    String? accountError;
    String? passwordError;

    if (account.isEmpty) {
      accountError = 'Vui lòng nhập email.';
    } else if (!_isEmail(account)) {
      accountError = 'Email không đúng định dạng.';
    }

    if (password.isEmpty) {
      passwordError = 'Vui lòng nhập mật khẩu.';
    } else if (password.length < 8) {
      passwordError = 'Mật khẩu phải có ít nhất 8 ký tự.';
    }

    setState(() {
      _accountError = accountError;
      _passwordError = passwordError;
    });

    if (accountError != null || passwordError != null) {
      _showMessage('Vui lòng kiểm tra lại thông tin đăng nhập.');
      return false;
    }

    return true;
  }

  void _clearAccountError(String _) {
    if (_accountError != null) {
      setState(() {
        _accountError = null;
      });
    }
  }

  void _clearPasswordError(String _) {
    if (_passwordError != null) {
      setState(() {
        _passwordError = null;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // LOGIN - GIỮ NGUYÊN BACKEND
  // ============================================================

  Future<void> _login() async {
    if (_isLoading || _isGoogleLoading) return;

    FocusScope.of(context).unfocus();

    if (!_validateLogin()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthApi.login(
        identifier: _accountController.text.trim(),
        password: _passwordController.text,
        remember: rememberMe,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _goAfterAuth();
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Không thể đăng nhập. Vui lòng thử lại.');
    }
  }

  Future<void> _loginWithGoogle() async {
    if (_isLoading || _isGoogleLoading) return;

    setState(() => _isGoogleLoading = true);

    try {
      final token = await GoogleAuth.idToken();

      if (token == null) {
        return;
      }

      await AuthService.instance.google(
        token,
        remember: rememberMe,
      );

      if (mounted) {
        _goAfterAuth();
      }
    } on ApiException catch (e) {
      if (mounted) {
        _showMessage(e.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Không đăng nhập được Google. Kiểm tra cấu hình OAuth và mạng.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  void _goAfterAuth() {
    AuthFlow.goAfterAuth(context);
  }

  void _goToRegister() {
    if (_isLoading || _isGoogleLoading) return;

    FocusScope.of(context).unfocus();

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 480),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const RegisterScreen();
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(
              opacity: curved,
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _goToForgotPassword() {
    if (_isLoading || _isGoogleLoading) return;

    FocusScope.of(context).unfocus();

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(
          milliseconds: 380,
        ),
        reverseTransitionDuration: const Duration(
          milliseconds: 300,
        ),
        pageBuilder: (
            context,
            animation,
            secondaryAnimation,
            ) {
          return const ForgotPasswordScreen();
        },
        transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
            ) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(
              opacity: curved,
              child: child,
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // ANIMATION HELPERS
  // ============================================================

  Animation<double> _opacity(double begin, double end) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(
        begin,
        end,
        curve: Curves.easeOut,
      ),
    );
  }

  Animation<Offset> _move(double begin, double end) {
    return Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          begin,
          end,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  Widget _animatedItem({
    required Animation<double> opacity,
    required Animation<Offset> move,
    required Widget child,
  }) {
    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(
        position: move,
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final ui = _LoginMetrics.fromSize(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          return Stack(
            children: [
              Positioned.fill(
                child: FadeTransition(
                  opacity: _backgroundOpacity,
                  child: Image.asset(
                    'assets/images/nen.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),

              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    SizedBox(
                      height: ui.topAreaHeight,
                      child: Align(
                        alignment: Alignment.center,
                        child: FadeTransition(
                          opacity: _logoOpacity,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: Image.asset(
                              'assets/images/logo_2.png',
                              width: ui.logoSize,
                              height: ui.logoSize,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      child: FadeTransition(
                        opacity: _cardOpacity,
                        child: SlideTransition(
                          position: _cardMove,
                          child: _buildLoginCard(ui),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoginCard(_LoginMetrics ui) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(ui.cardRadius),
          topRight: Radius.circular(ui.cardRadius),
        ),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          ui.horizontalPadding,
          ui.cardTopPadding,
          ui.horizontalPadding,
          ui.bottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _animatedItem(
              opacity: _titleOpacity,
              move: _titleMove,
              child: Text(
                'GoMate xin chào',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ui.titleSize,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryText,
                ),
              ),
            ),

            SizedBox(height: ui.titleToFieldGap),

            _animatedItem(
              opacity: _emailOpacity,
              move: _emailMove,
              child: AuthTextField(
                controller: _accountController,
                hintText: 'Email',
                prefixIcon: LucideIcons.mail,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                errorText: _accountError,
                enabled: !_isLoading && !_isGoogleLoading,
                onChanged: _clearAccountError,
              ),
            ),

            SizedBox(height: ui.fieldGap),

            _animatedItem(
              opacity: _passwordOpacity,
              move: _passwordMove,
              child: AuthTextField(
                controller: _passwordController,
                hintText: 'Mật khẩu',
                prefixIcon: LucideIcons.lock,
                isPassword: true,
                textInputAction: TextInputAction.done,
                errorText: _passwordError,
                enabled: !_isLoading && !_isGoogleLoading,
                onChanged: _clearPasswordError,
              ),
            ),

            SizedBox(height: ui.optionTopGap),

            _animatedItem(
              opacity: _optionsOpacity,
              move: _optionsMove,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: (_isLoading || _isGoogleLoading)
                          ? null
                          : () {
                        setState(() {
                          rememberMe = !rememberMe;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: ui.checkSize,
                            height: ui.checkSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: rememberMe
                                  ? AppColors.primaryIcon
                                  : Colors.white,
                              border: Border.all(
                                color: rememberMe
                                    ? AppColors.primaryIcon
                                    : AppColors.primaryIcon,
                                width: 1.1,
                              ),
                            ),
                            child: rememberMe
                                ? Icon(
                              LucideIcons.check,
                              size: ui.checkSize * 0.62,
                              color: Colors.white,
                            )
                                : null,
                          ),
                          SizedBox(width: ui.optionGap),
                          Flexible(
                            child: Text(
                              'Ghi nhớ đăng nhập',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: ui.optionFontSize,
                                color: AppColors.grayText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  TextButton(
                    onPressed: (_isLoading || _isGoogleLoading)
                        ? null
                        : _goToForgotPassword,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: ui.optionGap,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Quên mật khẩu?',
                      style: TextStyle(
                        fontSize: ui.optionFontSize,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: ui.buttonTopGap),

            _animatedItem(
              opacity: _loginButtonOpacity,
              move: _loginButtonMove,
              child: _GradientAuthButton(
                height: ui.buttonHeight,
                radius: ui.buttonRadius,
                loading: _isLoading,
                enabled: !_isGoogleLoading,
                label: 'Đăng Nhập',
                onTap: _login,
              ),
            ),

            SizedBox(height: ui.dividerTopGap),

            _animatedItem(
              opacity: _dividerOpacity,
              move: _dividerMove,
              child: Row(
                children: [
                  const Expanded(
                    child: Divider(
                      color: AppColors.grayBorder,
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui.dividerTextPadding,
                    ),
                    child: Text(
                      'Hoặc tiếp tục với',
                      style: TextStyle(
                        fontSize: ui.dividerFontSize,
                        color: AppColors.grayText,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Divider(
                      color: AppColors.grayBorder,
                      thickness: 1,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: ui.googleTopGap),

            _animatedItem(
              opacity: _googleOpacity,
              move: _googleMove,
              child: Center(
                child: _GoogleCircleButton(
                  size: ui.googleSize,
                  loading: _isGoogleLoading,
                  enabled: !_isLoading,
                  onTap: _loginWithGoogle,
                ),
              ),
            ),

            SizedBox(height: ui.registerTopGap),

            _animatedItem(
              opacity: _registerOpacity,
              move: _registerMove,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Chưa có tài khoản? ',
                    style: TextStyle(
                      fontSize: ui.footerFontSize,
                      color: AppColors.grayText,
                    ),
                  ),
                  GestureDetector(
                    onTap: (_isLoading || _isGoogleLoading)
                        ? null
                        : _goToRegister,
                    child: Text(
                      'Đăng ký',
                      style: TextStyle(
                        fontSize: ui.footerFontSize,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LOGIN RESPONSIVE METRICS
// ============================================================================

class _LoginMetrics {
  final double topAreaHeight;
  final double logoSize;
  final double cardRadius;
  final double horizontalPadding;
  final double cardTopPadding;
  final double bottomPadding;
  final double titleSize;
  final double titleToFieldGap;
  final double fieldGap;
  final double optionTopGap;
  final double optionGap;
  final double optionFontSize;
  final double checkSize;
  final double buttonTopGap;
  final double buttonHeight;
  final double buttonRadius;
  final double dividerTopGap;
  final double dividerTextPadding;
  final double dividerFontSize;
  final double googleTopGap;
  final double googleSize;
  final double registerTopGap;
  final double footerFontSize;

  const _LoginMetrics({
    required this.topAreaHeight,
    required this.logoSize,
    required this.cardRadius,
    required this.horizontalPadding,
    required this.cardTopPadding,
    required this.bottomPadding,
    required this.titleSize,
    required this.titleToFieldGap,
    required this.fieldGap,
    required this.optionTopGap,
    required this.optionGap,
    required this.optionFontSize,
    required this.checkSize,
    required this.buttonTopGap,
    required this.buttonHeight,
    required this.buttonRadius,
    required this.dividerTopGap,
    required this.dividerTextPadding,
    required this.dividerFontSize,
    required this.googleTopGap,
    required this.googleSize,
    required this.registerTopGap,
    required this.footerFontSize,
  });

  factory _LoginMetrics.fromSize(
      double width,
      double height,
      ) {
    // ============================================================
    // FIGMA REFERENCE: 375 x 715
    // ============================================================
    // Không copy pixel cứng. Mọi kích thước chính được đổi thành
    // tỉ lệ theo WIDTH của thiết bị:
    //
    // card top: 212 / 375 = 0.565
    // logo: 104 / 375 = 0.277
    // form: 295 / 375 = 0.787
    // title: 24 / 375 = 0.064
    // field: 46 / 375 = 0.123
    // button: 50 / 375 = 0.133
    //
    // Máy cao hơn sẽ có thêm khoảng trắng phía dưới card,
    // không kéo giãn các nhóm UI.

    final formWidth = width * 0.787;
    final horizontalPadding = (width - formWidth) / 2;

    return _LoginMetrics(
      // Figma card starts at y=212 on a 375-wide reference.
      topAreaHeight: width * 0.565,

      // 104 / 375.
      logoSize: width * 0.277,

      // Figma card radius 20.
      cardRadius: width * 0.053,

      horizontalPadding: horizontalPadding,

      // Card y=212, title y=246 => 34px.
      cardTopPadding: width * 0.091,

      // Keep bottom flexible; card itself expands to screen bottom.
      bottomPadding: width * 0.055,

      // 24 / 375.
      titleSize: width * 0.064,

      // title top 246 + 29 high -> field top 294 => 19px.
      titleToFieldGap: width * 0.051,

      // email bottom 340 -> password top 359 => 19px.
      fieldGap: width * 0.051,

      // password bottom 405 -> option row top 424 => 19px.
      optionTopGap: width * 0.051,

      optionGap: width * 0.008,

      // Figma 12px.
      optionFontSize: width * 0.032,

      // 15 / 375.
      checkSize: width * 0.040,

      // option row ~18px, button top 461 => ~19px.
      buttonTopGap: width * 0.051,

      // 50 / 375.
      buttonHeight: width * 0.133,

      // Figma radius 20, not a full pill.
      buttonRadius: width * 0.053,

      // button bottom 511 -> divider y550 => 39px.
      dividerTopGap: width * 0.104,

      dividerTextPadding: width * 0.029,

      // 13 / 375.
      dividerFontSize: width * 0.035,

      // divider center around 550; Google circle starts 578.
      googleTopGap: width * 0.050,

      // 50 / 375.
      googleSize: width * 0.133,

      // Google bottom 628 -> footer top 647 => 19px.
      registerTopGap: width * 0.051,

      // 13 / 375.
      footerFontSize: width * 0.035,
    );
  }
}

// ============================================================================
// SHARED LOGIN WIDGETS
// ============================================================================

class _GradientAuthButton extends StatelessWidget {
  final double height;
  final double radius;
  final bool loading;
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  const _GradientAuthButton({
    required this.height,
    required this.radius,
    required this.loading,
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;

    return Opacity(
      opacity: active || loading ? 1 : 0.65,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: active ? AppColors.elevatedShadow : const [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            onTap: active ? onTap : null,
            borderRadius: BorderRadius.circular(radius),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: loading
                    ? SizedBox(
                  key: const ValueKey('login_loading'),
                  width: height * 0.44,
                  height: height * 0.44,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  label,
                  key: const ValueKey('login_label'),
                  style: TextStyle(
                    fontSize: height * 0.32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleCircleButton extends StatelessWidget {
  final double size;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  const _GoogleCircleButton({
    required this.size,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.60,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: enabled && !loading ? onTap : null,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: AppColors.grayBorder,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: loading
                ? SizedBox(
              width: size * 0.42,
              height: size * 0.42,
              child: const CircularProgressIndicator(
                strokeWidth: 2.2,
                color: AppColors.primaryIcon,
              ),
            )
                : Image.asset(
              'assets/images/google_logo.png',
              width: size * 0.54,
              height: size * 0.54,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
