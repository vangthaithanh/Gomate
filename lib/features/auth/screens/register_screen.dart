import 'package:flutter/material.dart';

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

    _logoScale = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.04, 0.30, curve: Curves.easeOutBack),
      ),
    );

    _cardOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.16, 0.42, curve: Curves.easeOut),
    );

    _cardMove = Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero)
        .animate(
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
  // VALIDATION
  // ============================================================

  bool _isEmail(String value) {
    return RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(value);
  }

  bool _isVietnamesePhone(String value) {
    final normalized = value.replaceAll(RegExp(r'[\s.-]'), '');

    return RegExp(r'^(?:\+84|84|0)(3|5|7|8|9)[0-9]{8}$').hasMatch(normalized);
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
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // ============================================================
  // REGISTER
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

      await Future.delayed(const Duration(milliseconds: 650));

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
                    Colors.white.withOpacity(0.67),
                    Colors.white.withOpacity(0.90),
                  ],
                  stops: const [0.00, 0.33, 0.60, 1.00],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned(
                  top: 8,
                  left: 12,
                  child: IconButton(
                    onPressed: _isLoading ? null : _backToLogin,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 19,
                    ),
                    color: AppColors.textPrimary,
                    disabledColor: AppColors.textSecondary.withOpacity(0.45),
                  ),
                ),

                Align(
                  alignment: const Alignment(0, -0.77),
                  child: FadeTransition(
                    opacity: _logoOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: 84,
                        height: 84,
                        padding: const EdgeInsets.all(9),
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
                      child: _buildRegisterCard(),
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

  Widget _buildRegisterCard() {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: screenHeight * 0.70),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
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
            const Center(
              child: Column(
                children: [
                  Text(
                    'Tạo tài khoản',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Bắt đầu hành trình của bạn cùng GoMate',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 21),

            AuthTextField(
              controller: _nameController,
              hintText: 'Biệt danh',
              prefixIcon: Icons.person_outline_rounded,
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

            const SizedBox(height: 12),

            AuthTextField(
              controller: _accountController,
              hintText: 'Email',
              prefixIcon: Icons.mail_outline_rounded,
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

            const SizedBox(height: 12),

            AuthTextField(
              controller: _passwordController,
              hintText: 'Mật khẩu',
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.next,
              errorText: _passwordError,
              enabled: !_isLoading,
              onChanged: (_) {
                if (_passwordError != null || _confirmPasswordError != null) {
                  setState(() {
                    _passwordError = null;

                    if (_confirmPasswordController.text.isEmpty) {
                      _confirmPasswordError = null;
                    }
                  });
                }
              },
            ),

            const SizedBox(height: 12),

            AuthTextField(
              controller: _confirmPasswordController,
              hintText: 'Nhập lại mật khẩu',
              prefixIcon: Icons.lock_reset_rounded,
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

            const SizedBox(height: 13),

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
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _agreeTerms ? AppColors.blue500 : Colors.white,
                      border: Border.all(
                        color: _termsError != null
                            ? const Color(0xFFE57373)
                            : _agreeTerms
                            ? AppColors.blue500
                            : AppColors.blue200,
                      ),
                    ),
                    child: _agreeTerms
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          TextSpan(text: 'Tôi đồng ý với '),
                          TextSpan(
                            text: 'Điều khoản sử dụng',
                            style: TextStyle(
                              color: AppColors.blue500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(text: ' và '),
                          TextSpan(
                            text: 'Chính sách bảo mật',
                            style: TextStyle(
                              color: AppColors.blue500,
                              fontWeight: FontWeight.w600,
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
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 27),
                child: Text(
                  _termsError!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFE05A5A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: !_isLoading
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
                  /*
                    Cho phép bấm dù chưa tích điều khoản
                    để validation có thể thông báo rõ lỗi.
                  */
                  onPressed: _isLoading ? null : _register,
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
                            key: ValueKey('register_loading'),
                            width: 23,
                            height: 23,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            key: ValueKey('register_text'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Đăng ký',
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

            const SizedBox(height: 22),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Đã có tài khoản? ',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                GestureDetector(
                  onTap: _isLoading ? null : _backToLogin,
                  child: Text(
                    'Đăng nhập',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isLoading
                          ? AppColors.textSecondary.withOpacity(0.45)
                          : AppColors.blue500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
