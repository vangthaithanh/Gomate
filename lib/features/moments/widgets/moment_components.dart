import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gomate_emoji.dart';

enum MomentViewerActionResult { mute, report }

enum MyMomentActionResult { save, delete }

class MomentViewerActionContent extends StatelessWidget {
  const MomentViewerActionContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionRow(
          icon: LucideIcons.circle_x,
          label: 'Tắt ảnh khoảnh khắc',
          onTap: () => Navigator.of(context).pop(MomentViewerActionResult.mute),
        ),
        const Divider(height: 1, color: AppColors.grayBorder),
        _ActionRow(
          icon: LucideIcons.message_square_warning,
          label: 'Báo cáo',
          color: AppColors.primaryText,
          onTap: () => Navigator.of(context).pop(MomentViewerActionResult.report),
        ),
      ],
    );
  }
}

class MyMomentActionContent extends StatelessWidget {
  const MyMomentActionContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionRow(
          icon: LucideIcons.download,
          label: 'Lưu vào thư viện ảnh',
          onTap: () => Navigator.of(context).pop(MyMomentActionResult.save),
        ),
        const Divider(height: 1, color: AppColors.grayBorder),
        _ActionRow(
          icon: LucideIcons.trash,
          label: 'Xoá ảnh',
          color: AppColors.primaryText,
          onTap: () => Navigator.of(context).pop(MyMomentActionResult.delete),
        ),
      ],
    );
  }
}

class MomentConfirmContent extends StatelessWidget {
  final String title;
  final String description;
  final String? secondaryDescription;
  final String buttonLabel;

  const MomentConfirmContent({
    super.key,
    required this.title,
    required this.description,
    this.secondaryDescription,
    this.buttonLabel = 'Xác nhận',
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: EdgeInsets.only(bottom: (width * 0.018).clamp(6.0, 8.0).toDouble()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: (width * 0.042).clamp(15.0, 17.0).toDouble(),
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
          SizedBox(height: (width * 0.020).clamp(7.0, 9.0).toDouble()),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: (width * 0.028).clamp(10.0, 11.5).toDouble(),
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: AppColors.grayText,
            ),
          ),
          if (secondaryDescription != null) ...[
            SizedBox(height: (width * 0.008).clamp(3.0, 4.0).toDouble()),
            Text(
              secondaryDescription!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: (width * 0.028).clamp(10.0, 11.5).toDouble(),
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
          ],
          SizedBox(height: (width * 0.030).clamp(10.0, 13.0).toDouble()),
          SizedBox(
            width: (width * 0.43).clamp(150.0, 178.0).toDouble(),
            height: (width * 0.12).clamp(42.0, 48.0).toDouble(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: AppColors.elevatedShadow,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => Navigator.of(context).pop(true),
                  child: Center(
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
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

class MomentEmojiPickerContent extends StatelessWidget {
  const MomentEmojiPickerContent({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final emojiSize = (width * 0.075).clamp(26.0, 32.0).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chọn cảm xúc',
          style: TextStyle(
            fontSize: (width * 0.041).clamp(15.0, 17.0).toDouble(),
            fontWeight: FontWeight.w700,
            color: AppColors.primaryText,
          ),
        ),
        SizedBox(height: (width * 0.045).clamp(16.0, 19.0).toDouble()),
        Wrap(
          spacing: (width * 0.045).clamp(15.0, 19.0).toDouble(),
          runSpacing: (width * 0.040).clamp(14.0, 17.0).toDouble(),
          children: [
            for (final emoji in GoMateEmojiCatalog.all)
              InkWell(
                onTap: () => Navigator.of(context).pop(emoji),
                customBorder: const CircleBorder(),
                child: Container(
                  width: (width * 0.13).clamp(46.0, 54.0).toDouble(),
                  height: (width * 0.13).clamp(46.0, 54.0).toDouble(),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.elevatedShadow,
                  ),
                  alignment: Alignment.center,
                  child: GoMateEmojiIcon(emoji: emoji, size: emojiSize),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class MomentMessageContent extends StatefulWidget {
  final String receiverName;
  final String receiverAvatarAsset;

  const MomentMessageContent({
    super.key,
    required this.receiverName,
    required this.receiverAvatarAsset,
  });

  @override
  State<MomentMessageContent> createState() => _MomentMessageContentState();
}

class _MomentMessageContentState extends State<MomentMessageContent> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hasText = _controller.text.trim().isNotEmpty;
    final avatarSize = (width * 0.075).clamp(27.0, 31.0).toDouble();
    final composerHeight = (width * 0.105).clamp(38.0, 43.0).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.blue50,
                border: Border.all(color: AppColors.grayBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                widget.receiverAvatarAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  LucideIcons.user,
                  color: AppColors.grayText,
                ),
              ),
            ),
            SizedBox(width: (width * 0.025).clamp(8.0, 10.0).toDouble()),
            Expanded(
              child: Text(
                'Nhắn tin cho ${widget.receiverName} >',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: (width * 0.037).clamp(13.5, 15.0).toDouble(),
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: (width * 0.034).clamp(11.0, 14.0).toDouble()),
        Container(
          constraints: BoxConstraints(minHeight: composerHeight),
          decoration: BoxDecoration(
            color: AppColors.grayBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.only(left: 14, right: 7),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _submit,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Gửi tin nhắn',
                    hintStyle: TextStyle(
                      color: AppColors.grayText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (hasText)
                InkWell(
                  onTap: () => _submit(_controller.text),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      LucideIcons.arrow_up,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(
                    LucideIcons.send,
                    size: 21,
                    color: AppColors.grayText,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _submit(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }
}

class MomentReactionBar extends StatelessWidget {
  final List<GoMateEmojiType> quickEmojis;
  final ValueChanged<GoMateEmojiType> onReact;
  final VoidCallback onMore;

  const MomentReactionBar({
    super.key,
    required this.quickEmojis,
    required this.onReact,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final buttonSize = (width * 0.093).clamp(34.0, 38.0).toDouble();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final emoji in quickEmojis) ...[
          _ReactionButton(
            size: buttonSize,
            child: GoMateEmojiIcon(
              emoji: emoji,
              size: buttonSize * 0.42,
            ),
            onTap: () => onReact(emoji),
          ),
          SizedBox(width: (width * 0.044).clamp(15.0, 18.0).toDouble()),
        ],
        _ReactionButton(
          size: buttonSize,
          child: Icon(
            LucideIcons.plus,
            size: buttonSize * 0.56,
            color: AppColors.black,
          ),
          onTap: onMore,
        ),
      ],
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final double size;
  final Widget child;
  final VoidCallback onTap;

  const _ReactionButton({
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
          boxShadow: AppColors.elevatedShadow,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.black,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: (width * 0.037).clamp(13.0, 16.0).toDouble(),
        ),
        child: Row(
          children: [
            Icon(icon, size: 23, color: color),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: (width * 0.040).clamp(14.0, 16.0).toDouble(),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
