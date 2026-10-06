import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

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

  final TextEditingController _accountController = TextEditingController();

  final List<TextEditingController> _pinControllers =
  List.generate(4, (_) => TextEditingController());

  final List<FocusNode> _pinFocusNodes =
  List.generate(4, (_) => FocusNode());

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

    for (final node in _pinFocusNodes) {
      node.addListener(_refreshPinFocus);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  void _refreshPinFocus() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _accountController.dispose();

    for (final controller in _pinControllers) {
      controller.dispose();
    }

    for (final node in _pinFocusNodes) {
      node.removeListener(_refreshPinFocus);
      node.dispose();
    }

    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
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

  bool _isValidAccount(String value) {
    return _isEmail(value) || _isVietnamesePhone(value);
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
  // PRIMARY ACTION - GIỮ NGUYÊN FLOW
  // ============================================================

  Future<void> _handlePrimaryAction() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    // STEP 1: ACCOUNT
    if (_step == 0) {
      final account = _accountController.text.trim();

      String? error;

      if (account.isEmpty) {
        error = 'Vui lòng nhập email hoặc số điện thoại.';
      } else if (!_isValidAccount(account)) {
        error = 'Email hoặc số điện thoại không đúng định dạng.';
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
    final password = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    String? passwordError;
    String? confirmError;

    if (password.isEmpty) {
      passwordError = 'Vui lòng nhập mật khẩu mới.';
    } else if (!_isStrongEnoughPassword(password)) {
      passwordError =
      'Mật khẩu cần ít nhất 8 ký tự, gồm chữ và số.';
    }

    if (confirm.isEmpty) {
      confirmError = 'Vui lòng nhập lại mật khẩu mới.';
    } else if (confirm != password) {
      confirmError = 'Mật khẩu nhập lại không trùng khớp.';
    }

    setState(() {
      _newPasswordError = passwordError;
      _confirmPasswordError = confirmError;
    });

    if (passwordError != null || confirmError != null) {
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

    // Không hiển thị form/dialog confirm.
    // ForgotPasswordScreen được push từ Login nên pop() sẽ
    // đưa người dùng quay thẳng về trang đăng nhập.
    Navigator.of(context).pop();
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        // Màn thật phải tràn trắng.
        // Không tạo "frame điện thoại" như Figma.
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final ui = _ForgotMetrics.fromSize(
                constraints.maxWidth,
                constraints.maxHeight,
              );

              return FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _move,
                  child: Column(
                    children: [
                      _ForgotTopBar(
                        title: _titleForStep(),
                        ui: ui,
                        onBack: _isLoading ? null : _goBack,
                      ),

                      Expanded(
                        child: LayoutBuilder(
                          builder: (
                              context,
                              bodyConstraints,
                              ) {
                            return SingleChildScrollView(
                              physics:
                              const BouncingScrollPhysics(),
                              keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior
                                  .onDrag,
                              padding: EdgeInsets.only(
                                bottom: ui.bottomPadding,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight:
                                  bodyConstraints.maxHeight,
                                ),
                                child: Column(
                                  children: [
                                    // Từ Figma:
                                    // helper bắt đầu khoảng 195-207
                                    // trên frame rộng 375.
                                    // Chuyển thành tỉ lệ theo WIDTH,
                                    // không dùng top tuyệt đối.
                                    SizedBox(
                                      height: ui.contentTopGap,
                                    ),

                                    Center(
                                      child: SizedBox(
                                        width: ui.formWidth,
                                        child: AnimatedSwitcher(
                                          duration:
                                          const Duration(
                                            milliseconds: 300,
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
                                              const Offset(
                                                0.05,
                                                0,
                                              ),
                                              end:
                                              Offset.zero,
                                            ).animate(
                                              animation,
                                            );

                                            return FadeTransition(
                                              opacity: animation,
                                              child:
                                              SlideTransition(
                                                position:
                                                slide,
                                                child: child,
                                              ),
                                            );
                                          },
                                          child:
                                          _buildCurrentStep(
                                            ui,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _titleForStep() {
    if (_step == 0) {
      return 'Quên mật khẩu?';
    }

    if (_step == 1) {
      return 'Nhập mã pin';
    }

    return 'Đặt lại mật khẩu';
  }

  Widget _buildCurrentStep(_ForgotMetrics ui) {
    if (_step == 0) {
      return _buildAccountStep(ui);
    }

    if (_step == 1) {
      return _buildPinStep(ui);
    }

    return _buildPasswordStep(ui);
  }

  // ============================================================
  // STEP 1
  // ============================================================

  Widget _buildAccountStep(_ForgotMetrics ui) {
    return Column(
      key: const ValueKey('account_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Nhập email để nhận mã xác thực',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ui.helperFontSize,
            height: 1.30,
            fontWeight: FontWeight.w500,
            color: AppColors.grayText,
          ),
        ),

        SizedBox(height: ui.helperToFieldGap),

        _ForgotField(
          controller: _accountController,
          hintText: 'Email',
          prefixIcon: LucideIcons.mail,
          keyboardType: TextInputType.emailAddress,
          errorText: _accountError,
          enabled: !_isLoading,
          height: ui.fieldHeight,
          radius: ui.fieldRadius,
          fontSize: ui.fieldFontSize,
          iconSize: ui.fieldIconSize,
          onChanged: (_) {
            if (_accountError != null) {
              setState(() {
                _accountError = null;
              });
            }
          },
        ),

        SizedBox(height: ui.fieldToButtonGap),

        _ForgotGradientButton(
          text: 'Gửi mã',
          height: ui.buttonHeight,
          radius: ui.buttonRadius,
          fontSize: ui.buttonFontSize,
          loading: _isLoading,
          onTap: _handlePrimaryAction,
        ),
      ],
    );
  }

  // ============================================================
  // STEP 2
  // ============================================================

  Widget _buildPinStep(_ForgotMetrics ui) {
    return Column(
      key: const ValueKey('pin_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Nhập mã pin bao gồm 4 chữ số\nđược gửi đến email của bạn',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ui.helperFontSize,
            height: 1.28,
            fontWeight: FontWeight.w500,
            color: AppColors.grayText,
          ),
        ),

        SizedBox(height: ui.pinTopGap),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            4,
                (index) {
              final focused = _pinFocusNodes[index].hasFocus;
              final hasError =
                  _pinError != null && _pinError!.isNotEmpty;

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ui.pinGap / 2,
                ),
                child: AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 180,
                  ),
                  width: ui.pinSize,
                  height: ui.pinSize,
                  decoration: BoxDecoration(
                    color: focused
                        ? Colors.white
                        : AppColors.grayBackground,
                    borderRadius: BorderRadius.circular(
                      ui.pinRadius,
                    ),
                    border: (focused || hasError)
                        ? Border.all(
                      color: hasError
                          ? const Color(0xFFE57373)
                          : AppColors.primaryIcon,
                      width: 1.4,
                    )
                        : null,
                    boxShadow: focused && !hasError
                        ? [
                      BoxShadow(
                        color: AppColors.primaryIcon
                            .withOpacity(0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                        : const [],
                  ),
                  child: TextField(
                    controller: _pinControllers[index],
                    focusNode: _pinFocusNodes[index],
                    enabled: !_isLoading,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: TextStyle(
                      fontSize: ui.pinFontSize,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryText,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      if (_pinError != null) {
                        setState(() {
                          _pinError = null;
                        });
                      }

                      if (value.isNotEmpty && index < 3) {
                        _pinFocusNodes[index + 1]
                            .requestFocus();
                      }

                      if (value.isEmpty && index > 0) {
                        _pinFocusNodes[index - 1]
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
          SizedBox(height: ui.errorGap),
          Text(
            _pinError!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ui.errorFontSize,
              color: const Color(0xFFE05A5A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],

        SizedBox(height: ui.pinToButtonGap),

        _ForgotGradientButton(
          text: 'Xác nhận',
          height: ui.buttonHeight,
          radius: ui.buttonRadius,
          fontSize: ui.buttonFontSize,
          loading: _isLoading,
          onTap: _handlePrimaryAction,
        ),

        SizedBox(height: ui.resendTopGap),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Chưa nhận được mã? ',
              style: TextStyle(
                fontSize: ui.resendFontSize,
                color: AppColors.grayText,
              ),
            ),
            GestureDetector(
              onTap: _isLoading ? null : _resendPin,
              child: Text(
                'Gửi lại',
                style: TextStyle(
                  fontSize: ui.resendFontSize,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                  color: _isLoading
                      ? AppColors.grayText.withOpacity(0.45)
                      : AppColors.primaryText,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // STEP 3
  // ============================================================

  Widget _buildPasswordStep(_ForgotMetrics ui) {
    return Column(
      key: const ValueKey('password_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mật khẩu mới cần ít nhất 8 ký tự,\ngồm chữ và số',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: ui.helperFontSize,
            height: 1.28,
            fontWeight: FontWeight.w500,
            color: AppColors.grayText,
          ),
        ),

        SizedBox(height: ui.helperToFieldGap),

        _ForgotField(
          controller: _newPasswordController,
          hintText: 'Mật khẩu',
          prefixIcon: LucideIcons.lock,
          obscureText: _obscureNewPassword,
          errorText: _newPasswordError,
          enabled: !_isLoading,
          height: ui.fieldHeight,
          radius: ui.fieldRadius,
          fontSize: ui.fieldFontSize,
          iconSize: ui.fieldIconSize,
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
                  ? LucideIcons.eye_off
                  : LucideIcons.eye,
              size: ui.fieldIconSize,
              color: AppColors.grayText,
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

        SizedBox(height: ui.passwordFieldGap),

        _ForgotField(
          controller: _confirmPasswordController,
          hintText: 'Nhập lại mật khẩu',
          prefixIcon: LucideIcons.lock,
          obscureText: _obscureConfirmPassword,
          errorText: _confirmPasswordError,
          enabled: !_isLoading,
          height: ui.fieldHeight,
          radius: ui.fieldRadius,
          fontSize: ui.fieldFontSize,
          iconSize: ui.fieldIconSize,
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
                  ? LucideIcons.eye_off
                  : LucideIcons.eye,
              size: ui.fieldIconSize,
              color: AppColors.grayText,
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

        SizedBox(height: ui.fieldToButtonGap),

        _ForgotGradientButton(
          text: 'Đặt lại',
          height: ui.buttonHeight,
          radius: ui.buttonRadius,
          fontSize: ui.buttonFontSize,
          loading: _isLoading,
          onTap: _handlePrimaryAction,
        ),
      ],
    );
  }
}

// ============================================================================
// RESPONSIVE METRICS
// ============================================================================

class _ForgotMetrics {
  final double width;
  final double height;

  final double topBarHeight;
  final double titleFontSize;
  final double backIconSize;
  final double backLeftPadding;

  final double formWidth;
  final double contentTopGap;
  final double bottomPadding;

  final double helperFontSize;
  final double helperToFieldGap;

  final double fieldHeight;
  final double fieldRadius;
  final double fieldFontSize;
  final double fieldIconSize;

  final double passwordFieldGap;
  final double fieldToButtonGap;

  final double buttonHeight;
  final double buttonRadius;
  final double buttonFontSize;

  final double pinTopGap;
  final double pinSize;
  final double pinRadius;
  final double pinGap;
  final double pinFontSize;
  final double pinToButtonGap;

  final double resendTopGap;
  final double resendFontSize;

  final double errorGap;
  final double errorFontSize;

  const _ForgotMetrics({
    required this.width,
    required this.height,
    required this.topBarHeight,
    required this.titleFontSize,
    required this.backIconSize,
    required this.backLeftPadding,
    required this.formWidth,
    required this.contentTopGap,
    required this.bottomPadding,
    required this.helperFontSize,
    required this.helperToFieldGap,
    required this.fieldHeight,
    required this.fieldRadius,
    required this.fieldFontSize,
    required this.fieldIconSize,
    required this.passwordFieldGap,
    required this.fieldToButtonGap,
    required this.buttonHeight,
    required this.buttonRadius,
    required this.buttonFontSize,
    required this.pinTopGap,
    required this.pinSize,
    required this.pinRadius,
    required this.pinGap,
    required this.pinFontSize,
    required this.pinToButtonGap,
    required this.resendTopGap,
    required this.resendFontSize,
    required this.errorGap,
    required this.errorFontSize,
  });

  factory _ForgotMetrics.fromSize(
      double width,
      double height,
      ) {
    // ============================================================
    // TỈ LỆ LẤY TỪ FRAME FIGMA 375 x 715
    // ============================================================
    //
    // Không copy left/top tuyệt đối.
    // Chỉ chuyển các số Figma thành tỉ lệ theo chiều rộng thật.
    //
    // form: 295 / 375 = 0.7867
    // title: 24 / 375 = 0.064
    // helper: 16 / 375 = 0.0427
    // field: 46 / 375 = 0.1227
    // button: 50 / 375 = 0.1333
    // back-left: 33 / 375 = 0.088
    //
    // Nhờ vậy 320 / 360 / 390 / 412 / 430dp đều tự scale.

    return _ForgotMetrics(
      width: width,
      height: height,

      // Header riêng, không nằm trong một panel giả.
      topBarHeight: width * 0.155,

      titleFontSize: width * 0.064,

      // Lucide chevron cần lớn hơn glyph "<" của Figma một chút
      // để có cùng trọng lượng thị giác.
      backIconSize: width * 0.066,

      backLeftPadding: width * 0.072,

      // Figma 295 / 375.
      formWidth: width * 0.787,

      // Figma helper y ~= 195-207.
      // Header đã chiếm ~58px trên frame 375,
      // nên phần gap còn lại vào khoảng 137-149px.
      // Chuyển theo width để máy dài không đẩy form xuống.
      contentTopGap: width * 0.355,

      bottomPadding: width * 0.08,

      // Figma 16px, weight 500.
      helperFontSize: width * 0.043,

      // 248 -> 294 trong Figma, khoảng cách khoảng 16-20px
      // tùy chiều cao dòng helper.
      helperToFieldGap: width * 0.045,

      // Figma 46px.
      fieldHeight: width * 0.123,

      // Figma radius 10px.
      fieldRadius: width * 0.027,

      // Figma 13px.
      fieldFontSize: width * 0.035,

      // Figma icon 20px.
      fieldIconSize: width * 0.053,

      // Reset: top field 244, second field 311.
      // 67 - 46 = 21px.
      passwordFieldGap: width * 0.056,

      // Email field bottom 294 -> button top 317 = 23px.
      fieldToButtonGap: width * 0.061,

      // Figma button 50px.
      buttonHeight: width * 0.133,

      // Figma radius 20px, không phải pill 25px.
      buttonRadius: width * 0.053,

      // Figma 16px.
      buttonFontSize: width * 0.043,

      // PIN helper -> boxes.
      pinTopGap: width * 0.045,

      // Figma 46x46.
      pinSize: width * 0.123,

      pinRadius: width * 0.027,

      // Figma: box x = 61,130,199,268.
      // Mỗi box 46 => gap 23.
      pinGap: width * 0.061,

      pinFontSize: width * 0.052,

      // PIN bottom 293 -> button top 318 = 25.
      pinToButtonGap: width * 0.067,

      // Button bottom 368 -> resend top 393 = 25.
      resendTopGap: width * 0.067,

      // Figma 13px.
      resendFontSize: width * 0.035,

      errorGap: width * 0.014,
      errorFontSize: width * 0.030,
    );
  }
}

// ============================================================================
// TOP BAR
// ============================================================================

class _ForgotTopBar extends StatelessWidget {
  final String title;
  final _ForgotMetrics ui;
  final VoidCallback? onBack;

  const _ForgotTopBar({
    required this.title,
    required this.ui,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ui.topBarHeight,
      child: Stack(
        children: [
          // Title center tuyệt đối theo toàn màn hình.
          Positioned.fill(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ui.width * 0.18,
                ),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: ui.titleFontSize,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ),
          ),

          // Back ở đúng vùng góc trái như Figma,
          // nhưng touch target rộng hơn icon.
          Positioned(
            left: ui.backLeftPadding,
            top: 0,
            bottom: 0,
            child: Center(
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(
                  ui.backIconSize,
                ),
                child: SizedBox(
                  width: ui.backIconSize * 1.65,
                  height: ui.backIconSize * 1.65,
                  child: Center(
                    child: Icon(
                      LucideIcons.chevron_left,
                      size: ui.backIconSize,
                      weight: 800,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FIELD
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

  final double height;
  final double radius;
  final double fontSize;
  final double iconSize;

  const _ForgotField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.height,
    required this.radius,
    required this.fontSize,
    required this.iconSize,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  @override
  State<_ForgotField> createState() => _ForgotFieldState();
}

class _ForgotFieldState extends State<_ForgotField> {
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

    final activeColor = hasError
        ? const Color(0xFFE57373)
        : AppColors.primaryIcon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: widget.height,
          decoration: BoxDecoration(
            color: focused
                ? Colors.white
                : AppColors.grayBackground,
            borderRadius: BorderRadius.circular(
              widget.radius,
            ),
            border: (focused || hasError)
                ? Border.all(
              color: activeColor,
              width: 1.4,
            )
                : null,
            boxShadow: focused && !hasError
                ? [
              BoxShadow(
                color: AppColors.primaryIcon
                    .withOpacity(0.10),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ]
                : const [],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            onChanged: widget.onChanged,
            cursorColor: AppColors.primaryIcon,
            style: TextStyle(
              fontSize: widget.fontSize,
              color: AppColors.black,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                fontSize: widget.fontSize,
                color: AppColors.grayText,
              ),
              prefixIcon: Icon(
                widget.prefixIcon,
                size: widget.iconSize,
                color: hasError
                    ? const Color(0xFFE57373)
                    : focused
                    ? AppColors.primaryIcon
                    : AppColors.grayText,
              ),
              suffixIcon: widget.suffixIcon,
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                vertical: widget.height * 0.31,
              ),
            ),
          ),
        ),

        if (hasError) ...[
          SizedBox(
            height: widget.height * 0.10,
          ),
          Padding(
            padding: EdgeInsets.only(
              left: widget.radius * 0.35,
            ),
            child: Text(
              widget.errorText!,
              style: TextStyle(
                fontSize:
                (widget.fontSize * 0.88).clamp(10.0, 11.5).toDouble(),
                height: 1.25,
                color: const Color(0xFFE05A5A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================================
// GRADIENT BUTTON
// ============================================================================

class _ForgotGradientButton extends StatelessWidget {
  final String text;
  final double height;
  final double radius;
  final double fontSize;
  final bool loading;
  final VoidCallback onTap;

  const _ForgotGradientButton({
    required this.text,
    required this.height,
    required this.radius,
    required this.fontSize,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
              duration: const Duration(
                milliseconds: 200,
              ),
              child: loading
                  ? SizedBox(
                key: const ValueKey('loading'),
                width: height * 0.43,
                height: height * 0.43,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
                  : Text(
                text,
                key: ValueKey(text),
                style: TextStyle(
                  fontSize:
                  (height * 0.30).clamp(13.5, 15.5).toDouble(),
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
