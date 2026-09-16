import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/google_auth.dart';
import '../../../core/theme/app_colors.dart';
import '../navigation/auth_flow.dart';
import '../services/auth_api.dart';
import '../widgets/auth_text_field.dart';
import 'register_screen.dart';

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

    _cardMove = Tween<Offset>(begin: const Offset(0, 0.16), end: Offset.zero)
        .animate(
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
  // VALIDATION
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
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // ============================================================
  // LOGIN
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
      await AuthService.instance.google(token, remember: rememberMe);
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
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    );
  }

  void _goToForgotPassword() {
    _showMessage(
      'Chức năng khôi phục mật khẩu chưa nằm trong phiên bản đăng nhập này.',
    );
  }

  // ============================================================
  // ANIMATION HELPERS
  // ============================================================

  Animation<double> _opacity(double begin, double end) {
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end, curve: Curves.easeOut),
    );
  }

  Animation<Offset> _move(double begin, double end) {
    return Tween<Offset>(
      begin: const Offset(0, 0.16),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
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
      child: SlideTransition(position: move, child: child),
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
      body: Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: _backgroundOpacity,
              child: Image.asset(
                'assets/images/login_background.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),

          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.45),
                    AppColors.blue50.withOpacity(0.45),
                    Colors.white.withOpacity(0.65),
                    Colors.white.withOpacity(0.88),
                  ],
                  stops: const [0.00, 0.35, 0.62, 1.00],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Align(
                  alignment: const Alignment(0, -0.72),
                  child: FadeTransition(
                    opacity: _logoOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.92),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(10),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Align(
                  alignment: Alignment.bottomCenter,
                  child: FadeTransition(
                    opacity: _cardOpacity,
                    child: SlideTransition(
                      position: _cardMove,
                      child: _buildLoginCard(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: screenHeight * 0.62),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue500.withOpacity(0.12),
            blurRadius: 30,
            spreadRadius: 1,
            offset: const Offset(0, -8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _animatedItem(
              opacity: _titleOpacity,
              move: _titleMove,
              child: const Center(
                child: Text(
                  'GoMate xin chào',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            _animatedItem(
              opacity: _emailOpacity,
              move: _emailMove,
              child: AuthTextField(
                controller: _accountController,
                hintText: 'Email',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                errorText: _accountError,
                enabled: !_isLoading && !_isGoogleLoading,
                onChanged: _clearAccountError,
              ),
            ),

            const SizedBox(height: 13),

            _animatedItem(
              opacity: _passwordOpacity,
              move: _passwordMove,
              child: AuthTextField(
                controller: _passwordController,
                hintText: 'Mật khẩu',
                prefixIcon: Icons.lock_outline_rounded,
                isPassword: true,
                textInputAction: TextInputAction.done,
                errorText: _passwordError,
                enabled: !_isLoading && !_isGoogleLoading,
                onChanged: _clearPasswordError,
              ),
            ),

            const SizedBox(height: 6),

            _animatedItem(
              opacity: _optionsOpacity,
              move: _optionsMove,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: (_isLoading || _isGoogleLoading)
                        ? null
                        : () {
                            setState(() {
                              rememberMe = !rememberMe;
                            });
                          },
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: rememberMe
                                ? AppColors.blue500
                                : Colors.white,
                            border: Border.all(
                              color: rememberMe
                                  ? AppColors.blue500
                                  : AppColors.blue200,
                            ),
                          ),
                          child: rememberMe
                              ? const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          'Ghi nhớ đăng nhập',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  TextButton(
                    onPressed: (_isLoading || _isGoogleLoading)
                        ? null
                        : _goToForgotPassword,
                    child: const Text(
                      'Quên mật khẩu?',
                      style: TextStyle(fontSize: 12, color: AppColors.blue500),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            _animatedItem(
              opacity: _loginButtonOpacity,
              move: _loginButtonMove,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: !_isLoading && !_isGoogleLoading
                        ? [
                            BoxShadow(
                              color: AppColors.blue500.withOpacity(0.20),
                              blurRadius: 18,
                              spreadRadius: 1,
                              offset: const Offset(0, 7),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isGoogleLoading) ? null : _login,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.blue500,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.blue500.withOpacity(
                        0.82,
                      ),
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _isLoading
                          ? const SizedBox(
                              key: ValueKey('login_loading'),
                              width: 23,
                              height: 23,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              key: ValueKey('login_text'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Đăng nhập',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 7),
                                Icon(Icons.arrow_forward_rounded, size: 21),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            _animatedItem(
              opacity: _dividerOpacity,
              move: _dividerMove,
              child: Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Hoặc tiếp tục với',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
            ),

            const SizedBox(height: 18),

            _animatedItem(
              opacity: _googleOpacity,
              move: _googleMove,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  child: InkWell(
                    onTap: (_isLoading || _isGoogleLoading)
                        ? null
                        : _loginWithGoogle,
                    borderRadius: BorderRadius.circular(25),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: AppColors.fieldBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.025),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: _isGoogleLoading
                              ? const SizedBox(
                                  key: ValueKey('google_loading'),
                                  width: 23,
                                  height: 23,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: AppColors.blue500,
                                  ),
                                )
                              : Row(
                                  key: const ValueKey('google_content'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      'assets/images/google_logo.png',
                                      width: 21,
                                      height: 21,
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Tiếp tục với Google',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 22),

            _animatedItem(
              opacity: _registerOpacity,
              move: _registerMove,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Chưa có tài khoản? ',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  GestureDetector(
                    onTap: (_isLoading || _isGoogleLoading)
                        ? null
                        : _goToRegister,
                    child: const Text(
                      'Đăng ký',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blue500,
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
