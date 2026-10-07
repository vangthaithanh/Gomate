import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../../../core/widgets/gomate_emoji.dart';
import '../../../core/widgets/snackbar.dart';
import '../data/moments_repository.dart';
import '../models/moment_models.dart';
import '../widgets/moment_components.dart';
import '../widgets/moment_image_frame.dart';

enum MyMomentDetailResult { deleted }

class MyMomentDetailScreen extends StatefulWidget {
  final MomentsRepository repository;
  final String momentId;

  const MyMomentDetailScreen({
    super.key,
    required this.repository,
    required this.momentId,
  });

  @override
  State<MyMomentDetailScreen> createState() => _MyMomentDetailScreenState();
}

class _MyMomentDetailScreenState extends State<MyMomentDetailScreen> {
  MomentItem? get _moment => widget.repository.momentById(widget.momentId);

  @override
  Widget build(BuildContext context) {
    final moment = _moment;
    if (moment == null) {
      return const Scaffold(backgroundColor: Colors.white);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            double c(double value, double min, double max) {
              return value.clamp(min, max).toDouble();
            }

            final horizontalPadding = c(width * 0.075, 24, 30);
            final headerHeight = c(width * 0.20, 70, 82);
            final iconSize = c(width * 0.064, 22, 25);
            final bodyHeight = math.max(0.0, height - headerHeight);
            final imageSize = math.min(width * 0.80, bodyHeight * 0.56);

            final date = moment.createdAt;
            final hour = date.hour.toString().padLeft(2, '0');
            final minute = date.minute.toString().padLeft(2, '0');

            return Column(
              children: [
                SizedBox(
                  height: headerHeight,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: horizontalPadding),
                          child: _HeaderIcon(
                            icon: LucideIcons.x,
                            size: iconSize,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: width * 0.22,
                          vertical: c(width * 0.025, 8, 10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${date.day} tháng ${date.month}',
                              style: TextStyle(
                                color: AppColors.primaryText,
                                fontSize: c(width * 0.043, 15, 17),
                                height: 1.05,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: c(width * 0.008, 2, 4)),
                            Text(
                              '$hour : $minute',
                              style: TextStyle(
                                color: AppColors.grayText,
                                fontSize: c(width * 0.032, 11, 13),
                                height: 1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (moment.locationText != null) ...[
                              SizedBox(height: c(width * 0.008, 2, 4)),
                              Text(
                                moment.locationText!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.grayText,
                                  fontSize: c(width * 0.029, 10, 12),
                                  height: 1,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.only(right: horizontalPadding),
                          child: _HeaderIcon(
                            icon: LucideIcons.ellipsis_vertical,
                            size: iconSize,
                            onTap: _openActions,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Spacer làm ảnh bị tụt xuống trên máy cao. Dùng khoảng cách
                        // responsive theo chiều rộng để giữ đúng nhịp với header.
                        SizedBox(height: c(width * 0.13, 44, 52)),

                        Center(
                          child: MomentImageFrame(
                            size: imageSize,
                            imageAsset: moment.imageAsset,
                          ),
                        ),

                        SizedBox(height: c(width * 0.065, 20, 26)),

                        Text(
                          'Cảm xúc',
                          style: TextStyle(
                            color: AppColors.black,
                            fontSize: c(width * 0.035, 12.5, 14),
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        SizedBox(height: c(width * 0.026, 8, 11)),

                        Expanded(
                          child: moment.reactions.isEmpty
                              ? Align(
                                  alignment: Alignment.topLeft,
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      top: c(width * 0.018, 6, 8),
                                    ),
                                    child: Text(
                                      'Chưa có cảm xúc',
                                      style: TextStyle(
                                        color: AppColors.grayText,
                                        fontSize: c(width * 0.035, 12.5, 14),
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: EdgeInsets.only(
                                    bottom: c(height * 0.025, 12, 20),
                                  ),
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: moment.reactions.length,
                                  separatorBuilder: (_, __) => SizedBox(
                                    height: c(width * 0.018, 6, 8),
                                  ),
                                  itemBuilder: (context, index) {
                                    final reaction = moment.reactions[index];
                                    return _ReactionRow(
                                      reaction: reaction,
                                      width: width,
                                      onMessage: () =>
                                          _messageReactionUser(reaction),
                                    );
                                  },
                                ),
                        ),
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

  Future<void> _openActions() async {
    final result = await GoMateBottomSheet.show<MyMomentActionResult>(
      context: context,
      size: GoMateBottomSheetSize.compact,
      child: const MyMomentActionContent(),
    );

    if (!mounted || result == null) return;

    switch (result) {
      case MyMomentActionResult.save:
        GoMateSnackBar.show(
          context,
          message: 'Đã chọn ảnh để lưu vào thư viện',
          bottomOffset: 16,
          icon: LucideIcons.download,
        );
        break;
      case MyMomentActionResult.delete:
        await _deleteMoment();
        break;
    }
  }

  Future<void> _deleteMoment() async {
    final confirmed = await GoMateBottomSheet.show<bool>(
      context: context,
      size: GoMateBottomSheetSize.compact,
      child: const MomentConfirmContent(
        title: 'Xoá ảnh khoảnh khắc',
        description: 'Ảnh khoảnh khắc này sẽ bị xoá vĩnh viễn khỏi kho lưu trữ.',
      ),
    );

    if (!mounted || confirmed != true) return;

    widget.repository.deleteMoments({widget.momentId});
    Navigator.of(context).pop(MyMomentDetailResult.deleted);
  }

  Future<void> _messageReactionUser(MomentReaction reaction) async {
    final message = await GoMateBottomSheet.show<String>(
      context: context,
      size: GoMateBottomSheetSize.compact,
      child: MomentMessageContent(
        receiverName: reaction.userName,
        receiverAvatarAsset: reaction.avatarAsset,
      ),
    );

    if (!mounted || message == null || message.trim().isEmpty) return;

    await widget.repository.sendMessage(
      receiverUserId: reaction.userId,
      message: message,
    );

    if (!mounted) return;
    GoMateSnackBar.show(
      context,
      message: 'Đã gửi tin nhắn cho ${reaction.userName}',
      bottomOffset: 16,
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

class _ReactionRow extends StatelessWidget {
  final MomentReaction reaction;
  final double width;
  final VoidCallback onMessage;

  const _ReactionRow({
    required this.reaction,
    required this.width,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    double c(double value, double min, double max) {
      return value.clamp(min, max).toDouble();
    }

    final avatar = c(width * 0.091, 32, 36);
    final rowHeight = c(width * 0.117, 42, 47);

    return SizedBox(
      height: rowHeight,
      child: Row(
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
            child: Image.asset(reaction.avatarAsset, fit: BoxFit.cover),
          ),
          SizedBox(width: c(width * 0.027, 9, 11)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reaction.userName,
                  style: TextStyle(
                    fontSize: c(width * 0.032, 11.5, 13),
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                SizedBox(height: c(width * 0.009, 3, 4)),
                Text(
                  reaction.userName,
                  style: TextStyle(
                    fontSize: c(width * 0.029, 10.5, 12),
                    height: 1,
                    color: AppColors.grayText,
                  ),
                ),
              ],
            ),
          ),
          GoMateEmojiIcon(
            emoji: reaction.emoji,
            size: c(width * 0.041, 14, 16),
          ),
          SizedBox(width: c(width * 0.035, 11, 14)),
          InkWell(
            onTap: onMessage,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                LucideIcons.send,
                size: c(width * 0.059, 20, 23),
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
