import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/snackbar.dart';

/// Lý do báo cáo.
///
/// Chỉ là dữ liệu UI ở bước hiện tại.
/// Khi backend Report được nối sau này, feature/controller sẽ map giá trị này
/// sang request tương ứng. Base bottom sheet không biết backend.
enum ReportReason {
  negativeOrViolence('Nội dung mang tính tiêu cực, bạo lực hoặc công kích'),
  nudityOrInappropriate('Ảnh khoả thân hoặc hoạt động không chuẩn mực'),
  scamOrSpam('Nội dung lừa đảo, gian lận hoặc spam'),
  prohibitedGoods('Kinh doanh hoặc quảng bá mặt hàng vi phạm'),
  falseInformation('Thông tin sai sự thật'),
  intellectualProperty('Vi phạm quyền sở hữu trí tuệ');

  String get code => const [
    'NEGATIVE_OR_VIOLENCE',
    'NUDITY_OR_INAPPROPRIATE',
    'SCAM_OR_SPAM',
    'PROHIBITED_GOODS',
    'FALSE_INFORMATION',
    'INTELLECTUAL_PROPERTY',
  ][index];
  final String label;

  const ReportReason(this.label);
}

class ReportReasonContent extends StatefulWidget {
  final Future<void> Function(ReportReason, String)? onSubmit;
  const ReportReasonContent({super.key, this.onSubmit});
  @override
  State<ReportReasonContent> createState() => _ReportReasonContentState();
}

class _ReportReasonContentState extends State<ReportReasonContent> {
  ReportReason? _selected;
  final _description = TextEditingController();
  bool _busy = false;
  String? _submittedText;
  ReportReason? _submittedReason;
  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _selected == null) return;
    setState(() => _busy = true);
    try {
      _submittedText ??= _description.text;
      _submittedReason ??= _selected;
      await widget.onSubmit!(_submittedReason!, _submittedText!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) GoMateSnackBar.show(context, message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width = screen.width;

    double c(double value, double min, double max) {
      return value.clamp(min, max).toDouble();
    }

    // Khung report được giữ ở một chiều cao ổn định theo màn hình.
    // Khi sau này thêm nhiều option, phần danh sách bên dưới sẽ scroll
    // bên trong khung; sheet không tự cao thêm.
    final contentHeight = c(screen.height * 0.64, 390, 500);

    final titleSize = c(width * 0.043, 15.5, 17);
    final descriptionSize = c(width * 0.027, 10, 11);
    final optionSize = c(width * 0.032, 11.5, 13);
    final chevronSize = c(width * 0.060, 21, 24);

    final titleTopGap = c(width * 0.006, 2, 4);
    final descriptionTopGap = c(width * 0.018, 6, 8);
    final headerBottomGap = c(width * 0.042, 14, 18);

    return SizedBox(
      width: double.infinity,
      height: contentHeight,
      child: Column(
        children: [
          SizedBox(height: titleTopGap),

          Text(
            'Tại sao bạn lại báo cáo?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: titleSize,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),

          SizedBox(height: descriptionTopGap),

          Text(
            'Báo cáo sẽ được ẩn danh với tác giả bài viết.\n'
            'Báo cáo này sẽ được gửi đến quản trị viên',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: descriptionSize,
              height: 1.25,
              fontWeight: FontWeight.w500,
              color: AppColors.grayText,
            ),
          ),

          SizedBox(height: headerBottomGap),

          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: ReportReason.values.length,
              itemBuilder: (context, index) {
                final reason = ReportReason.values[index];

                return _ReportReasonTile(
                  reason: reason,
                  fontSize: optionSize,
                  chevronSize: chevronSize,
                  width: width,
                  onTap: () {
                    if (widget.onSubmit == null) {
                      Navigator.of(context).pop(reason);
                    } else if (!_busy && _submittedReason == null) {
                      setState(() => _selected = reason);
                    }
                  },
                );
              },
            ),
          ),
          if (widget.onSubmit != null && _selected != null) ...[
            Text(
              _selected!.label,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            TextField(
              controller: _description,
              readOnly: _busy || _submittedText != null,
              maxLength: 1000,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Mô tả thêm (không bắt buộc)',
              ),
            ),
            TextButton(
              onPressed: _busy ? null : _send,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Gửi'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportReasonTile extends StatelessWidget {
  final ReportReason reason;
  final double fontSize;
  final double chevronSize;
  final double width;
  final VoidCallback onTap;

  const _ReportReasonTile({
    required this.reason,
    required this.fontSize,
    required this.chevronSize,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    double c(double value, double min, double max) {
      return value.clamp(min, max).toDouble();
    }

    final rowMinHeight = c(width * 0.145, 52, 60);
    final leftPadding = c(width * 0.025, 8, 11);
    final rightPadding = c(width * 0.012, 4, 6);
    final verticalPadding = c(width * 0.020, 7, 9);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: rowMinHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              leftPadding,
              verticalPadding,
              rightPadding,
              verticalPadding,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    reason.label,
                    style: TextStyle(
                      fontSize: fontSize,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black,
                    ),
                  ),
                ),

                SizedBox(width: c(width * 0.020, 7, 9)),

                Icon(
                  LucideIcons.chevron_right,
                  size: chevronSize,
                  color: AppColors.grayText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
