import 'package:flutter/material.dart';

/// Kích thước trình bày của phần "vỏ" bottom sheet.
///
/// - compact: nội dung ngắn, chiều cao chạy theo content.
/// - expanded: nội dung dài, có giới hạn chiều cao và cho phép scroll.
///
/// Enum này KHÔNG đại diện cho feature/business type.
enum GoMateBottomSheetSize {
  compact,
  expanded,
}

class GoMateBottomSheet {
  const GoMateBottomSheet._();

  /// Overlay xám theo design GoMate.
  static const Color _defaultBarrierColor = Color(0x99D9D9D9);

  /// Hiển thị bottom sheet dùng chung của GoMate.
  ///
  /// Mặc định:
  /// - Bấm vào vùng xám bên ngoài => đóng popup.
  /// - Vuốt popup xuống => đóng popup.
  ///
  /// Business logic phải nằm ở feature và truyền vào [child]
  /// thông qua callback.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    GoMateBottomSheetSize size = GoMateBottomSheetSize.compact,

    /// Cho phép bấm vùng overlay bên ngoài để đóng.
    bool isDismissible = true,

    /// Cho phép kéo / vuốt xuống để đóng.
    bool enableDrag = true,

    bool useRootNavigator = true,
    bool showDragHandle = true,
    Color barrierColor = _defaultBarrierColor,
    EdgeInsetsGeometry? contentPadding,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();

    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: true,

      // Tap vùng xám bên ngoài để đóng.
      isDismissible: isDismissible,

      // Vuốt xuống để đóng.
      enableDrag: enableDrag,

      backgroundColor: Colors.transparent,
      barrierColor: barrierColor,

      builder: (sheetContext) {
        return _GoMateBottomSheetShell(
          size: size,
          showDragHandle: showDragHandle,
          contentPadding: contentPadding,
          child: child,
        );
      },
    );
  }
}

// ============================================================================
// BOTTOM SHEET SHELL
// ============================================================================

class _GoMateBottomSheetShell extends StatelessWidget {
  final GoMateBottomSheetSize size;
  final bool showDragHandle;
  final EdgeInsetsGeometry? contentPadding;
  final Widget child;

  const _GoMateBottomSheetShell({
    required this.size,
    required this.showDragHandle,
    required this.contentPadding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    final width = media.size.width;
    final screenHeight = media.size.height;
    final keyboardInset = media.viewInsets.bottom;

    double c(
        double value,
        double min,
        double max,
        ) {
      return value.clamp(min, max).toDouble();
    }

    // Không fix chiều cao theo Figma.
    //
    // Compact:
    // - chạy theo content;
    // - chỉ giới hạn tối đa 55% màn hình.
    //
    // Expanded:
    // - dùng cho nội dung dài;
    // - giới hạn tối đa 82% màn hình;
    // - nội dung bên trong có thể scroll.
    final maxHeightFactor = switch (size) {
      GoMateBottomSheetSize.compact => 0.55,
      GoMateBottomSheetSize.expanded => 0.82,
    };

    // ============================================================
    // RESPONSIVE METRICS
    // ============================================================

    final radius = c(
      width * 0.053,
      18,
      22,
    );

    final horizontalPadding = c(
      width * 0.053,
      18,
      22,
    );

    final bottomPadding = c(
      width * 0.050,
      18,
      24,
    );

    final handleWidth = c(
      width * 0.123,
      44,
      48,
    );

    final handleHeight = c(
      width * 0.008,
      3,
      4,
    );

    final handleTopGap = c(
      width * 0.022,
      8,
      10,
    );

    final handleBottomGap = c(
      width * 0.022,
      8,
      10,
    );

    final resolvedPadding =
        contentPadding ??
            EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              bottomPadding,
            );

    // ============================================================
    // QUAN TRỌNG
    //
    // Không dùng LayoutBuilder + Align ở ngoài cùng.
    // Hai widget đó có thể làm child của ModalBottomSheet chiếm toàn bộ
    // chiều cao màn hình. Khi đó vùng xám nhìn thấy được nhưng thực tế
    // vẫn nằm trong vùng hit-test của sheet, nên tap ngoài không đóng.
    //
    // Shell dưới đây chỉ cao đúng bằng popup.
    // Phần còn lại thực sự là modal barrier của Flutter.
    // ============================================================

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        bottom: keyboardInset,
      ),
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: SizedBox(
          width: double.infinity,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenHeight * maxHeightFactor,
            ),
            child: Material(
              color: Colors.white,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(radius),
              topRight: Radius.circular(radius),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ==================================================
                // DRAG HANDLE
                // ==================================================

                if (showDragHandle) ...[
                  SizedBox(
                    height: handleTopGap,
                  ),

                  Container(
                    width: handleWidth,
                    height: handleHeight,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(
                        999,
                      ),
                    ),
                  ),

                  SizedBox(
                    height: handleBottomGap,
                  ),
                ],

                // ==================================================
                // CONTENT
                // ==================================================

                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: resolvedPadding,
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
