import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../ui_preview/post_ui_demo_store.dart';

/// Displays local user-selected photos and video, or existing CDN/asset photos.
/// TODO(BACKEND-CREATE-POST-VIDEO): Replace local file paths after upload;
/// local video trimRange is preview metadata, not an exported clipped file.
class GoMatePostMediaWidget extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final Uint8List? thumbnailBytes;
  final GoMatePostTrimRange? trimRange;

  const GoMatePostMediaWidget({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.thumbnailBytes,
    this.trimRange,
  });

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('video-file:')) {
      return _LocalVideo(
        key: ValueKey(source),
        file: File(source.substring('video-file:'.length)),
        thumbnailBytes: thumbnailBytes,
        trimRange: trimRange,
        fit: fit,
      );
    }
    if (source.startsWith('video-demo:')) {
      final poster = source.substring('video-demo:'.length);
      return Stack(fit: StackFit.expand, children: [
        Image.asset(poster, fit: fit, errorBuilder: (_, __, ___) => _fallback()),
        const Center(child: Icon(LucideIcons.play, color: Colors.white, size: 36)),
      ]);
    }
    if (source.startsWith('file://')) {
      return Image.file(File.fromUri(Uri.parse(source)), fit: fit,
        errorBuilder: (_, __, ___) => _fallback());
    }
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(source, fit: fit,
        errorBuilder: (_, __, ___) => _fallback());
    }
    return source.isEmpty
        ? _fallback()
        : Image.asset(source, fit: fit,
          errorBuilder: (_, __, ___) => _fallback());
  }

  Widget _fallback() => const ColoredBox(
    color: Color(0xFFE8EDF6),
    child: Center(child: Icon(LucideIcons.image, color: AppColors.grayText)),
  );
}

class _LocalVideo extends StatefulWidget {
  final File file;
  final Uint8List? thumbnailBytes;
  final GoMatePostTrimRange? trimRange;
  final BoxFit fit;

  const _LocalVideo({
    super.key,
    required this.file,
    required this.thumbnailBytes,
    required this.trimRange,
    required this.fit,
  });

  @override
  State<_LocalVideo> createState() => _LocalVideoState();
}

class _LocalVideoState extends State<_LocalVideo> {
  late final VideoPlayerController _player;
  bool _initialized = false;
  bool _playing = false;
  bool _stopping = false;

  @override
  void initState() {
    super.initState();
    _player = VideoPlayerController.file(widget.file);
    _player.addListener(_watch);
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.initialize();
      if (!mounted) return;
      final start = widget.trimRange?.startMs ?? 0;
      if (start > 0) {
        await _player.seekTo(Duration(milliseconds: start));
      }
      if (mounted) setState(() => _initialized = true);
    } catch (_) {
      // The poster stays available when the device cannot decode a video.
    }
  }

  void _watch() {
    if (!_initialized || !_player.value.isInitialized) return;
    final end = widget.trimRange?.endMs;
    if (end != null && !_stopping && _player.value.isPlaying &&
        _player.value.position.inMilliseconds >= end) {
      _stopping = true;
      _rewind();
    }
  }

  Future<void> _rewind() async {
    try {
      await _player.pause();
      await _player.seekTo(
        Duration(milliseconds: widget.trimRange?.startMs ?? 0));
      if (mounted) setState(() => _playing = false);
    } finally {
      _stopping = false;
    }
  }

  Future<void> _toggle() async {
    if (!_initialized) return;
    if (_player.value.isPlaying) {
      await _player.pause();
    } else {
      final start = widget.trimRange?.startMs ?? 0;
      final end = widget.trimRange?.endMs;
      if (end != null && _player.value.position.inMilliseconds >= end) {
        await _player.seekTo(Duration(milliseconds: start));
      }
      await _player.play();
    }
    if (mounted) setState(() => _playing = _player.value.isPlaying);
  }

  @override
  void dispose() {
    _player.removeListener(_watch);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Stack(fit: StackFit.expand, children: [
        if (_initialized && _player.value.size.width > 0)
          FittedBox(fit: widget.fit,
            child: SizedBox(
              width: _player.value.size.width,
              height: _player.value.size.height,
              child: VideoPlayer(_player),
            ),
          )
        else if (widget.thumbnailBytes != null)
          Image.memory(widget.thumbnailBytes!, fit: widget.fit)
        else
          const ColoredBox(color: Color(0xFFE8EDF6),
            child: Icon(LucideIcons.video, size: 30, color: AppColors.grayText)),
        if (!_playing)
          const Center(child: Icon(LucideIcons.play,
            size: 38, color: Colors.white)),
      ]),
    );
  }
}
