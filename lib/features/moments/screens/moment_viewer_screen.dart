import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/gomate_emoji.dart';
import '../../../core/widgets/snackbar.dart';
import '../../home/widgets/report_reason_content.dart';
import '../data/moments_repository.dart';
import '../models/moment_models.dart';
import '../widgets/moment_components.dart';
import '../widgets/moment_image_frame.dart';
import 'moment_camera_screen.dart';
import 'my_moments_screen.dart';

class MomentViewerScreen extends StatefulWidget {
  final MomentsRepository repository;
  final String startUserId;

  const MomentViewerScreen({
    super.key,
    required this.repository,
    required this.startUserId,
  });

  @override
  State<MomentViewerScreen> createState() => _MomentViewerScreenState();
}

class _MomentViewerScreenState extends State<MomentViewerScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocus = FocusNode();

  late List<MomentItem> _queue;
  int _index = 0;

  MomentItem get _current => _queue[_index];

  @override
  void initState() {
    super.initState();
    _queue = widget.repository.availableQueue(startUserId: widget.startUserId);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _queue.isNotEmpty) {
        widget.repository.markViewed(_current.id);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) {
      return const Scaffold(backgroundColor: Colors.white);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            double c(double value, double min, double max) {
              return value.clamp(min, max).toDouble();
            }

            final horizontalPadding = c(width * 0.053, 16, 22);
            final headerHeight = c(width * 0.155, 54, 66);
            final headerIconSize = c(width * 0.064, 22, 25);
            final bodyHeight = math.max(0.0, height - headerHeight);

            final authorHeight = c(width * 0.13, 46, 54);
            final reactionHeight = c(width * 0.112, 40, 44);
            final composerHeight = c(width * 0.123, 44, 48);
            final minimumGaps = c(height * 0.13, 72, 104);

            final maxImageByHeight = math.max(
              150.0,
              bodyHeight -
                  authorHeight -
                  reactionHeight -
                  composerHeight -
                  minimumGaps,
            );
            final imageSize = math.min(width * 0.80, maxImageByHeight);

            final moment = _current;
            final next = _index < _queue.length - 1 ? _queue[_index + 1] : null;

            return Column(
              children: [
                _ViewerHeader(
                  height: headerHeight,
                  horizontalPadding: horizontalPadding,
                  iconSize: headerIconSize,
                  moment: moment,
                  onClose: () => Navigator.of(context).pop(),
                  onLibrary: _openLibrary,
                  onCamera: _openCamera,
                ),

                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Column(
                      children: [
                        // Khoảng cách header -> ảnh bám theo chiều rộng thật của máy.
                        // Không dùng Spacer ở đây vì màn hình cao sẽ đẩy ảnh tụt xuống.
                        SizedBox(height: c(width * 0.13, 44, 52)),

                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _nextMoment,
                          child: _MomentMediaStack(
                            moment: moment,
                            nextMoment: next,
                            size: imageSize,
                            offset: c(imageSize * 0.02, 4, 7),
                          ),
                        ),

                        SizedBox(height: c(width * 0.035, 12, 16)),

                        SizedBox(
                          height: authorHeight,
                          child: _AuthorRow(
                            moment: moment,
                            width: width,
                            onMore: _openMore,
                          ),
                        ),

                        const Spacer(),

                        SizedBox(
                          width: math.min(width * 0.51, 210),
                          height: reactionHeight,
                          child: _ReactionBar(
                            width: width,
                            emojis: widget.repository.frequentReactions,
                            onReact: _react,
                            onMore: _openEmojiPicker,
                          ),
                        ),

                        const Spacer(),

                        SizedBox(
                          width: math.min(width * 0.82, 360),
                          height: composerHeight,
                          child: _MessageComposer(
                            width: width,
                            controller: _messageController,
                            focusNode: _messageFocus,
                            receiverName: moment.ownerName,
                            onSend: _sendMessage,
                          ),
                        ),

                        SizedBox(height: c(height * 0.035, 14, 26)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _nextMoment() async {
    HapticFeedback.selectionClick();

    if (_index >= _queue.length - 1) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _index += 1;
      _messageController.clear();
      _messageFocus.unfocus();
    });

    widget.repository.markViewed(_current.id);
  }

  Future<void> _openMore() async {
    final result = await GoMateBottomSheet.show<MomentViewerActionResult>(
      context: context,
      size: GoMateBottomSheetSize.compact,
      child: const MomentViewerActionContent(),
    );

    if (!mounted || result == null) return;

    switch (result) {
      case MomentViewerActionResult.mute:
        await _confirmMute();
        break;
      case MomentViewerActionResult.report:
        await _reportMoment();
        break;
    }
  }

  Future<void> _confirmMute() async {
    final owner = _current;
    final confirmed = await GoMateBottomSheet.show<bool>(
      context: context,
      size: GoMateBottomSheetSize.compact,
      child: MomentConfirmContent(
        title: 'Tắt ảnh khoảnh khắc của ${owner.ownerName}?',
        description: 'Bạn sẽ không thể xem ảnh khoảnh khắc do người này chia sẻ.',
        secondaryDescription:
            'Bạn có thể bật lại khoảnh khắc từ trang cá nhân của họ.',
      ),
    );

    if (!mounted || confirmed != true) return;

    widget.repository.muteUser(owner.ownerId);

    GoMateSnackBar.show(
      context,
      message: 'Đã ẩn ảnh khoảnh khắc của ${owner.ownerName}',
      bottomOffset: 16,
    );

    final remaining = widget.repository.availableQueue(
      startUserId: owner.ownerId,
    );

    if (remaining.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (mounted) Navigator.of(context).pop();
      return;
    }

    setState(() {
      _queue = remaining;
      _index = 0;
    });
    widget.repository.markViewed(_current.id);
  }

  Future<void> _reportMoment() async {
    final reason = await GoMateBottomSheet.show<ReportReason>(
      context: context,
      size: GoMateBottomSheetSize.expanded,
      child: const ReportReasonContent(),
    );

    if (!mounted || reason == null) return;

    GoMateSnackBar.show(
      context,
      message: 'Cảm ơn bạn đã đóng góp ý kiến',
      bottomOffset: 16,
      actionLabel: 'Xem báo cáo',
      onAction: () {},
    );
  }

  void _react(GoMateEmojiType emoji) {
    HapticFeedback.lightImpact();
    widget.repository.reactToMoment(_current.id, emoji);
  }

  Future<void> _openEmojiPicker() async {
    final emoji = await GoMateBottomSheet.show<GoMateEmojiType>(
      context: context,
      size: GoMateBottomSheetSize.compact,
      child: const MomentEmojiPickerContent(),
    );

    if (emoji != null) _react(emoji);
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final receiver = _current;
    await widget.repository.sendMessage(
      receiverUserId: receiver.ownerId,
      message: message,
    );

    if (!mounted) return;
    _messageController.clear();
    _messageFocus.unfocus();

    GoMateSnackBar.show(
      context,
      message: 'Đã gửi tin nhắn cho ${receiver.ownerName}',
      bottomOffset: 16,
    );
    setState(() {});
  }

  Future<void> _openLibrary() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyMomentsScreen(repository: widget.repository),
      ),
    );
  }

  Future<void> _openCamera() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MomentCameraScreen(repository: widget.repository),
      ),
    );
  }
}

