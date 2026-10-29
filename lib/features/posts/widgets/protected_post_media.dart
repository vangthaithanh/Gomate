import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/services/auth_service.dart';
import '../data/post_video_pool.dart';
import '../../../core/diagnostics/post_media_diagnostics.dart';
import '../../../core/theme/app_colors.dart';
import '../data/home_post_media_store.dart';
import 'retained_home_post_media.dart';

/// No NetworkImage cache: private Post bytes stay scoped to this mounted view.
class ProtectedPostMedia extends StatefulWidget {
  final String path;
  final String? posterPath;
  final PostVideoPool? videoPool;
  final bool video;
  final AuthService? auth;
  final BoxFit fit;
  final bool resizeToDisplay;
  final bool active;
  final ScrollController? scrollController;
  final HomePostMediaStore? homeStore;
  final String mediaVersion;
  const ProtectedPostMedia({
    super.key,
    required this.path,
    this.posterPath,
    this.videoPool,
    this.video = false,
    this.auth,
    this.fit = BoxFit.cover,
    this.resizeToDisplay = false,
    this.active = true,
    this.scrollController,
    this.homeStore,
    this.mediaVersion = '',
  });
  @override
  State<ProtectedPostMedia> createState() => _ProtectedPostMediaState();
}

class _ProtectedPostMediaState extends State<ProtectedPostMedia> {
  String get _key => PostMediaDiagnostics.key(widget.path);
  String? _lastStage;
  VideoPlayerController _createPlayer(Uri uri, Map<String, String> headers) {
    final p = VideoPlayerController.networkUrl(uri, httpHeaders: headers);
    PostMediaDiagnostics.event(
      'player_init',
      _key,
      values: {'player': identityHashCode(p)},
    );
    if (PostMediaDiagnostics.enabled) {
      bool? buffering;
      p.addListener(() {
        if (buffering != p.value.isBuffering) {
          buffering = p.value.isBuffering;
          PostMediaDiagnostics.event(
            'player_buffer',
            _key,
            values: {
              'player': identityHashCode(p),
              'buffering': buffering == true ? 1 : 0,
            },
          );
        }
      });
    }
    return p;
  }

  Future<void> _disposePlayer(VideoPlayerController? p) async {
    if (p == null) return;
    PostMediaDiagnostics.event(
      'player_dispose',
      _key,
      values: {'player': identityHashCode(p)},
    );
    await p.dispose();
  }

  late final AuthService _auth;
  late final String? _owner;
  Uint8List? _bytes;
  ImageProvider? _decodedImage;
  int? _decodeWidth;
  VideoPlayerController? _video;
  bool _error = false;
  bool _initializing = false;
  bool _playWhenReady = false;
  Duration _position = Duration.zero;
  void _releaseVideo() {
    final player = _video;
    if (player == null) return;
    _position = player.value.position;
    _playWhenReady = false;
    _request++;
    _initializing = false;
    _video = null;
    unawaited(_disposePlayer(player));
    if (mounted) setState(() {});
  }

  int _request = 0;
  bool _scrollCheckScheduled = false;
  void _clear() {
    _request++;
    widget.videoPool?.forget(this);
    unawaited(_disposePlayer(_video));
    _position = Duration.zero;
    _playWhenReady = false;
    _initializing = false;
    _video = null;
    _decodedImage?.evict();
    _decodedImage = null;
    _decodeWidth = null;
    if (_bytes != null) MemoryImage(_bytes!).evict();
    _bytes = null;
  }

