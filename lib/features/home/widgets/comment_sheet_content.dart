import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/bottom_sheet.dart';
import '../data/post_interaction_repository.dart';
import '../models/post_interaction_models.dart';

class CommentSheetContent extends StatefulWidget {
  final String postId;
  final PostInteractionRepository repository;

  const CommentSheetContent({
    super.key,
    required this.postId,
    required this.repository,
  });

  @override
  State<CommentSheetContent> createState() => _CommentSheetContentState();
}

class _CommentSheetContentState extends State<CommentSheetContent> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  /// Ảnh đang chờ gửi cùng bình luận.
  /// Đây là local XFile của UI; repository thật sau này chịu trách nhiệm upload.
  final List<XFile> _selectedImages = <XFile>[];

  List<PostComment> _comments = const <PostComment>[];
  final Set<String> _expandedReplyRoots = <String>{};

  bool _loading = true;
  bool _sending = false;
  String? _replyingToId;
  String? _replyingToName;

  @override
  void initState() {
    super.initState();
    _load();
    _controller.addListener(_onTextChanged);
  }

  Future<void> _load() async {
    final comments = await widget.repository.getComments(widget.postId);

    if (!mounted) return;

    setState(() {
      _comments = comments;
      _loading = false;
    });
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  List<PostComment> get _rootComments {
    return _comments
        .where((comment) => comment.parentId == null)
        .toList(growable: false);
  }

  List<PostComment> _repliesOf(String rootId) {
    return _comments
        .where((comment) => comment.parentId == rootId)
        .toList(growable: false);
  }

  Future<void> _toggleLike(PostComment comment) async {
    HapticFeedback.selectionClick();

    final updated = await widget.repository.toggleCommentLike(comment);
    if (!mounted) return;

    setState(() {
      _comments = _comments
          .map((item) => item.id == updated.id ? updated : item)
          .toList(growable: false);
    });
  }

  void _beginReply(PostComment comment) {
    setState(() {
      _replyingToId = comment.parentId ?? comment.id;
      _replyingToName = comment.userName;
    });

    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToName = null;
    });
  }

  Future<void> _pickFromGallery() async {
    // Tối đa 6 ảnh cho một bình luận để UI không bị quá tải.
    final remaining = 6 - _selectedImages.length;
    if (remaining <= 0) return;

    final images = await _imagePicker.pickMultiImage(
      imageQuality: 88,
      limit: remaining,
    );

    if (!mounted || images.isEmpty) return;

    setState(() {
      _selectedImages.addAll(images.take(remaining));
    });
  }

  Future<void> _takePhoto() async {
    if (_selectedImages.length >= 6) return;

    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
    );

    if (!mounted || image == null) return;

    setState(() {
      _selectedImages.add(image);
    });
  }

  void _removeSelectedImage(int index) {
    if (index < 0 || index >= _selectedImages.length) return;

    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final body = _controller.text.trim();

    // Cho phép gửi:
    // - chỉ text;
    // - chỉ ảnh;
    // - text + ảnh.
    if ((body.isEmpty && _selectedImages.isEmpty) || _sending) return;

    HapticFeedback.selectionClick();

    setState(() {
      _sending = true;
    });

    final comment = await widget.repository.createComment(
      postId: widget.postId,
      body: body,
      parentId: _replyingToId,
      mediaAssets: _selectedImages.map((image) => image.path).toList(
        growable: false,
      ),
    );

    if (!mounted) return;

    _controller.clear();

    setState(() {
      _comments = <PostComment>[..._comments, comment];
      if (_replyingToId != null) {
        _expandedReplyRoots.add(_replyingToId!);
      }
      _selectedImages.clear();
      _replyingToId = null;
      _replyingToName = null;
      _sending = false;
    });
  }

  Future<void> _openDelete(PostComment comment) async {
    if (!comment.isMine) return;

    HapticFeedback.mediumImpact();

    final shouldDelete = await GoMateBottomSheet.show<bool>(
      context: context,
      size: GoMateBottomSheetSize.compact,
      contentPadding: EdgeInsets.zero,
      child: _DeleteCommentAction(
        onDelete: () => Navigator.of(context).pop(true),
      ),
    );

    if (!mounted || shouldDelete != true) return;

    await widget.repository.deleteComment(comment.id);

    if (!mounted) return;

    setState(() {
      final removedRoot = comment.parentId == null ? comment.id : null;

      _comments = _comments.where((item) {
        if (item.id == comment.id) return false;
        if (removedRoot != null && item.parentId == removedRoot) return false;
        return true;
      }).toList(growable: false);

      if (removedRoot != null) {
        _expandedReplyRoots.remove(removedRoot);
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final height = (screen.height * 0.64).clamp(420.0, 560.0).toDouble();

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              screen.width * 0.055,
              0,
              screen.width * 0.055,
              screen.width * 0.025,
            ),
            child: Text(
              'Bình luận',
              style: TextStyle(
                fontSize: _font(screen.width, 15.5),
                fontWeight: FontWeight.w700,
                color: AppColors.black,
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
                : _rootComments.isEmpty
                ? Center(
              child: Text(
                'Chưa có bình luận.',
                style: TextStyle(
                  fontSize: _font(screen.width, 12.5),
                  color: AppColors.grayText,
                ),
              ),
            )
                : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                screen.width * 0.045,
                screen.width * 0.015,
                screen.width * 0.045,
                screen.width * 0.025,
              ),
              itemCount: _rootComments.length,
              itemBuilder: (context, index) {
                final root = _rootComments[index];
                final replies = _repliesOf(root.id);
                final expanded =
                _expandedReplyRoots.contains(root.id);

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: screen.width * 0.025,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CommentTile(
                        comment: root,
                        isReply: false,
                        onLike: () => _toggleLike(root),
                        onReply: () => _beginReply(root),
                        onLongPress: root.isMine
                            ? () => _openDelete(root)
                            : null,
                      ),

                      if (replies.isNotEmpty && !expanded)
                        _ReplyDisclosure(
                          count: replies.length,
                          onTap: () {
                            setState(() {
                              _expandedReplyRoots.add(root.id);
                            });
                          },
                        ),

                      if (replies.isNotEmpty && expanded) ...[
                        for (final reply in replies)
                          Padding(
                            padding: EdgeInsets.only(
                              left: screen.width * 0.105,
                              top: screen.width * 0.020,
                            ),
                            child: _CommentTile(
                              comment: reply,
                              isReply: true,
                              onLike: () => _toggleLike(reply),
                              onReply: () => _beginReply(reply),
                              onLongPress: reply.isMine
                                  ? () => _openDelete(reply)
                                  : null,
                            ),
                          ),
                        _ReplyDisclosure(
                          count: replies.length,
                          expanded: true,
                          onTap: () {
                            setState(() {
                              _expandedReplyRoots.remove(root.id);
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          if (_replyingToName != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                screen.width * 0.055,
                screen.width * 0.010,
                screen.width * 0.055,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Đang trả lời $_replyingToName',
                      style: TextStyle(
                        fontSize: _font(screen.width, 10.5),
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _cancelReply,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(screen.width * 0.010),
                      child: Icon(
                        LucideIcons.x,
                        size: screen.width * 0.042,
                        color: AppColors.grayText,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          _CommentComposer(
            controller: _controller,
            focusNode: _focusNode,
            sending: _sending,
            selectedImages: _selectedImages,
            onTakePhoto: _takePhoto,
            onPickGallery: _pickFromGallery,
            onRemoveImage: _removeSelectedImage,
            onSend: _submit,
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final PostComment comment;
  final bool isReply;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback? onLongPress;

  const _CommentTile({
    required this.comment,
    required this.isReply,
    required this.onLike,
    required this.onReply,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final avatarSize = isReply
        ? (width * 0.075).clamp(27.0, 31.0).toDouble()
        : (width * 0.085).clamp(31.0, 35.0).toDouble();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentAvatar(
            asset: comment.avatarAsset,
            size: avatarSize,
          ),
          SizedBox(width: width * 0.022),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: TextStyle(
                        fontSize: _font(width, 11.5),
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                    SizedBox(width: width * 0.018),
                    Text(
                      comment.timeText,
                      style: TextStyle(
                        fontSize: _font(width, 9.5),
                        color: AppColors.grayText,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: width * 0.008),

                _CommentBody(
                  text: comment.body,
                  width: width,
                ),

                if (comment.mediaAssets.isNotEmpty) ...[
                  SizedBox(height: width * 0.022),
                  SizedBox(
                    // Tăng ảnh comment lên một chút để dễ nhìn hơn.
                    height: (width * 0.32).clamp(116.0, 138.0).toDouble(),
                    child: ListView.separated(
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: comment.mediaAssets.length,
                      separatorBuilder: (_, __) =>
                          SizedBox(width: width * 0.018),
                      itemBuilder: (context, index) {
                        final size =
                        (width * 0.32).clamp(116.0, 138.0).toDouble();

                        return ClipRRect(
                          borderRadius: BorderRadius.circular(
                            (width * 0.030).clamp(10.0, 13.0).toDouble(),
                          ),
                          child: _CommentMediaImage(
                            path: comment.mediaAssets[index],
                            width: size,
                            height: size,
                          ),
                        );
                      },
                    ),
                  ),
                ],

                SizedBox(height: width * 0.012),

                InkWell(
                  onTap: onReply,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: width * 0.004,
                      vertical: width * 0.006,
                    ),
                    child: Text(
                      'Trả lời',
                      style: TextStyle(
                        fontSize: _font(width, 9.5),
                        fontWeight: FontWeight.w500,
                        color: AppColors.grayText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: width * 0.016),

          InkWell(
            onTap: onLike,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: EdgeInsets.all(width * 0.012),
              child: Column(
                children: [
                  comment.isLiked
                      ? Icon(
                    Icons.favorite_rounded,
                    size: (width * 0.047).clamp(17.0, 20.0).toDouble(),
                    color: AppColors.primaryIcon,
                  )
                      : Icon(
                    LucideIcons.heart,
                    size: (width * 0.047).clamp(17.0, 20.0).toDouble(),
                    color: AppColors.black,
                  ),
                  if (comment.likeCount > 0) ...[
                    SizedBox(height: width * 0.006),
                    Text(
                      '${comment.likeCount}',
                      style: TextStyle(
                        fontSize: _font(width, 9),
                        fontWeight: FontWeight.w500,
                        color: comment.isLiked
                            ? AppColors.primaryText
                            : AppColors.grayText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentBody extends StatelessWidget {
  final String text;
  final double width;

  const _CommentBody({
    required this.text,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final parts = text.split(RegExp(r'(\s+)'));

    return Wrap(
      spacing: 2,
      runSpacing: 0,
      children: parts.where((part) => part.trim().isNotEmpty).map((part) {
        final mention = part.startsWith('@');

        return Text(
          part,
          style: TextStyle(
            fontSize: _font(width, 11.5),
            height: 1.18,
            fontWeight: mention ? FontWeight.w600 : FontWeight.w400,
            color: mention ? AppColors.primaryText : AppColors.black,
          ),
        );
      }).toList(growable: false),
    );
  }
}

class _ReplyDisclosure extends StatelessWidget {
  final int count;
  final bool expanded;
  final VoidCallback onTap;

  const _ReplyDisclosure({
    required this.count,
    required this.onTap,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Padding(
      padding: EdgeInsets.only(
        left: width * 0.105,
        top: width * 0.008,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: width * 0.006,
            vertical: width * 0.010,
          ),
          child: Text(
            expanded
                ? 'Ẩn câu trả lời'
                : 'Hiển thị $count câu trả lời',
            style: TextStyle(
              fontSize: _font(width, 10),
              fontWeight: FontWeight.w600,
              color: AppColors.grayText,
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final List<XFile> selectedImages;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickGallery;
  final ValueChanged<int> onRemoveImage;
  final VoidCallback onSend;

  const _CommentComposer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.selectedImages,
    required this.onTakePhoto,
    required this.onPickGallery,
    required this.onRemoveImage,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hasText = controller.text.trim().isNotEmpty;
    final hasImages = selectedImages.isNotEmpty;
    final canSend = hasText || hasImages;

    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(
        width * 0.045,
        width * 0.016,
        width * 0.045,
        width * 0.025,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasImages) ...[
            _PendingCommentMediaStrip(
              images: selectedImages,
              width: width,
              onRemove: onRemoveImage,
            ),
            SizedBox(height: width * 0.018),
          ],

          Container(
            constraints: BoxConstraints(
              // Tăng composer nhẹ để cân với bottom sheet và dễ thao tác hơn.
              minHeight: (width * 0.118).clamp(43.0, 49.0).toDouble(),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: width * 0.026,
              vertical: width * 0.008,
            ),
            decoration: BoxDecoration(
              color: AppColors.grayBackground,
              borderRadius: BorderRadius.circular(
                (width * 0.050).clamp(17.0, 21.0).toDouble(),
              ),
            ),
            child: Row(
              children: [
                // Khi bắt đầu nhập chữ, toàn bộ nút thêm media được ẩn.
                if (!hasText) ...[
                  InkWell(
                    onTap: onTakePhoto,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(width * 0.008),
                      child: Icon(
                        LucideIcons.camera,
                        size: (width * 0.052).clamp(19.0, 22.0).toDouble(),
                        color: AppColors.grayText,
                      ),
                    ),
                  ),
                  SizedBox(width: width * 0.010),
                ],

                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    cursorColor: AppColors.primaryIcon,
                    style: TextStyle(
                      fontSize: _font(width, 12.5),
                      color: AppColors.black,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'Viết bình luận...',
                      hintStyle: TextStyle(
                        fontSize: _font(width, 12),
                        color: AppColors.grayText,
                      ),
                    ),
                  ),
                ),

                // Chỉ hiện emoji + thêm ảnh khi CHƯA nhập text.
                if (!hasText) ...[
                  SizedBox(width: width * 0.010),
                  Icon(
                    LucideIcons.face_slightly_smiling,
                    size: (width * 0.050).clamp(18.0, 21.0).toDouble(),
                    color: AppColors.grayText,
                  ),
                  SizedBox(width: width * 0.015),
                  InkWell(
                    onTap: selectedImages.length >= 6 ? null : onPickGallery,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(width * 0.008),
                      child: Icon(
                        LucideIcons.image,
                        size: (width * 0.050).clamp(18.0, 21.0).toDouble(),
                        color: selectedImages.length >= 6
                            ? AppColors.grayBorder
                            : AppColors.grayText,
                      ),
                    ),
                  ),
                ],

                if (canSend) ...[
                  SizedBox(width: width * 0.018),
                  _CommentSendButton(
                    sending: sending,
                    attachmentCount: selectedImages.length,
                    width: width,
                    onTap: onSend,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingCommentMediaStrip extends StatelessWidget {
  final List<XFile> images;
  final double width;
  final ValueChanged<int> onRemove;

  const _PendingCommentMediaStrip({
    required this.images,
    required this.width,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final previewWidth = (width * 0.235).clamp(84.0, 102.0).toDouble();
    final previewHeight = (width * 0.285).clamp(102.0, 124.0).toDouble();

    return SizedBox(
      width: double.infinity,
      height: previewHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: width * 0.006),
        itemCount: images.length,
        separatorBuilder: (_, __) => SizedBox(width: width * 0.020),
        itemBuilder: (context, index) {
          final image = images[index];

          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  (width * 0.035).clamp(12.0, 15.0).toDouble(),
                ),
                child: Image.file(
                  File(image.path),
                  width: previewWidth,
                  height: previewHeight,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: previewWidth,
                    height: previewHeight,
                    color: AppColors.grayBackground,
                    alignment: Alignment.center,
                    child: const Icon(
                      LucideIcons.image,
                      color: AppColors.grayText,
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 6,
                right: 6,
                child: InkWell(
                  onTap: () => onRemove(index),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: (width * 0.070).clamp(25.0, 29.0).toDouble(),
                    height: (width * 0.070).clamp(25.0, 29.0).toDouble(),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.68),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.x,
                      size: (width * 0.040).clamp(14.0, 17.0).toDouble(),
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CommentSendButton extends StatelessWidget {
  final bool sending;
  final int attachmentCount;
  final double width;
  final VoidCallback onTap;

  const _CommentSendButton({
    required this.sending,
    required this.attachmentCount,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = (width * 0.078).clamp(28.0, 32.0).toDouble();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: sending ? null : onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            alignment: Alignment.center,
            child: sending
                ? const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: Colors.white,
              ),
            )
                : Icon(
              LucideIcons.send,
              size: (width * 0.038).clamp(14.0, 16.0).toDouble(),
              color: Colors.white,
            ),
          ),
        ),

        if (attachmentCount > 0)
          Positioned(
            top: -6,
            right: -5,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 17,
                minHeight: 17,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              alignment: Alignment.center,
              child: Text(
                '$attachmentCount',
                style: TextStyle(
                  fontSize: _font(width, 8.5),
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryText,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CommentMediaImage extends StatelessWidget {
  final String path;
  final double width;
  final double height;

  const _CommentMediaImage({
    required this.path,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    if (path.startsWith('/') || path.startsWith('file://')) {
      final filePath = path.startsWith('file://')
          ? Uri.parse(path).toFilePath()
          : path;

      return Image.file(
        File(filePath),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    return Image.asset(
      path,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      color: AppColors.grayBackground,
      alignment: Alignment.center,
      child: const Icon(
        LucideIcons.image,
        color: AppColors.grayText,
      ),
    );
  }
}

class _DeleteCommentAction extends StatelessWidget {
  final VoidCallback onDelete;

  const _DeleteCommentAction({
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDelete,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            width * 0.060,
            width * 0.045,
            width * 0.060,
            width * 0.060,
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.trash,
                size: (width * 0.060).clamp(21.0, 24.0).toDouble(),
                color: const Color(0xFFE53935),
              ),
              SizedBox(width: width * 0.035),
              Text(
                'Xóa bình luận',
                style: TextStyle(
                  fontSize: _font(width, 14),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE53935),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentAvatar extends StatelessWidget {
  final String asset;
  final double size;

  const _CommentAvatar({
    required this.asset,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE7EBF3),
        border: Border.all(color: AppColors.grayBorder),
      ),
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(
            LucideIcons.user,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

double _font(double width, double baseAt375) {
  final value = baseAt375 * (width / 375);
  return value.clamp(baseAt375 * 0.92, baseAt375 * 1.10).toDouble();
}
