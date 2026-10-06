import '../../../core/services/auth_service.dart';
import '../../../core/network/api_exception.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/navigation/auth_flow.dart';
import '../models/survey_question.dart';
import '../widgets/survey_option_tile.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _sceneController;

  int _currentPage = 0;

  // Dùng List thay vì Set để giữ đúng thứ tự người dùng bấm.
  final Map<int, List<String>> _selectedOptions = {
    0: <String>[],
    1: <String>[],
    2: <String>[],
  };

  final List<SurveyQuestion> _questions = const [
    SurveyQuestion(
      title: 'Bạn thường đi du lịch với mục đích gì?',
      defaultImage: 'assets/images/login_top.png',
      options: [
        'Kết thêm bạn bè ở nhiều nơi',
        'Du lịch nghỉ dưỡng',
        'Check-in địa điểm hot, chụp ảnh',
        'Trải nghiệm, khám phá thiên nhiên',
        'Khám phá văn hóa lịch sử',
        'Khám phá ẩm thực vùng miền',
        'Khác',
      ],
      optionImages: {
        'Kết thêm bạn bè ở nhiều nơi': 'assets/images/ketban.jpg',
        'Du lịch nghỉ dưỡng': 'assets/images/nghiduong.jpg',
        'Check-in địa điểm hot, chụp ảnh': 'assets/images/checkin.jpg',
        'Trải nghiệm, khám phá thiên nhiên': 'assets/images/thiennhien.jpg',
        'Khám phá văn hóa lịch sử': 'assets/images/lichsu.jpg',
        'Khám phá ẩm thực vùng miền': 'assets/images/survey_food.jpg',

        // "Khác" không có ảnh.
      },
    ),

    SurveyQuestion(
      title: 'Bạn thích khám phá những đâu?',
      defaultImage: 'assets/images/login_top.png',
      options: [
        'Biển đảo / Núi rừng',
        'Thành phố / Trung tâm',
        'Địa danh nổi tiếng',
        'Làng nghề văn hóa / Di tích lịch sử',
        'Ngoại ô / Đồng quê',
        'Khác',
      ],
      optionImages: {
        'Biển đảo / Núi rừng': 'assets/images/survey_beach.jpg',
        'Thành phố / Trung tâm': 'assets/images/survey_city.jpg',
        'Địa danh nổi tiếng': 'assets/images/survey_landmark.jpg',
        'Làng nghề văn hóa / Di tích lịch sử':
        'assets/images/survey_culture.jpg',
        'Ngoại ô / Đồng quê': 'assets/images/survey_country.jpg',

        // "Khác" không có ảnh.
      },
    ),

    SurveyQuestion(
      title: 'Bạn muốn GoMate ưu tiên gợi ý những gì?',
      defaultImage: 'assets/images/nen.png',
      options: [
        'Gần tôi',
        'Địa điểm Local',
        'Đang Hot',
        'Dễ đi trong ngày',
        'Có bài review đi kèm',
        'Khác',
      ],
      optionImages: {
        // "Khác" không có ảnh.
      },
    ),
  ];

  @override
  void initState() {
    super.initState();

    _pageController = PageController();

    // Chuyển động camera rất nhẹ để ảnh không bị đứng hoàn toàn.
    _sceneController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _sceneController.dispose();
    super.dispose();
  }

  // ============================================================
  // OPTION
  // ============================================================

  void _toggleOption(int pageIndex, String option) {
    setState(() {
      final selected = _selectedOptions[pageIndex]!;

      if (selected.contains(option)) {
        selected.remove(option);
      } else {
        // add vào cuối để ảnh cũng xuất hiện theo thứ tự người dùng chọn.
        selected.add(option);
      }
    });
  }

  // ============================================================
  // NEXT
  // ============================================================

  Future<void> _nextPage() async {
    if (_currentPage < _questions.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    _goToHome();
  }

  // ============================================================
  // BACK
  // ============================================================

  Future<void> _previousPage() async {
    if (_currentPage == 0) return;

    await _pageController.previousPage(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
    );
  }

  // ============================================================
  // SKIP
  // ============================================================

  void _skip() {
    for (final selected in _selectedOptions.values) {
      selected.clear();
    }
    _goToHome();
  }

  // ============================================================
  // HOME
  // ============================================================

  bool _saving = false;

  bool get _hasAnsweredAllPages {
    for (var page = 0; page < _questions.length; page++) {
      if (_selectedOptions[page]!.isEmpty) {
        return false;
      }
    }
    return true;
  }

  Future<void> _goToHome() async {
    if (_saving) return;

    final skipAll = _selectedOptions.values.every((selected) {
      return selected.isEmpty;
    });

    if (!skipAll && !_hasAnsweredAllPages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn đủ 3 nhóm câu hỏi hoặc bấm Bỏ qua.'),
        ),
      );
      return;
    }

    _saving = true;
    const codes = [
      [
        'KET_BAN',
        'NGHI_DUONG',
        'CHECKIN_HOT',
        'THIEN_NHIEN',
        'VAN_HOA',
        'AM_THUC',
        'MUC_DICH_KHAC',
      ],
      [
        'BIEN_NUI',
        'TRUNG_TAM',
        'DIA_DANH_NOI_TIENG',
        'LANG_NGHE_DI_TICH',
        'NGOAI_O_DONG_QUE',
        'LOAI_KHAC',
      ],
      [
        'GAN_TOI',
        'LOCAL',
        'DANG_HOT',
        'DI_TRONG_NGAY',
        'CO_REVIEW',
        'UU_TIEN_KHAC',
      ],
    ];
    try {
      final selected = <String>[];
      if (!skipAll) {
        for (var page = 0; page < codes.length; page++) {
          final options = _questions[page].options;
          for (final value in _selectedOptions[page]!) {
            final index = options.indexOf(value);
            if (index >= 0) selected.add(codes[page][index]);
          }
        }
      }
      await AuthService.instance.saveOnboarding(selected);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      _saving = false;
      return;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được lựa chọn. Vui lòng thử lại.'),
          ),
        );
      }
      _saving = false;
      return;
    }
    if (!mounted) return;

    AuthFlow.goHomeAfterSurvey(context);
  }

  // ============================================================
  // BUILD - UI/UX ONLY
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final ui = _SurveyUiMetrics.fromWidth(constraints.maxWidth);

            return PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _questions.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return _buildPage(index, ui);
              },
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // PAGE - UI/UX ONLY
  // ============================================================

  Widget _buildPage(int index, _SurveyUiMetrics ui) {
    final question = _questions[index];

    // GIỮ NGUYÊN logic hiện tại:
    // có ít nhất 1 lựa chọn thì nút tiếp tục được bật.
    final hasSelection = _selectedOptions[index]!.isNotEmpty;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        ui.contentPadding,
        ui.pageTopPadding,
        ui.contentPadding,
        ui.pageBottomPadding,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
          MediaQuery.sizeOf(context).height -
              MediaQuery.paddingOf(context).vertical -
              ui.pageTopPadding -
              ui.pageBottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --------------------------------------------------
            // HEADER
            // --------------------------------------------------
            Row(
              children: [
                InkWell(
                  // Không đổi logic back:
                  // page 0 vẫn gọi _previousPage() và method hiện tại tự return.
                  onTap: _previousPage,
                  borderRadius: BorderRadius.circular(ui.headerTapSize / 2),
                  child: SizedBox(
                    width: ui.headerTapSize,
                    height: ui.headerTapSize,
                    child: Center(
                      child: Icon(
                        LucideIcons.chevron_left,
                        size: ui.backIconSize,
                        color: Colors.black,
                        weight: 900,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                GestureDetector(
                  onTap: _saving ? null : _skip,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui.width * 0.01,
                      vertical: ui.width * 0.02,
                    ),
                    child: Text(
                      'Bỏ qua',
                      style: TextStyle(
                        fontSize: ui.skipFontSize,
                        fontWeight: FontWeight.w800,
                        color: AppColors.grayText,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: ui.titleTopGap),

            // --------------------------------------------------
            // TITLE
            // --------------------------------------------------
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ui.width * 0.78,
              ),
              child: Text(
                question.title,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: ui.titleFontSize,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryText,
                  letterSpacing: -0.35,
                ),
              ),
            ),

            SizedBox(height: ui.gridTopGap),

            // --------------------------------------------------
            // OPTION CARDS
            // --------------------------------------------------
            _buildOptionGrid(
              pageIndex: index,
              question: question,
              ui: ui,
            ),

            SizedBox(height: ui.buttonTopGap),

            // --------------------------------------------------
            // CONTINUE
            // --------------------------------------------------
            _SurveyGradientButton(
              height: ui.buttonHeight,
              radius: ui.buttonRadius,
              enabled: hasSelection && !_saving,
              loading: _saving,
              label: index == _questions.length - 1 ? 'Tiếp Tục' : 'Tiếp Tục',
              fontSize: ui.buttonFontSize,
              onTap: _nextPage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionGrid({
    required int pageIndex,
    required SurveyQuestion question,
    required _SurveyUiMetrics ui,
  }) {
    // "Khác" vẫn tồn tại trong _questions và mapping backend để không làm lệch index.
    // UI chỉ ẩn option này theo thiết kế mới.
    final options = question.options
        .where((option) => option != 'Khác')
        .toList(growable: false);

    return Wrap(
      spacing: ui.cardHorizontalGap,
      runSpacing: ui.cardVerticalGap,
      children: options.map((option) {
        final selected = _selectedOptions[pageIndex]!.contains(option);
        final image = question.optionImages[option];

        return SizedBox(
          width: ui.cardWidth,
          child: _SurveyImageOptionCard(
            label: _surveyDisplayLabel(option),
            imagePath: image,
            selected: selected,
            width: ui.cardWidth,
            height: ui.cardHeight,
            imageHeight: ui.cardImageHeight,
            radius: ui.cardRadius,
            fontSize: ui.cardFontSize,
            onTap: () {
              // GIỮ NGUYÊN logic chọn/bỏ chọn hiện tại.
              _toggleOption(pageIndex, option);
            },
          ),
        );
      }).toList(),
    );
  }

  String _surveyDisplayLabel(String option) {
    // Chỉ rút gọn text HIỂN THỊ cho khớp Figma.
    // Giá trị option gốc vẫn được giữ nguyên để mapping backend không thay đổi.
    switch (option) {
      case 'Kết thêm bạn bè ở nhiều nơi':
        return 'Kết bạn mới';
      case 'Du lịch nghỉ dưỡng':
        return 'Nghỉ dưỡng';
      case 'Check-in địa điểm hot, chụp ảnh':
        return 'Checkin địa\nđiểm hot';
      case 'Trải nghiệm, khám phá thiên nhiên':
        return 'Khám phá\nthiên nhiên';
      case 'Khám phá văn hóa lịch sử':
        return 'Khám phá\nvăn hoá, lịch sử';
      case 'Khám phá ẩm thực vùng miền':
        return 'Khám phá\nẩm thực';

      case 'Biển đảo / Núi rừng':
        return 'Núi, biển';
      case 'Thành phố / Trung tâm':
        return 'Thành phố';
      case 'Địa danh nổi tiếng':
        return 'Địa danh\nnổi tiếng';
      case 'Làng nghề văn hóa / Di tích lịch sử':
        return 'Làng nghề, di\ntích lịch sử';
      case 'Ngoại ô / Đồng quê':
        return 'Ngoại ô\nđồng quê';

      case 'Địa điểm Local':
        return 'Địa điểm local';
      case 'Đang Hot':
        return 'Địa điểm hot';
      case 'Dễ đi trong ngày':
        return 'Dễ đi trong ngày';
      case 'Có bài review đi kèm':
        return 'Có bài review';
      case 'Gần tôi':
        return 'Gần tôi';
      case 'Khác':
        return 'Khác';
      default:
        return option;
    }
  }

  // ============================================================
  // GALLERY
  // ============================================================

  Widget _buildImageGallery(int index, SurveyQuestion question) {
    final selected = _selectedOptions[index] ?? <String>[];

    final List<String> selectedImages = [];

    /*
      Duyệt trực tiếp selected để giữ đúng thứ tự bấm.

      Ví dụ:
      người dùng chọn:
      1. Ẩm thực
      2. Check-in
      3. Nghỉ dưỡng

      => gallery:
      [Ẩm thực | Check-in | Nghỉ dưỡng]
    */
    for (final option in selected) {
      final image = question.optionImages[option];

      // "Khác" không có ảnh => không ảnh mới, gallery không đổi.
      if (image == null) {
        continue;
      }

      // Không hiển thị trùng cùng một file ảnh.
      if (!selectedImages.contains(image)) {
        selectedImages.add(image);
      }
    }

    /*
      Không có OPTION CÓ ẢNH nào đang được chọn
      => giữ/quay lại ảnh mặc định.

      Điều này vẫn đúng khi:
      selected = ['Khác']
    */
    final images = selectedImages.isEmpty
        ? [question.defaultImage]
        : selectedImages;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DynamicSurveyGallery(
        images: images,
        sceneController: _sceneController,
      ),
    );
  }

  // ============================================================
  // PROGRESS
  // ============================================================

  Widget _buildProgress(int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_questions.length, (i) {
        final active = i == index;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 7,
          height: 6,
          decoration: BoxDecoration(
            color: active ? AppColors.blue500 : AppColors.blue100,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}


// ============================================================================
// SURVEY FIGMA UI HELPERS
// UI ONLY - không chứa API/backend/business logic.
// ============================================================================

class _SurveyUiMetrics {
  final double width;


  final double contentPadding;
  final double pageTopPadding;
  final double pageBottomPadding;

  final double headerTapSize;
  final double backIconSize;
  final double skipFontSize;

  final double titleTopGap;
  final double titleFontSize;
  final double gridTopGap;

  final double cardHorizontalGap;
  final double cardVerticalGap;
  final double cardWidth;
  final double cardHeight;
  final double cardImageHeight;
  final double cardRadius;
  final double cardFontSize;

  final double buttonTopGap;
  final double buttonHeight;
  final double buttonRadius;
  final double buttonFontSize;

  const _SurveyUiMetrics({
    required this.width,
    required this.contentPadding,
    required this.pageTopPadding,
    required this.pageBottomPadding,
    required this.headerTapSize,
    required this.backIconSize,
    required this.skipFontSize,
    required this.titleTopGap,
    required this.titleFontSize,
    required this.gridTopGap,
    required this.cardHorizontalGap,
    required this.cardVerticalGap,
    required this.cardWidth,
    required this.cardHeight,
    required this.cardImageHeight,
    required this.cardRadius,
    required this.cardFontSize,
    required this.buttonTopGap,
    required this.buttonHeight,
    required this.buttonRadius,
    required this.buttonFontSize,
  });

  factory _SurveyUiMetrics.fromWidth(double width) {
    double c(double value, double min, double max) {
      return value.clamp(min, max).toDouble();
    }

    // Cùng cách responsive với Home:
    // - nền trắng full màn hình
    // - chỉ scale theo width
    // - không dựng frame 375x715 giả
    // - clamp chỉ để tablet không phóng quá lớn
    final contentPadding = c(width * 0.053, 16, 22);
    final gap = c(width * 0.042, 13, 18);

    final availableWidth = width - (contentPadding * 2);
    final cardWidth = (availableWidth - gap) / 2;

    return _SurveyUiMetrics(
      width: width,

      contentPadding: contentPadding,
      pageTopPadding: c(width * 0.025, 8, 12),
      pageBottomPadding: c(width * 0.085, 28, 40),

      headerTapSize: c(width * 0.105, 38, 44),
      backIconSize: c(width * 0.060, 21, 25),
      skipFontSize: c(width * 0.043, 15, 17),

      titleTopGap: c(width * 0.035, 11, 16),
      titleFontSize: c(width * 0.064, 23, 27),
      gridTopGap: c(width * 0.060, 20, 27),

      cardHorizontalGap: gap,
      cardVerticalGap: c(width * 0.043, 14, 19),

      // Figma ~150x140 trên frame tham chiếu, nhưng không fix cứng.
      cardWidth: cardWidth,
      cardHeight: cardWidth * (140 / 150),
      cardImageHeight: cardWidth * (100 / 150),
      cardRadius: c(cardWidth * 0.133, 16, 21),
      cardFontSize: c(width * 0.032, 11.5, 13),

      buttonTopGap: c(width * 0.065, 22, 30),
      buttonHeight: c(width * 0.133, 48, 54),
      buttonRadius: c(width * 0.053, 19, 22),
      buttonFontSize: c(width * 0.043, 15.5, 17),
    );
  }
}

class _SurveyImageOptionCard extends StatelessWidget {
  final String label;
  final String? imagePath;
  final bool selected;

  final double width;
  final double height;
  final double imageHeight;
  final double radius;
  final double fontSize;

  final VoidCallback onTap;

  const _SurveyImageOptionCard({
    required this.label,
    required this.imagePath,
    required this.selected,
    required this.width,
    required this.height,
    required this.imageHeight,
    required this.radius,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected
                  ? AppColors.primaryIcon
                  : Colors.transparent,
              width: selected ? 1.2 : 0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 6,
                offset: const Offset(3, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(radius),
                  topRight: Radius.circular(radius),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: imageHeight,
                  child: _SurveyCardImage(
                    imagePath: imagePath,
                    selected: selected,
                  ),
                ),
              ),

              Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: width * 0.055,
                    ),
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.primaryText
                            : AppColors.grayText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurveyCardImage extends StatelessWidget {
  final String? imagePath;
  final bool selected;

  const _SurveyCardImage({
    required this.imagePath,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final path = imagePath;

    if (path == null || path.isEmpty) {
      return Container(
        color: const Color(0xFFEAF4FD),
        alignment: Alignment.center,
        child: Icon(
          LucideIcons.image,
          size: 30,
          color: AppColors.primaryIcon.withOpacity(0.55),
        ),
      );
    }

    return Image.asset(
      path,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (_, __, ___) {
        return Container(
          color: const Color(0xFFEAF4FD),
          alignment: Alignment.center,
          child: Icon(
            LucideIcons.image,
            size: 30,
            color: AppColors.primaryIcon.withOpacity(0.55),
          ),
        );
      },
    );
  }
}

class _SurveyGradientButton extends StatelessWidget {
  final double height;
  final double radius;
  final bool enabled;
  final bool loading;
  final String label;
  final double fontSize;
  final VoidCallback onTap;

  const _SurveyGradientButton({
    required this.height,
    required this.radius,
    required this.enabled,
    required this.loading,
    required this.label,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: active || loading ? 1 : 0.48,
      child: Container(
        width: double.infinity,
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
              child: loading
                  ? SizedBox(
                width: height * 0.42,
                height: height * 0.42,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.3,
                  color: Colors.white,
                ),
              )
                  : Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
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

// ============================================================================
// DYNAMIC GALLERY
// ============================================================================

class DynamicSurveyGallery extends StatefulWidget {
  final List<String> images;
  final AnimationController sceneController;

  const DynamicSurveyGallery({
    super.key,
    required this.images,
    required this.sceneController,
  });

  @override
  State<DynamicSurveyGallery> createState() => _DynamicSurveyGalleryState();
}

class _DynamicSurveyGalleryState extends State<DynamicSurveyGallery> {
  // Gồm cả những ảnh đang chạy exit animation.
  late List<String> _displayedImages;

  final Set<String> _enteringImages = {};
  final Set<String> _removingImages = {};

  final Map<String, bool> _visible = {};

  /*
    Layout cố ý chậm hơn fade một chút:
    ảnh còn lại có thời gian trượt + giãn mềm để lấp khoảng trống.
  */
  static const Duration _layoutDuration = Duration(milliseconds: 620);

  static const Duration _enterDuration = Duration(milliseconds: 520);

  static const Duration _removeDuration = Duration(milliseconds: 520);

  static const Duration _fadeDuration = Duration(milliseconds: 360);

  @override
  void initState() {
    super.initState();

    _displayedImages = List<String>.from(widget.images);

    for (final image in _displayedImages) {
      _visible[image] = true;
    }
  }

  @override
  void didUpdateWidget(covariant DynamicSurveyGallery oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldImages = oldWidget.images;
    final newImages = widget.images;

    final added = newImages
        .where((image) => !oldImages.contains(image))
        .toList();

    final removed = oldImages
        .where((image) => !newImages.contains(image))
        .toList();

    // ==========================================================
    // ADD
    // ==========================================================
    if (added.isNotEmpty) {
      for (final image in added) {
        final targetIndex = newImages.indexOf(image);

        if (!_displayedImages.contains(image)) {
          /*
            Với lựa chọn mới, widget.images đã giữ đúng thứ tự người dùng bấm.
            Thêm ảnh đúng vào vị trí mục tiêu.
          */
          if (targetIndex >= _displayedImages.length) {
            _displayedImages.add(image);
          } else {
            _displayedImages.insert(targetIndex, image);
          }
        }

        _enteringImages.add(image);
        _visible[image] = false;
      }

      /*
        setState tại đây giúp Flutter dựng frame đầu tiên
        với ảnh mới đang ở ngoài bên phải.
      */
      setState(() {});

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        setState(() {
          for (final image in added) {
            _visible[image] = true;
          }
        });

        Future.delayed(_enterDuration, () {
          if (!mounted) return;

          setState(() {
            _enteringImages.removeAll(added);
          });
        });
      });
    }

    // ==========================================================
    // REMOVE
    // ==========================================================
    if (removed.isNotEmpty) {
      /*
        Không xóa khỏi _displayedImages ngay.

        Ảnh bị bỏ:
        - giữ nguyên vị trí ngang cũ
        - trượt lên
        - fade out

        Ảnh còn lại:
        - ngay lập tức nhận target left/width mới
        - AnimatedPositioned trượt và giãn để lấp chỗ.
      */
      setState(() {
        for (final image in removed) {
          _removingImages.add(image);
          _visible[image] = false;
        }
      });

      Future.delayed(_removeDuration, () {
        if (!mounted) return;

        setState(() {
          for (final image in removed) {
            _displayedImages.remove(image);
            _removingImages.remove(image);
            _enteringImages.remove(image);
            _visible.remove(image);
          }

          _syncDisplayedOrder();
        });
      });
    }

    if (added.isEmpty && removed.isEmpty) {
      _syncDisplayedOrder();
    }
  }

  // ============================================================
  // SYNC ORDER
  // ============================================================

  void _syncDisplayedOrder() {
    /*
      Không reorder ảnh đang exit.
      Chỉ đồng bộ các ảnh active theo widget.images.
    */
    final active = _displayedImages.where(widget.images.contains).toList();

    active.sort(
          (a, b) => widget.images.indexOf(a).compareTo(widget.images.indexOf(b)),
    );

    final removing = _displayedImages.where(_removingImages.contains).toList();

    _displayedImages = [...active, ...removing];
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final activeImages = widget.images;

        final activeCount = activeImages.isEmpty ? 1 : activeImages.length;

        final targetWidth = constraints.maxWidth / activeCount;

        return Container(
          color: AppColors.blue50,
          child: ClipRect(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                for (final image in _displayedImages)
                  _buildImageItem(
                    image: image,
                    activeImages: activeImages,
                    targetWidth: targetWidth,
                    constraints: constraints,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // IMAGE ITEM
  // ============================================================

  Widget _buildImageItem({
    required String image,
    required List<String> activeImages,
    required double targetWidth,
    required BoxConstraints constraints,
  }) {
    final isRemoving = _removingImages.contains(image);

    final isEntering = _enteringImages.contains(image);

    final isVisible = _visible[image] ?? true;

    final isActive = activeImages.contains(image);

    double left;
    double width;

    if (isActive) {
      /*
        Ảnh còn được chọn:
        dùng vị trí và width MỚI.

        Đây chính là phần khiến ảnh còn lại
        vừa trượt ngang vừa giãn lấp chỗ ảnh bị bỏ.
      */
      final activeIndex = activeImages.indexOf(image);

      left = activeIndex * targetWidth;

      width = targetWidth;
    } else {
      /*
        Ảnh bị bỏ chọn:
        giữ nguyên vị trí và kích thước cũ,
        không chạy ngang theo các ảnh còn lại.
      */
      final oldIndex = _displayedImages.indexOf(image);

      final oldCount = _displayedImages.length;

      final oldWidth = constraints.maxWidth / oldCount;

      left = oldIndex * oldWidth;

      width = oldWidth;
    }

    return AnimatedPositioned(
      duration: _layoutDuration,
      curve: Curves.easeInOutCubic,
      left: left,
      top: 0,
      width: width,
      height: constraints.maxHeight,
      child: _buildImageAnimation(
        image: image,
        isRemoving: isRemoving,
        isEntering: isEntering,
        isVisible: isVisible,
      ),
    );
  }

  // ============================================================
  // ENTER / EXIT
  // ============================================================

  Widget _buildImageAnimation({
    required String image,
    required bool isRemoving,
    required bool isEntering,
    required bool isVisible,
  }) {
    // ----------------------------------------------------------
    // REMOVE:
    // chỉ ảnh bị bỏ chọn trượt lên + fade
    // ----------------------------------------------------------
    if (isRemoving) {
      return AnimatedSlide(
        duration: _removeDuration,
        curve: Curves.easeInOutCubic,
        offset: isVisible ? Offset.zero : const Offset(0, -0.78),
        child: AnimatedOpacity(
          duration: _fadeDuration,
          curve: Curves.easeInOut,
          opacity: isVisible ? 1 : 0,
          child: AnimatedScale(
            duration: _removeDuration,
            curve: Curves.easeInOutCubic,
            scale: isVisible ? 1 : 0.97,
            child: _GalleryImage(
              image: image,
              sceneController: widget.sceneController,
            ),
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // ENTER:
    // ảnh mới trượt từ PHẢI -> TRÁI
    // ----------------------------------------------------------
    if (isEntering) {
      return AnimatedSlide(
        duration: _enterDuration,
        curve: Curves.easeOutCubic,
        offset: isVisible ? Offset.zero : const Offset(0.88, 0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 330),
          curve: Curves.easeOut,
          opacity: isVisible ? 1 : 0,
          child: AnimatedScale(
            duration: _enterDuration,
            curve: Curves.easeOutCubic,
            scale: isVisible ? 1 : 0.985,
            child: _GalleryImage(
              image: image,
              sceneController: widget.sceneController,
            ),
          ),
        ),
      );
    }

    /*
      Ảnh bình thường KHÔNG dùng AnimatedSlide.

      Khi ảnh bên cạnh bị bỏ:
      AnimatedPositioned tự:
      - thay đổi left
      - thay đổi width
      => trượt + giãn rất tự nhiên.
    */
    return _GalleryImage(image: image, sceneController: widget.sceneController);
  }
}

// ============================================================================
// IMAGE CELL
// ============================================================================

class _GalleryImage extends StatelessWidget {
  final String image;
  final AnimationController sceneController;

  const _GalleryImage({required this.image, required this.sceneController});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: sceneController,
        builder: (context, child) {
          final value = sceneController.value;

          /*
            Idle rất nhẹ vì gallery đã có nhiều transition.
            Giảm chuyển động giúp tổng thể mượt và ít rối hơn.
          */
          final x = (value - 0.5) * 3;

          final y = math.sin(value * math.pi * 2) * 0.8;

          return Transform.translate(
            offset: Offset(x, y),
            child: Transform.scale(scale: 1.025, child: child),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(image, fit: BoxFit.cover, alignment: Alignment.center),
            Container(color: Colors.white.withOpacity(0.08)),
          ],
        ),
      ),
    );
  }
}
