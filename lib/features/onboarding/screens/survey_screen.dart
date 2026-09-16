import '../../../core/services/auth_service.dart';
import '../../../core/network/api_exception.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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
        'Kết thêm bạn bè ở nhiều nơi': 'assets/images/survey_friend.jpg',
        'Du lịch nghỉ dưỡng': 'assets/images/survey_resort.jpg',
        'Check-in địa điểm hot, chụp ảnh': 'assets/images/survey_checkin.jpg',
        'Trải nghiệm, khám phá thiên nhiên': 'assets/images/survey_nature.jpg',
        'Khám phá văn hóa lịch sử': 'assets/images/survey_culture.jpg',
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
            'assets/images/survey_history.jpg',
        'Ngoại ô / Đồng quê': 'assets/images/survey_country.jpg',

        // "Khác" không có ảnh.
      },
    ),

    SurveyQuestion(
      title: 'Bạn muốn GoMate ưu tiên gợi ý những gì?',
      defaultImage: 'assets/images/login_top.png',
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
    _goToHome();
  }

  // ============================================================
  // HOME
  // ============================================================

  bool _saving = false;
  Future<void> _goToHome() async {
    if (_saving) return;
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
      for (var page = 0; page < codes.length; page++) {
        final options = _questions[page].options;
        for (final value in _selectedOptions[page]!) {
          final index = options.indexOf(value);
          if (index >= 0) selected.add(codes[page][index]);
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FCFE),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _questions.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          return _buildPage(index);
        },
      ),
    );
  }

  // ============================================================
  // PAGE
  // ============================================================

  Widget _buildPage(int index) {
    final question = _questions[index];

    // Chọn "Khác" vẫn được tính là đã trả lời.
    final hasSelection = _selectedOptions[index]!.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
        child: Column(
          children: [
            // TOP
            Row(
              children: [
                if (index > 0)
                  GestureDetector(
                    onTap: _previousPage,
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 40, height: 40),

                const Spacer(),

                GestureDetector(
                  onTap: _skip,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    child: Text(
                      'Bỏ qua',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // IMAGE
            Expanded(flex: 38, child: _buildImageGallery(index, question)),

            const SizedBox(height: 16),

            // QUESTION
            Text(
              question.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                height: 1.18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 18),

            // OPTIONS
            Expanded(
              flex: 39,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: question.options.map((option) {
                    final selected = _selectedOptions[index]!.contains(option);

                    return SurveyOptionTile(
                      text: option,
                      selected: selected,
                      onTap: () {
                        _toggleOption(index, option);
                      },
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // PROGRESS
            _buildProgress(index),

            const SizedBox(height: 22),

            // NEXT
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: hasSelection
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
                  onPressed: hasSelection ? _nextPage : null,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.blue500,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.blue100.withOpacity(
                      0.70,
                    ),
                    disabledForegroundColor: Colors.white.withOpacity(0.85),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        index == _questions.length - 1
                            ? 'Hoàn tất'
                            : 'Tiếp theo',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 22),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