class _ViewerHeader extends StatelessWidget {
  final double height;
  final double horizontalPadding;
  final double iconSize;
  final MomentItem moment;
  final VoidCallback onClose;
  final VoidCallback onLibrary;
  final VoidCallback onCamera;

  const _ViewerHeader({
    required this.height,
    required this.horizontalPadding,
    required this.iconSize,
    required this.moment,
    required this.onClose,
    required this.onLibrary,
    required this.onCamera,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final locationFont = (width * 0.032).clamp(11.0, 12.5).toDouble();
    final locationThumb = (width * 0.08).clamp(28.0, 32.0).toDouble();

    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: horizontalPadding),
              child: _HeaderIcon(
                icon: LucideIcons.x,
                size: iconSize,
                onTap: onClose,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.25),
            child: moment.locationText == null
                ? Text(
                    'Không tìm thấy vị trí',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.grayText,
                      fontSize: locationFont,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(locationThumb * 0.26),
                        child: Image.asset(
                          moment.imageAsset,
                          width: locationThumb,
                          height: locationThumb,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(width: width * 0.02),
                      Flexible(
                        child: Text(
                          moment.locationText!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontSize: locationFont,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: horizontalPadding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeaderIcon(
                    icon: LucideIcons.layout_grid,
                    size: iconSize,
                    onTap: onLibrary,
                  ),
                  SizedBox(width: width * 0.015),
                  _HeaderIcon(
                    icon: LucideIcons.camera,
                    size: iconSize,
                    onTap: onCamera,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _HeaderIcon({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: size + 18,
        height: size + 18,
        child: Center(
          child: Icon(icon, size: size, color: AppColors.black),
        ),
      ),
    );
  }
}

class _MomentMediaStack extends StatelessWidget {
  final MomentItem moment;
  final MomentItem? nextMoment;
  final double size;
  final double offset;

  const _MomentMediaStack({
    required this.moment,
    required this.nextMoment,
    required this.size,
    required this.offset,
  });

  @override
  Widget build(BuildContext context) {
    final hasNext = nextMoment != null;

    return SizedBox(
      width: size + (hasNext ? offset : 0),
      height: size + (hasNext ? offset : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (hasNext)
            Positioned(
              left: offset,
              top: offset * 0.45,
              child: Transform.rotate(
                angle: 0.025,
                child: MomentImageFrame(
                  size: size,
                  imageAsset: nextMoment!.imageAsset,
                  opacity: 0.96,
                ),
              ),
            ),
          Positioned(
            left: 0,
            top: 0,
            child: Transform.rotate(
              angle: hasNext ? -0.018 : 0,
              child: MomentImageFrame(
                size: size,
                imageAsset: moment.imageAsset,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  final MomentItem moment;
  final double width;
  final VoidCallback onMore;

  const _AuthorRow({
    required this.moment,
    required this.width,
    required this.onMore,
  });

  String _relativeTime() {
    final diff = DateTime.now().difference(moment.createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)} phút';
    if (diff.inHours < 24) return '${diff.inHours} giờ';
    return '${diff.inDays} ngày';
  }

  @override
  Widget build(BuildContext context) {
    double c(double value, double min, double max) {
      return value.clamp(min, max).toDouble();
    }

    final avatar = c(width * 0.096, 34, 38);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: avatar,
          height: avatar,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.blue50,
            border: Border.all(color: AppColors.grayBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(moment.ownerAvatarAsset, fit: BoxFit.cover),
        ),
        SizedBox(width: c(width * 0.025, 8, 10)),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              moment.ownerName,
              style: TextStyle(
                fontSize: c(width * 0.043, 15, 17),
                height: 1.05,
                fontWeight: FontWeight.w700,
                color: AppColors.black,
              ),
            ),
            SizedBox(height: c(width * 0.008, 2, 4)),
            Text(
              _relativeTime(),
              style: TextStyle(
                fontSize: c(width * 0.035, 12, 14),
                height: 1.05,
                color: AppColors.grayText,
              ),
            ),
          ],
        ),
        SizedBox(width: c(width * 0.012, 4, 6)),
        InkWell(
          onTap: onMore,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              LucideIcons.ellipsis_vertical,
              size: c(width * 0.061, 21, 24),
              color: AppColors.black,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReactionBar extends StatelessWidget {
  final double width;
  final List<GoMateEmojiType> emojis;
  final ValueChanged<GoMateEmojiType> onReact;
  final VoidCallback onMore;

  const _ReactionBar({
    required this.width,
    required this.emojis,
    required this.onReact,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final quick = emojis.take(3).toList(growable: false);
    final circle = (width * 0.101).clamp(36.0, 40.0).toDouble();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final emoji in quick)
          _ReactionCircle(
            size: circle,
            onTap: () => onReact(emoji),
            child: GoMateEmojiIcon(
              emoji: emoji,
              size: circle * 0.43,
            ),
          ),
        _ReactionCircle(
          size: circle,
          onTap: onMore,
          child: Icon(
            LucideIcons.plus,
            size: circle * 0.63,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }
}

class _ReactionCircle extends StatelessWidget {
  final double size;
  final Widget child;
  final VoidCallback onTap;

  const _ReactionCircle({
    required this.size,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _MessageComposer extends StatefulWidget {
  final double width;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String receiverName;
  final VoidCallback onSend;

  const _MessageComposer({
    required this.width,
    required this.controller,
    required this.focusNode,
    required this.receiverName,
    required this.onSend,
  });

  @override
  State<_MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<_MessageComposer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.trim().isNotEmpty;
    final width = widget.width;
    final sendButton = (width * 0.075).clamp(26.0, 30.0).toDouble();
    final fontSize = (width * 0.035).clamp(12.0, 14.0).toDouble();

    return Container(
      padding: EdgeInsets.only(
        left: (width * 0.065).clamp(20.0, 28.0).toDouble(),
        right: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.grayBackground,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              minLines: 1,
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => widget.onSend(),
              style: TextStyle(fontSize: fontSize, color: AppColors.black),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'Gửi tin nhắn cho ${widget.receiverName}',
                hintStyle: TextStyle(
                  color: AppColors.grayText,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (hasText)
            InkWell(
              onTap: widget.onSend,
              customBorder: const CircleBorder(),
              child: Container(
                width: sendButton,
                height: sendButton,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                alignment: Alignment.center,
                child: Icon(
                  LucideIcons.arrow_up,
                  size: sendButton * 0.54,
                  color: Colors.white,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Icon(
                LucideIcons.send,
                size: (width * 0.059).clamp(20.0, 23.0).toDouble(),
                color: AppColors.grayText,
              ),
            ),
        ],
      ),
    );
  }
}