  @override
  void didUpdateWidget(covariant ProtectedPostMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.homeStore != null) return;
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_scrollChanged);
      widget.scrollController?.addListener(_scrollChanged);
    }
    if (!widget.active)
      unawaited(_pause());
    else if (!oldWidget.active)
      _scheduleWarm();
    if (oldWidget.path != widget.path || oldWidget.video != widget.video) {
      _clear();
      _error = false;
      _load();
    }
  }

  @override
  void initState() {
    super.initState();
    PostMediaDiagnostics.event('widget_mount', _key);
    _auth = widget.auth ?? AuthService.instance;
    _owner = _auth.user?['id']?.toString();
    _auth.addListener(_sessionChanged);
    widget.scrollController?.addListener(_scrollChanged);
    if (widget.homeStore == null) _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.of(context)) unawaited(_pause());
  }

  Future<void> _pause() async {
    final player = _video;
    if (player == null || !player.value.isPlaying) return;
    try {
      await player.pause();
      if (mounted && identical(player, _video)) setState(() {});
    } catch (_) {
      // A concurrent session change/dispose already releases this player.
    }
  }

  void _scheduleWarm() {
    if (!widget.video ||
        widget.posterPath == null ||
        _bytes == null ||
        _video != null ||
        _initializing ||
        !widget.active ||
        widget.videoPool?.hasRoom == false)
      return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _inViewport() && TickerMode.of(context))
        unawaited(_playVideo(warm: true));
    });
  }

  bool _inViewport() {
    final box = context.findRenderObject();
    final viewport = Scrollable.maybeOf(
      context,
      axis: Axis.vertical,
    )?.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (!rect.isFinite) return false;
    if (viewport is RenderBox && viewport.attached && viewport.hasSize)
      return rect.overlaps(viewport.localToGlobal(Offset.zero) & viewport.size);
    return rect.overlaps(Offset.zero & MediaQuery.sizeOf(context));
  }

  void _scrollChanged() {
    _scheduleWarm();
    if (_video?.value.isPlaying != true || _scrollCheckScheduled) return;
    _scrollCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCheckScheduled = false;
      if (!mounted || _video?.value.isPlaying != true) return;
      final box = context.findRenderObject();
      final viewport = Scrollable.maybeOf(
        context,
        axis: Axis.vertical,
      )?.context.findRenderObject();
      if (box is! RenderBox ||
          viewport is! RenderBox ||
          !box.attached ||
          !viewport.attached ||
          !box.hasSize ||
          !viewport.hasSize) {
        unawaited(_pause());
        return;
      }
      final mediaRect = box.localToGlobal(Offset.zero) & box.size;
      final viewportRect = viewport.localToGlobal(Offset.zero) & viewport.size;
      if (!mediaRect.isFinite || !mediaRect.overlaps(viewportRect)) {
        unawaited(_pause());
      }
    });
  }

  void _sessionChanged() {
    if (_auth.user?['id']?.toString() != _owner) {
      _clear();
      if (mounted) {
        setState(() {
          _bytes = null;
          _error = true;
        });
      }
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      if (widget.video && widget.posterPath != null) {
        final bytes = await _auth.postImage(widget.posterPath!);
        if (mounted && request == _request) {
          setState(() => _bytes = bytes);
          _scheduleWarm();
        }
        return;
      }
      if (widget.video) {
        final access = await _auth.postMediaAccess(widget.path);
        if (!mounted || request != _request) return;
        final player = _createPlayer(access.uri, access.headers);
        _video = player;
        await player.initialize();
        if (!mounted || request != _request) {
          return;
        }
      } else {
        final bytes = await _auth.postImage(widget.path);
        if (mounted && request == _request) _bytes = bytes;
      }
      if (mounted &&
          request == _request &&
          _auth.user?['id']?.toString() == _owner)
        setState(() {});
    } catch (_) {
      if (mounted && request == _request) setState(() => _error = true);
    }
  }

  Future<void> _playVideo({bool warm = false}) async {
    if (!widget.active || !TickerMode.of(context)) return;
    if (!warm) _playWhenReady = true;
    if (_initializing) return;
    if (warm &&
        (_video != null ||
            widget.videoPool?.hasRoom == false ||
            !_inViewport()))
      return;
    if (_video?.value.isInitialized == true) {
      if (warm) return;
      widget.videoPool?.acquire(this, _releaseVideo);
      setState(() {
        _video!.value.isPlaying ? _video!.pause() : _video!.play();
      });
      return;
    }
    setState(() {
      _initializing = true;
      _error = false;
    });
    final request = ++_request;
    try {
      final access = await _auth.postMediaAccess(widget.path);
      if (!mounted ||
          request != _request ||
          _auth.user?['id']?.toString() != _owner)
        return;
      if (warm && !_playWhenReady && widget.videoPool?.hasRoom == false) {
        setState(() => _initializing = false);
        return;
      }
      widget.videoPool?.acquire(this, _releaseVideo);
      final player = _createPlayer(access.uri, access.headers);
      _video = player;
      await player.initialize();
      if (!mounted || request != _request) return;
      if (_position > Duration.zero) await player.seekTo(_position);
      if (!mounted || request != _request) return;
      if (_playWhenReady &&
          widget.active &&
          TickerMode.of(context) &&
          _inViewport())
        await player.play();
      if (mounted && request == _request) setState(() => _initializing = false);
    } catch (_) {
      if (mounted && request == _request) {
        widget.videoPool?.forget(this);
        final failed = _video;
        _video = null;
        if (failed != null) unawaited(_disposePlayer(failed));
        setState(() {
          _initializing = false;
          _error = true;
        });
      }
    }
  }

  @override
  void dispose() {
    PostMediaDiagnostics.event('widget_dispose', _key);
    _auth.removeListener(_sessionChanged);
    widget.scrollController?.removeListener(_scrollChanged);
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    PostMediaDiagnostics.event('widget_build', _key, sampled: true);
    if (widget.homeStore != null) {
      return RetainedHomePostMedia(
        store: widget.homeStore!,
        path: widget.path,
        version: widget.mediaVersion,
        poster: widget.posterPath,
        video: widget.video,
        active: widget.active,
        fit: widget.fit,
        scroll: widget.scrollController,
      );
    }
    final stage = _error
        ? 'error'
        : widget.video
        ? (_video?.value.isInitialized == true
              ? 'video'
              : _initializing && _playWhenReady
              ? 'video_spinner'
              : _bytes == null
              ? 'cover_wait'
              : 'cover')
        : _bytes == null
        ? 'image_spinner'
        : 'image';
    if (stage != _lastStage) {
      _lastStage = stage;
      PostMediaDiagnostics.event('display_$stage', _key);
    }
    if (_error && (!widget.video || widget.posterPath == null))
      return const ColoredBox(
        color: Color(0xFFE8EDF6),
        child: Center(
          child: Icon(LucideIcons.image, color: AppColors.grayText),
        ),
      );
    final player = _video;
    if (widget.video && player?.value.isInitialized == true) {
      return GestureDetector(
        onTap: _playVideo,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: FittedBox(
                fit: widget.fit,
                child: SizedBox(
                  width: player!.value.size.width,
                  height: player.value.size.height,
                  child: VideoPlayer(player),
                ),
              ),
            ),
            if (!player.value.isPlaying)
              const Icon(LucideIcons.play, color: Colors.white, size: 38),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                player,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppColors.primaryIcon,
                  bufferedColor: AppColors.grayBorder,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (widget.video && widget.posterPath != null) {
      return GestureDetector(
        onTap: _playVideo,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            if (_bytes != null)
              Image.memory(_bytes!, fit: widget.fit, cacheWidth: 600)
            else
              const ColoredBox(color: Color(0xFFE8EDF6)),
            if (_initializing && _playWhenReady)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else
              const Icon(LucideIcons.play, color: Colors.white, size: 38),
          ],
        ),
      );
    }
    if (_bytes != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = widget.resizeToDisplay && constraints.maxWidth.isFinite
              ? (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                    .ceil()
                    .clamp(1, 16384)
              : null;
          if (_decodedImage == null || _decodeWidth != width) {
            _decodedImage?.evict();
            PostMediaDiagnostics.event(
              'image_decode',
              _key,
              values: {'width': width ?? 0, 'bytes': _bytes!.length},
            );
            _decodeWidth = width;
            _decodedImage = ResizeImage.resizeIfNeeded(
              width,
              null,
              MemoryImage(_bytes!),
            );
          }
          return Image(
            image: _decodedImage!,
            fit: widget.fit,
            gaplessPlayback: false,
          );
        },
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
