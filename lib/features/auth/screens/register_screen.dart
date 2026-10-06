import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../navigation/auth_flow.dart';
import '../services/auth_api.dart';
import '../widgets/auth_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _backgroundOpacity;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _cardOpacity;
  late final Animation<Offset> _cardMove;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();

  bool _agreeTerms = false;
  bool _isLoading = false;

  String? _nameError;
  String? _accountError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _termsError;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _backgroundOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.20, curve: Curves.easeOut),
    );

    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.04, 0.27, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(
      begin: 0.88,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.04, 0.30, curve: Curves.easeOutBack),
      ),
    );

    _cardOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.16, 0.42, curve: Curves.easeOut),
    );

    _cardMove = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.16, 0.50, curve: Curves.easeOutCubic),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  // ============================================================
  // VALIDATION - GIỮ NGUYÊN LOGIC
  // ============================================================

  bool _isEmail(String value) {
    return RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(value);
  }

  bool _isVietnamesePhone(String value) {
    final normalized = value.replaceAll(RegExp(r'[\s.-]'), '');

    return RegExp(
      r'^(?:\+84|84|0)(3|5|7|8|9)[0-9]{8}$',
    ).hasMatch(normalized);
  }

  bool _isStrongEnoughPassword(String value) {
    return value.length >= 8 &&
        RegExp(r'[A-Za-z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value);
  }

  bool _validateRegister() {
    final name = _nameController.text.trim();
    final account = _accountController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    String? nameError;
    String? accountError;
    String? passwordError;
    String? confirmError;
    String? termsError;

    if (name.length < 3 || name.length > 40) {
      nameError = 'Biệt danh cần từ 3 đến 40 ký tự.';
    }

    if (account.isEmpty) {
      accountError = 'Vui lòng nhập email.';
    } else if (!_isEmail(account)) {
      accountError = 'Email không đúng định dạng.';
    }

    if (password.isEmpty) {
      passwordError = 'Vui lòng nhập mật khẩu.';
    } else if (!_isStrongEnoughPassword(password)) {
      passwordError = 'Mật khẩu cần ít nhất 8 ký tự, gồm chữ và số.';
    }

    if (confirm.isEmpty) {
      confirmError = 'Vui lòng nhập lại mật khẩu.';
    } else if (confirm != password) {
      confirmError = 'Mật khẩu nhập lại không trùng khớp.';
    }

    if (!_agreeTerms) {
      termsError = 'Bạn cần đồng ý Điều khoản sử dụng và Chính sách bảo mật.';
    }

    setState(() {
      _nameError = nameError;
      _accountError = accountError;
      _passwordError = passwordError;
      _confirmPasswordError = confirmError;
      _termsError = termsError;
    });

    final valid =
        nameError == null &&
            accountError == null &&
            passwordError == null &&
            confirmError == null &&
            termsError == null;

    if (!valid) {
      _showMessage('Vui lòng kiểm tra lại thông tin đăng ký.');
    }

    return valid;
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
  // REGISTER - GIỮ NGUYÊN BACKEND
  // ============================================================

  Future<void> _register() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    if (!_validateRegister()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthApi.register(
        identifier: _accountController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Đăng ký thành công.');

      await Future.delayed(
        const Duration(milliseconds: 650),
      );

      if (!mounted) return;

      AuthFlow.goAfterAuth(context);
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

      _showMessage('Không thể đăng ký. Vui lòng thử lại.');
    }
  }

  void _backToLogin() {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
          final ui = _RegisterMetrics.fromSize(
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
                          child: _buildRegisterCard(ui),
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

  Widget _buildRegisterCard(_RegisterMetrics ui) {
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
            Text(
              'Tạo tài khoản',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: ui.titleSize,
                height: 1.08,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryText,
              ),
            ),

            SizedBox(height: ui.titleGap),

            AuthTextField(
              controller: _nameController,
              hintText: 'Biệt danh',
              prefixIcon: LucideIcons.user_round,
              textInputAction: TextInputAction.next,
              errorText: _nameError,
              enabled: !_isLoading,
              onChanged: (_) {
                if (_nameError != null) {
                  setState(() {
                    _nameError = null;
                  });
                }
              },
            ),

            SizedBox(height: ui.fieldGap),

            AuthTextField(
              controller: _accountController,
              hintText: 'Email',
              prefixIcon: LucideIcons.mail,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              errorText: _accountError,
              enabled: !_isLoading,
              onChanged: (_) {
                if (_accountError != null) {
                  setState(() {
                    _accountError = null;
                  });
                }
              },
            ),

            SizedBox(height: ui.passwordHintTopGap),

            Padding(
              padding: EdgeInsets.only(
                left: ui.passwordHintIndent,
              ),
              child: Text(
                'Mật khẩu bao gồm ít nhất 8 ký tự, gồm chữ và số',
                style: TextStyle(
                  fontSize: ui.passwordHintSize,
                  height: 1.15,
                  color: AppColors.grayText,
                ),
              ),
            ),

            SizedBox(height: ui.passwordHintBottomGap),

            AuthTextField(
              controller: _passwordController,
              hintText: 'Mật khẩu',
              prefixIcon: LucideIcons.lock,
              isPassword: true,
              textInputAction: TextInputAction.next,
              errorText: _passwordError,
              enabled: !_isLoading,
              onChanged: (_) {
                if (_passwordError != null ||
                    _confirmPasswordError != null) {
                  setState(() {
                    _passwordError = null;

                    if (_confirmPasswordController.text.isEmpty) {
                      _confirmPasswordError = null;
                    }
                  });
                }
              },
            ),

            SizedBox(height: ui.fieldGap),

            AuthTextField(
              controller: _confirmPasswordController,
              hintText: 'Nhập lại mật khẩu',
              prefixIcon: LucideIcons.lock,
              isPassword: true,
              textInputAction: TextInputAction.done,
              errorText: _confirmPasswordError,
              enabled: !_isLoading,
              onChanged: (_) {
                if (_confirmPasswordError != null) {
                  setState(() {
                    _confirmPasswordError = null;
                  });
                }
              },
            ),

            SizedBox(height: ui.termsTopGap),

            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isLoading
                  ? null
                  : () {
                setState(() {
                  _agreeTerms = !_agreeTerms;
                  _termsError = null;
                });
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.only(top: 1),
                    width: ui.checkSize,
                    height: ui.checkSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _agreeTerms
                          ? AppColors.primaryIcon
                          : Colors.white,
                      border: Border.all(
                        color: _termsError != null
                            ? const Color(0xFFE57373)
                            : AppColors.primaryIcon,
                        width: 1.1,
                      ),
                    ),
                    child: _agreeTerms
                        ? Icon(
                      LucideIcons.check,
                      size: ui.checkSize * 0.62,
                      color: Colors.white,
                    )
                        : null,
                  ),

                  SizedBox(width: ui.termsGap),

                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: ui.termsFontSize,
                          height: 1.35,
                          color: AppColors.grayText,
                        ),
                        children: const [
                          TextSpan(text: 'Tôi đồng ý với '),
                          TextSpan(
                            text: 'điều khoản sử dụng',
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(text: ' và '),
                          TextSpan(
                            text: 'chính sách bảo mật',
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_termsError != null) ...[
              SizedBox(height: ui.errorGap),
              Padding(
                padding: EdgeInsets.only(
                  left: ui.checkSize + ui.termsGap,
                ),
                child: Text(
                  _termsError!,
                  style: TextStyle(
                    fontSize: ui.errorFontSize,
                    color: const Color(0xFFE05A5A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],

            SizedBox(height: ui.buttonTopGap),

            _RegisterGradientButton(
              height: ui.buttonHeight,
              radius: ui.buttonRadius,
              loading: _isLoading,
              onTap: _register,
            ),

            SizedBox(height: ui.footerTopGap),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Đã có tài khoản? ',
                  style: TextStyle(
                    fontSize: ui.footerFontSize,
                    color: AppColors.grayText,
                  ),
                ),
                GestureDetector(
                  onTap: _isLoading ? null : _backToLogin,
                  child: Text(
                    'Đăng nhập',
                    style: TextStyle(
                      fontSize: ui.footerFontSize,
                      fontWeight: FontWeight.w500,
                      color: _isLoading
                          ? AppColors.grayText.withOpacity(0.45)
                          : AppColors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// REGISTER RESPONSIVE METRICS
// ============================================================================

class _RegisterMetrics {
  final double topAreaHeight;
  final double logoSize;
  final double cardRadius;
  final double horizontalPadding;
  final double cardTopPadding;
  final double bottomPadding;
  final double titleSize;
  final double titleGap;
  final double fieldGap;
  final double passwordHintTopGap;
  final double passwordHintBottomGap;
  final double passwordHintIndent;
  final double passwordHintSize;
  final double termsTopGap;
  final double checkSize;
  final double termsGap;
  final double termsFontSize;
  final double errorGap;
  final double errorFontSize;
  final double buttonTopGap;
  final double buttonHeight;
  final double buttonRadius;
  final double footerTopGap;
  final double footerFontSize;

  const _RegisterMetrics({
    required this.topAreaHeight,
    required this.logoSize,
    required this.cardRadius,
    required this.horizontalPadding,
    required this.cardTopPadding,
    required this.bottomPadding,
    required this.titleSize,
    required this.titleGap,
    required this.fieldGap,
    required this.passwordHintTopGap,
    required this.passwordHintBottomGap,
    required this.passwordHintIndent,
    required this.passwordHintSize,
    required this.termsTopGap,
    required this.checkSize,
    required this.termsGap,
    required this.termsFontSize,
    required this.errorGap,
    required this.errorFontSize,
    required this.buttonTopGap,
    required this.buttonHeight,
    required this.buttonRadius,
    required this.footerTopGap,
    required this.footerFontSize,
  });

  factory _RegisterMetrics.fromSize(
      double width,
      double height,
      ) {
    // ============================================================
    // FIGMA REFERENCE: 375 x 715
    // ============================================================
    // Tất cả tỉ lệ theo WIDTH, không dùng chiều cao để kéo giãn.
    //
    // card top: 212 / 375 = 0.565
    // logo: 104 / 375 = 0.277
    // form: 295 / 375 = 0.787
    // title: 24 / 375 = 0.064
    // field: 46 / 375 = 0.123
    // button: 50 / 375 = 0.133

    final formWidth = width * 0.787;
    final horizontalPadding = (width - formWidth) / 2;

    return _RegisterMetrics(
      topAreaHeight: width * 0.565,

      logoSize: width * 0.277,

      cardRadius: width * 0.053,

      horizontalPadding: horizontalPadding,

      // card top 212 -> title top 246 = 34.
      cardTopPadding: width * 0.091,

      bottomPadding: width * 0.050,

      titleSize: width * 0.064,

      // title ~29px high, first field y=291.
      titleGap: width * 0.043,

      // name bottom 337 -> email top 350 = 13.
      fieldGap: width * 0.035,

      // email bottom 396 -> hint y407.
      passwordHintTopGap: width * 0.020,

      // hint ~11px high -> password top 422.
      passwordHintBottomGap: width * 0.011,

      // Figma hint starts x49 while field starts x40.
      passwordHintIndent: width * 0.024,

      // 10 / 375.
      passwordHintSize: width * 0.027,

      // confirm bottom 527 -> terms top about 540.
      termsTopGap: width * 0.035,

      // 15 / 375.
      checkSize: width * 0.040,

      // checkbox x47, text x74 => ~12px after 15px circle.
      termsGap: width * 0.032,

      // 12 / 375.
      termsFontSize: width * 0.032,

      errorGap: width * 0.012,
      errorFontSize: width * 0.028,

      // terms block ~27px; button y588 => about 21px.
      buttonTopGap: width * 0.056,

      buttonHeight: width * 0.133,

      buttonRadius: width * 0.053,

      // button bottom 638 -> footer y651 = 13.
      footerTopGap: width * 0.035,

      footerFontSize: width * 0.035,
    );
  }
}

// ============================================================================
// REGISTER BUTTON
// ============================================================================

class _RegisterGradientButton extends StatelessWidget {
  final double height;
  final double radius;
  final bool loading;
  final VoidCallback onTap;

  const _RegisterGradientButton({
    required this.height,
    required this.radius,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: !loading
            ? AppColors.elevatedShadow
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: loading
                  ? SizedBox(
                key: const ValueKey('register_loading'),
                width: height * 0.44,
                height: height * 0.44,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
                  : Text(
                'Đăng Ký',
                key: const ValueKey('register_label'),
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
    );
  }
}
