import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _move;

  final TextEditingController _accountController =
  TextEditingController();

  final List<TextEditingController> _pinControllers =
  List.generate(
    4,
        (_) => TextEditingController(),
  );

  final List<FocusNode> _pinFocusNodes =
  List.generate(
    4,
        (_) => FocusNode(),
  );

  final TextEditingController _newPasswordController =
  TextEditingController();

  final TextEditingController _confirmPasswordController =
  TextEditingController();

  int _step = 0;

  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  String? _accountError;
  String? _pinError;
  String? _newPasswordError;
  String? _confirmPasswordError;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _move = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _accountController.dispose();

    for (final controller in _pinControllers) {
      controller.dispose();
    }

    for (final node in _pinFocusNodes) {
      node.dispose();
    }

    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
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
    final normalized =
    value.replaceAll(RegExp(r'[\s.-]'), '');

    return RegExp(
      r'^(?:\+84|84|0)(3|5|7|8|9)[0-9]{8}$',
    ).hasMatch(normalized);
  }

  bool _isValidAccount(String value) {
    return _isEmail(value) ||
        _isVietnamesePhone(value);
  }

  bool _isStrongEnoughPassword(String value) {
    return value.length >= 8 &&
        RegExp(r'[A-Za-z]').hasMatch(value) &&
        RegExp(r'[0-9]').hasMatch(value);
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
  // PRIMARY ACTION
  // ============================================================

  Future<void> _handlePrimaryAction() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    // STEP 1: ACCOUNT
    if (_step == 0) {
      final account =
      _accountController.text.trim();

      String? error;

      if (account.isEmpty) {
        error =
        'Vui lòng nhập email hoặc số điện thoại.';
      } else if (!_isValidAccount(account)) {
        error =
        'Email hoặc số điện thoại không đúng định dạng.';
      }

      setState(() {
        _accountError = error;
      });

      if (error != null) {
        _showMessage(
          'Vui lòng kiểm tra thông tin nhận mã PIN.',
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      // UI demo: sau này thay bằng API gửi PIN.
      await Future.delayed(
        const Duration(milliseconds: 1200),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _pinError = null;
      });

      _goToStep(1);
      return;
    }

    // STEP 2: PIN
    if (_step == 1) {
      final pin = _pinControllers
          .map((controller) => controller.text)
          .join();

      String? error;

      if (pin.length != 4) {
        error = 'Vui lòng nhập đủ 4 số PIN.';
      } else if (!RegExp(r'^[0-9]{4}$').hasMatch(pin)) {
        error = 'Mã PIN chỉ được gồm 4 chữ số.';
      }

      setState(() {
        _pinError = error;
      });

      if (error != null) {
        _showMessage(
          'Mã PIN chưa hợp lệ.',
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      // UI demo: hiện tại coi 4 chữ số hợp lệ là xác minh thành công.
      // Sau này API sẽ kiểm tra PIN thật.
      await Future.delayed(
        const Duration(milliseconds: 1000),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _goToStep(2);
      return;
    }

    // STEP 3: NEW PASSWORD
    final password =
        _newPasswordController.text;
    final confirm =
        _confirmPasswordController.text;

    String? passwordError;
    String? confirmError;

    if (password.isEmpty) {
      passwordError =
      'Vui lòng nhập mật khẩu mới.';
    } else if (!_isStrongEnoughPassword(password)) {
      passwordError =
      'Mật khẩu cần ít nhất 8 ký tự, gồm chữ và số.';
    }

    if (confirm.isEmpty) {
      confirmError =
      'Vui lòng nhập lại mật khẩu mới.';
    } else if (confirm != password) {
      confirmError =
      'Mật khẩu nhập lại không trùng khớp.';
    }

    setState(() {
      _newPasswordError = passwordError;
      _confirmPasswordError = confirmError;
    });

    if (passwordError != null ||
        confirmError != null) {
      _showMessage(
        'Vui lòng kiểm tra lại mật khẩu mới.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(
      const Duration(milliseconds: 1200),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    await _showSuccessDialog();
  }

  // ============================================================
  // STEP
  // ============================================================

  void _goToStep(int step) {
    setState(() {
      _step = step;
    });
  }

  void _goBack() {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    if (_step > 0) {
      setState(() {
        _step -= 1;
      });
      return;
    }

    Navigator.of(context).pop();
  }

  // ============================================================
  // RESEND PIN
  // ============================================================

  Future<void> _resendPin() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _pinError = null;
    });

    await Future.delayed(
      const Duration(milliseconds: 900),
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;

      for (final controller in _pinControllers) {
        controller.clear();
      }
    });

    _pinFocusNodes.first.requestFocus();

    _showMessage(
      'Mã PIN mới đã được gửi.',
    );
  }

  // ============================================================
  // SUCCESS
  // ============================================================

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              24,
              28,
              24,
              24,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.blue500
                      .withOpacity(0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.blue50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 34,
                    color: AppColors.blue500,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Đổi mật khẩu thành công',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bạn có thể sử dụng mật khẩu mới để đăng nhập vào GoMate.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor:
                      AppColors.blue500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Quay lại đăng nhập',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FCFE),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _move,
            child: Column(
              children: [
                _buildTopBar(),

                Expanded(
                  child: SingleChildScrollView(
                    physics:
                    const BouncingScrollPhysics(),
                    padding:
                    const EdgeInsets.fromLTRB(
                      24,
                      18,
                      24,
                      28,
                    ),
                    child: Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 28),

                        // Căn chính giữa toàn bộ 1-2-3.
                        Center(
                          child: _buildStepIndicator(),
                        ),

                        const SizedBox(height: 30),

                        AnimatedSwitcher(
                          duration: const Duration(
                            milliseconds: 340,
                          ),
                          switchInCurve:
                          Curves.easeOutCubic,
                          switchOutCurve:
                          Curves.easeInCubic,
                          transitionBuilder: (
                              child,
                              animation,
                              ) {
                            final slide =
                            Tween<Offset>(
                              begin:
                              const Offset(0.08, 0),
                              end: Offset.zero,
                            ).animate(animation);

                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: slide,
                                child: child,
                              ),
                            );
                          },
                          child:
                          _buildCurrentStep(),
                        ),
                      ],
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

  // ============================================================
  // TOP BAR - KHÔNG CÒN LOGO
  // ============================================================

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        0,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed:
            _isLoading ? null : _goBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 19,
            ),
            color: AppColors.textPrimary,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.blue500
                    .withOpacity(0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            _step == 0
                ? Icons.lock_reset_rounded
                : _step == 1
                ? Icons.pin_outlined
                : Icons.password_rounded,
            size: 34,
            color: AppColors.blue500,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _step == 0
              ? 'Quên mật khẩu?'
              : _step == 1
              ? 'Nhập mã PIN'
              : 'Tạo mật khẩu mới',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 27,
            height: 1.15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 330,
          ),
          child: Text(
            _step == 0
                ? 'Nhập email hoặc số điện thoại đã đăng ký để nhận mã xác minh.'
                : _step == 1
                ? 'Nhập mã PIN gồm 4 chữ số được gửi tới thông tin liên hệ của bạn.'
                : 'Mật khẩu mới cần ít nhất 8 ký tự, gồm chữ và số.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CENTERED STEP INDICATOR
  // ============================================================

  Widget _buildStepIndicator() {
    const connectorWidth = 52.0;

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepCircle(0),

          _buildConnector(
            completed: _step >= 1,
            width: connectorWidth,
          ),

          _buildStepCircle(1),

          _buildConnector(
            completed: _step >= 2,
            width: connectorWidth,
          ),

          _buildStepCircle(2),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int index) {
    final active = index <= _step;

    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 260,
      ),
      curve: Curves.easeOutCubic,

      width: 30,
      height: 30,

      decoration: BoxDecoration(
        shape: BoxShape.circle,

        color: active
            ? AppColors.blue500
            : AppColors.blue50,

        border: Border.all(
          color: active
              ? AppColors.blue500
              : AppColors.blue100,
        ),
      ),

      child: Center(
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,

            color: active
                ? Colors.white
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildConnector({
    required bool completed,
    required double width,
  }) {
    return AnimatedContainer(
      duration: const Duration(
        milliseconds: 260,
      ),
      curve: Curves.easeOutCubic,

      width: width,
      height: 2,

      // Margin đã nằm ngoài width của connector,
      // Row tự tính tổng chiều rộng nên không còn overflow.
      margin: const EdgeInsets.symmetric(
        horizontal: 6,
      ),

      decoration: BoxDecoration(
        color: completed
            ? AppColors.blue500
            : AppColors.blue100,

        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  // ============================================================
  // CURRENT STEP
  // ============================================================

  Widget _buildCurrentStep() {
    if (_step == 0) {
      return _buildAccountStep();
    }

    if (_step == 1) {
      return _buildPinStep();
    }

    return _buildPasswordStep();
  }

  // ============================================================
  // STEP 1
  // ============================================================

  Widget _buildAccountStep() {
    return Container(
      key: const ValueKey('account_step'),
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Email hoặc số điện thoại',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 9),

          _ForgotField(
            controller: _accountController,
            hintText:
            'Nhập email hoặc số điện thoại',
            prefixIcon:
            Icons.mail_outline_rounded,
            keyboardType:
            TextInputType.emailAddress,
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

          const SizedBox(height: 22),

          _buildPrimaryButton(
            text: 'Gửi mã PIN',
            icon:
            Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 2
  // ============================================================

  Widget _buildPinStep() {
    return Container(
      key: const ValueKey('pin_step'),
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: List.generate(
              4,
                  (index) {
                return Padding(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 6,
                  ),
                  child: SizedBox(
                    width: 58,
                    height: 62,
                    child: TextField(
                      controller:
                      _pinControllers[index],
                      focusNode:
                      _pinFocusNodes[index],
                      enabled: !_isLoading,
                      keyboardType:
                      TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      inputFormatters: [
                        FilteringTextInputFormatter
                            .digitsOnly,
                      ],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight:
                        FontWeight.w700,
                        color:
                        AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor:
                        AppColors.fieldBackground,
                        contentPadding:
                        EdgeInsets.zero,
                        enabledBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(
                            16,
                          ),
                          borderSide: BorderSide(
                            color: _pinError != null
                                ? const Color(
                              0xFFE57373,
                            )
                                : AppColors
                                .fieldBorder,
                          ),
                        ),
                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(
                            16,
                          ),
                          borderSide: BorderSide(
                            color: _pinError != null
                                ? const Color(
                              0xFFE57373,
                            )
                                : AppColors
                                .blue500,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        if (_pinError != null) {
                          setState(() {
                            _pinError = null;
                          });
                        }

                        if (value.isNotEmpty &&
                            index < 3) {
                          _pinFocusNodes[
                          index + 1]
                              .requestFocus();
                        }

                        if (value.isEmpty &&
                            index > 0) {
                          _pinFocusNodes[
                          index - 1]
                              .requestFocus();
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          if (_pinError != null) ...[
            const SizedBox(height: 9),
            Text(
              _pinError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFFE05A5A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          const SizedBox(height: 18),

          Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              const Text(
                'Chưa nhận được mã? ',
                style: TextStyle(
                  fontSize: 12.5,
                  color:
                  AppColors.textSecondary,
                ),
              ),
              GestureDetector(
                onTap:
                _isLoading ? null : _resendPin,
                child: Text(
                  'Gửi lại',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _isLoading
                        ? AppColors.textSecondary
                        .withOpacity(0.45)
                        : AppColors.blue500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          _buildPrimaryButton(
            text: 'Xác nhận',
            icon:
            Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 3
  // ============================================================

  Widget _buildPasswordStep() {
    return Container(
      key: const ValueKey('password_step'),
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Mật khẩu mới',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 9),

          _ForgotField(
            controller:
            _newPasswordController,
            hintText: 'Nhập mật khẩu mới',
            prefixIcon:
            Icons.lock_outline_rounded,
            obscureText:
            _obscureNewPassword,
            errorText: _newPasswordError,
            enabled: !_isLoading,
            suffixIcon: IconButton(
              onPressed: _isLoading
                  ? null
                  : () {
                setState(() {
                  _obscureNewPassword =
                  !_obscureNewPassword;
                });
              },
              icon: Icon(
                _obscureNewPassword
                    ? Icons
                    .visibility_off_outlined
                    : Icons
                    .visibility_outlined,
                size: 20,
                color:
                AppColors.textSecondary,
              ),
            ),
            onChanged: (_) {
              if (_newPasswordError != null) {
                setState(() {
                  _newPasswordError = null;
                });
              }
            },
          ),

          const SizedBox(height: 14),

          const Text(
            'Nhập lại mật khẩu',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 9),

          _ForgotField(
            controller:
            _confirmPasswordController,
            hintText:
            'Nhập lại mật khẩu mới',
            prefixIcon:
            Icons.lock_reset_rounded,
            obscureText:
            _obscureConfirmPassword,
            errorText: _confirmPasswordError,
            enabled: !_isLoading,
            suffixIcon: IconButton(
              onPressed: _isLoading
                  ? null
                  : () {
                setState(() {
                  _obscureConfirmPassword =
                  !_obscureConfirmPassword;
                });
              },
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons
                    .visibility_off_outlined
                    : Icons
                    .visibility_outlined,
                size: 20,
                color:
                AppColors.textSecondary,
              ),
            ),
            onChanged: (_) {
              if (_confirmPasswordError != null) {
                setState(() {
                  _confirmPasswordError = null;
                });
              }
            },
          ),

          const SizedBox(height: 22),

          _buildPrimaryButton(
            text: 'Đặt lại mật khẩu',
            icon: Icons.check_rounded,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUTTON
  // ============================================================

  Widget _buildPrimaryButton({
    required String text,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        boxShadow: !_isLoading
            ? [
          BoxShadow(
            color:
            AppColors.blue500
                .withOpacity(0.20),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color:
            Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ]
            : [],
      ),
      child: ElevatedButton(
        onPressed:
        _isLoading ? null : _handlePrimaryAction,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.blue500,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
          AppColors.blue500.withOpacity(0.82),
          disabledForegroundColor:
          Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
        ),
        child: AnimatedSwitcher(
          duration:
          const Duration(milliseconds: 220),
          child: _isLoading
              ? const SizedBox(
            key: ValueKey('loading'),
            width: 23,
            height: 23,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white,
            ),
          )
              : Row(
            key: ValueKey(text),
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                icon,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(
        color:
        AppColors.blue100.withOpacity(0.55),
      ),
      boxShadow: [
        BoxShadow(
          color:
          AppColors.blue500.withOpacity(0.07),
          blurRadius: 26,
          offset: const Offset(0, 9),
        ),
      ],
    );
  }
}

// ============================================================================
// FORGOT FIELD
// ============================================================================

class _ForgotField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool enabled;

  const _ForgotField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  @override
  State<_ForgotField> createState() =>
      _ForgotFieldState();
}

class _ForgotFieldState
    extends State<_ForgotField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode()
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    final hasError =
        widget.errorText != null &&
            widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration:
          const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: focused
                ? [
              BoxShadow(
                color: AppColors.blue300
                    .withOpacity(0.16),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ]
                : [],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            onChanged: widget.onChanged,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
              prefixIcon: Icon(
                widget.prefixIcon,
                size: 20,
                color: hasError
                    ? const Color(0xFFE57373)
                    : focused
                    ? AppColors.blue500
                    : AppColors.textSecondary,
              ),
              suffixIcon: widget.suffixIcon,
              filled: true,
              fillColor: focused
                  ? Colors.white
                  : AppColors.fieldBackground,
              contentPadding:
              const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 17,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: hasError
                      ? const Color(0xFFE57373)
                      : AppColors.fieldBorder,
                  width: hasError ? 1.5 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: hasError
                      ? const Color(0xFFE57373)
                      : AppColors.blue500,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),

        if (hasError) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              widget.errorText!,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.25,
                color: Color(0xFFE05A5A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
