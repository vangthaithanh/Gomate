import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:video_player/video_player.dart';
import '../../../core/diagnostics/post_media_diagnostics.dart';
import '../../../core/theme/app_colors.dart';
import '../data/home_post_media_store.dart';

/// A disposable view/lease only; the Home store owns its image and player.
class RetainedHomePostMedia extends StatefulWidget {
  final HomePostMediaStore store;
  final String path, version;
  final String? poster;
  final bool video, active;
  final BoxFit fit;
  final ScrollController? scroll;
  const RetainedHomePostMedia({
    super.key,
    required this.store,
    required this.path,
    required this.version,
    this.poster,
    required this.video,
    required this.active,
    required this.fit,
    this.scroll,
  });
  @override
  State<RetainedHomePostMedia> createState() => _RetainedHomePostMediaState();
}

class _RetainedHomePostMediaState extends State<RetainedHomePostMedia> {
  late HomeMediaEntry _entry;
  bool _checkScheduled = false;
  String? _stage;
  void _attach() {
    _entry = widget.store.acquire(
      widget.path,
      widget.video,
      widget.poster,
      widget.version,
    );
    _entry.addListener(_changed);
    unawaited(_entry.loadImage());
    _scheduleCheck();
  }

  void _detach() {
    _entry.removeListener(_changed);
    _entry.visible = false;
    _entry.pause();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.scroll?.addListener(_scroll);
    _attach();
  }

  @override
  void didUpdateWidget(covariant RetainedHomePostMedia old) {
    super.didUpdateWidget(old);
    if (old.scroll != widget.scroll) {
      old.scroll?.removeListener(_scroll);
      widget.scroll?.addListener(_scroll);
    }
    if (old.store != widget.store ||
        old.path != widget.path ||
        old.version != widget.version ||
        old.poster != widget.poster ||
        old.video != widget.video) {
      _detach();
      _attach();
    }
    if (!widget.active) {
      _entry.visible = false;
      _entry.pause();
    }
    if (widget.active && !old.active) _entry.retryImage();
    _scheduleCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.of(context)) {
      _entry.visible = false;
      _entry.pause();
    }
    _scheduleCheck();
  }

  bool _visible() {
    if (!widget.active ||
        !widget.store.enabled ||
        !TickerMode.of(context) ||
        ModalRoute.of(context)?.isCurrent == false) {
      return false;
    }
    final box = context.findRenderObject();
    final viewport = Scrollable.maybeOf(
      context,
      axis: Axis.vertical,
    )?.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (!rect.isFinite) return false;
    final bounds =
        viewport is RenderBox && viewport.attached && viewport.hasSize
        ? viewport.localToGlobal(Offset.zero) & viewport.size
        : Offset.zero & MediaQuery.sizeOf(context);
    return rect.overlaps(bounds);
  }

  void _scroll() {
    // Pausing is synchronous with the scroll notification, not an async fetch.
    if (_entry.player?.value.isPlaying == true && !_visible()) {
      _entry.visible = false;
      _entry.pause();
    }
    _scheduleCheck();
  }

  void _scheduleCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted) return;
      final visible = _visible();
      if (_entry.released && visible) {
        _detach();
        _attach();
        return;
      }
      final entered = visible && !_entry.visible;
      _entry.visible = visible;
      if (!visible) {
        _entry.pause();
        return;
      }
      if (entered) widget.store.touch(_entry);
      if (widget.video && !_entry.error) unawaited(_entry.prepare());
    });
  }

  Future<void> _play() async {
    if (!_visible()) return;
    _entry.visible = true;
    await _entry.toggle();
  }

  @override
  void dispose() {
    widget.scroll?.removeListener(_scroll);
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _entry.player;
    final initialized = p?.value.isInitialized == true;
    final stage = widget.video
        ? initialized
              ? 'video'
              : _entry.initializing && _entry.wantsPlay
              ? 'video_spinner'
              : 'cover'
        : _entry.image == null
        ? 'image_spinner'
        : 'image';
    if (stage != _stage) {
      _stage = stage;
      PostMediaDiagnostics.event('display_$stage', _entry.logKey);
    }
    if (widget.video && initialized) {
      return GestureDetector(
        onTap: _play,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: FittedBox(
                fit: widget.fit,
                child: SizedBox(
                  width: p!.value.size.width,
                  height: p.value.size.height,
                  child: VideoPlayer(p),
                ),
              ),
            ),
            if (!p.value.isPlaying)
              const Icon(LucideIcons.play, color: Colors.white, size: 38),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                p,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.primaryIcon,
                  bufferedColor: AppColors.grayBorder,
                ),
              ),
            ),
            if (_entry.error)
              const Icon(LucideIcons.wifi_off, color: Colors.white, size: 20),
          ],
        ),
      );
    }
    if (widget.video) {
      return GestureDetector(
        onTap: _play,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            if (_entry.image != null)
              RawImage(image: _entry.image, fit: widget.fit)
            else
              const ColoredBox(color: Color(0xFFE8EDF6)),
            if (_entry.initializing && _entry.wantsPlay)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else
              const Icon(LucideIcons.play, color: Colors.white, size: 38),
          ],
        ),
      );
    }
    if (_entry.image != null) {
      return RawImage(image: _entry.image, fit: widget.fit);
    }
    if (_entry.error || _entry.released) {
      return const ColoredBox(
        color: Color(0xFFE8EDF6),
        child: Center(
          child: Icon(LucideIcons.image, color: AppColors.grayText),
        ),
      );
    }
    return const Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.primaryIcon,
      ),
    );
  }
}
