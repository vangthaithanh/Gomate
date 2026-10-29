import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';
import '../../../core/diagnostics/post_media_diagnostics.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/auth_service.dart';

/// Home owns these resources, not its lazily mounted cards. No disk/HTTP cache.
class HomePostMediaStore {
  final AuthService auth;
  final int maxPosts, maxEntries, maxImageBytes, maxPlayers;
  final Duration idleTtl;
  final DateTime Function() now;
  final void Function(int)? onUnavailable;
  HomePostMediaStore({
    required this.auth,
    this.maxPosts = 8,
    this.maxEntries = 16,
    this.maxImageBytes = 32 * 1024 * 1024,
    this.maxPlayers = 3,
    this.idleTtl = const Duration(minutes: 15),
    DateTime Function()? now,
    this.onUnavailable,
  }) : now = now ?? DateTime.now {
    _owner = auth.user?['id']?.toString();
    auth.addListener(_session);
  }
  String? _owner;
  bool _disposed = false, enabled = true;
  final _entries = <String, HomeMediaEntry>{};
  final _players = <HomeMediaEntry>[];
  Future<void> _disposals = Future.value();
  int get length => _entries.length;
  int get playerCount => _players.length;
  int get imageBytes => _entries.values.fold(0, (n, e) => n + e.imageBytes);

  static String identity(
    String path,
    bool video,
    String? poster,
    String version,
  ) => '$path|$video|$poster|$version';
  static String version(Map<dynamic, dynamic> m) =>
      '${m['version'] ?? ''}:${m['bytes']}:${m['width']}:${m['height']}:${m['durationMs']}';

  HomeMediaEntry acquire(
    String path,
    bool video,
    String? poster,
    String version,
  ) {
    prune();
    final key = '${_owner ?? ''}|${identity(path, video, poster, version)}';
    final existing = _entries.remove(key);
    if (existing != null) {
      existing.touched = now();
      _entries[key] = existing;
      PostMediaDiagnostics.event('retention_hit', existing.logKey);
      return existing;
    }
    final entry = HomeMediaEntry._(this, key, path, video, poster, version);
    if (_disposed || _owner == null) {
      entry._release();
      return entry;
    }
    _entries[key] = entry;
    PostMediaDiagnostics.event('retention_miss', entry.logKey);
    _trim(protect: entry);
    return entry;
  }

  void touch(HomeMediaEntry e) {
    if (!e.released) {
      e.touched = now();
      if (_players.remove(e)) _players.add(e);
    }
  }

  void setEnabled(bool value) {
    if (enabled != value) {
      PostMediaDiagnostics.event(
        value ? 'home_media_activate' : 'home_media_pause',
        'home',
        values: {
          'players': playerCount,
          'entries': length,
          'decodedBytes': imageBytes,
        },
      );
    }
    enabled = value;
    if (!value) {
      for (final e in _entries.values) {
        e.visible = false;
        e.pause();
      }
    } else {
      prune();
    }
  }

  void reconcile(List<Map<String, dynamic>> posts) {
    final allowed = <String>{};
    for (final p in posts) {
      for (final raw in p['media'] as List? ?? const []) {
        final m = raw as Map;
        allowed.add(
          '${_owner ?? ''}|${identity(m['url'] as String, m['kind'] == 'VIDEO', m['thumbnailUrl'] as String?, version(m))}',
        );
      }
    }
    for (final e in _entries.values.toList()) {
      if (!allowed.contains(e.key)) _evict(e, 'permission_or_identity');
    }
  }

  void revoke(int postId) {
    for (final e in _entries.values.toList()) {
      if (e.postId == postId) _evict(e, 'revoke');
    }
  }

  void prune() {
    final cutoff = now().subtract(idleTtl);
    for (final e in _entries.values.toList()) {
      if (!e.visible && e.touched.isBefore(cutoff)) _evict(e, 'ttl');
    }
  }

  void _trim({HomeMediaEntry? protect}) {
    while (_entries.length > maxEntries ||
        imageBytes > maxImageBytes ||
        _entries.values.map((e) => e.postId).toSet().length > maxPosts) {
      final candidates = _entries.values.where((e) => e != protect).toList()
        ..sort((a, b) {
          if (a.visible != b.visible) return a.visible ? 1 : -1;
          return a.touched.compareTo(b.touched);
        });
      if (candidates.isEmpty) {
        if (protect != null) _evict(protect, 'oversized');
        break;
      }
      _evict(candidates.first, 'budget');
    }
    PostMediaDiagnostics.event(
      'retention_budget',
      'home',
      values: {
        'entries': length,
        'decodedBytes': imageBytes,
        'players': playerCount,
      },
      sampled: true,
    );
  }

  bool reservePlayer(HomeMediaEntry e, {required bool warm}) {
    if (!enabled || e.released) return false;
    if (_players.remove(e)) {
      _players.add(e);
      return true;
    }
    if (_players.length >= maxPlayers) {
      if (warm) return false;
      final oldest = _players.removeAt(0);
      oldest._releasePlayer();
    }
    _players.add(e);
    return true;
  }

  void playOnly(HomeMediaEntry entry) {
    for (final e in _players.toList()) {
      if (e != entry) e.pause();
    }
  }

  void _disposePlayer(VideoPlayerController player, String key) {
    // Pause immediately; serialize native releases before allocating a decoder.
    unawaited(player.pause().catchError((_) {}));
    _disposals = _disposals.then((_) async {
      PostMediaDiagnostics.event(
        'player_dispose',
        key,
        values: {'player': identityHashCode(player)},
      );
      try {
        await player.dispose();
      } catch (_) {}
    });
  }

  void _denied(HomeMediaEntry e, Object error) {
    if (error is ApiException && [401, 403, 404].contains(error.status)) {
      if (error.status == 401) {
        clear();
      } else {
        revoke(e.postId);
      }
      onUnavailable?.call(e.postId);
    }
  }

  void _evict(HomeMediaEntry e, String reason) {
    _entries.remove(e.key);
    PostMediaDiagnostics.event('retention_evict_$reason', e.logKey);
    e._release();
  }

  void clear() {
    for (final e in _entries.values.toList()) {
      _evict(e, 'clear');
    }
  }

  void _session() {
    final owner = auth.user?['id']?.toString();
    if (_owner != owner) {
      clear();
      _owner = owner;
    }
  }

  void dispose() {
    _disposed = true;
    auth.removeListener(_session);
    clear();
  }
}

class HomeMediaEntry extends ChangeNotifier {
  final HomePostMediaStore store;
  final String key, path, version;
  final bool video;
  final String? poster;
  HomeMediaEntry._(
    this.store,
    this.key,
    this.path,
    this.video,
    this.poster,
    this.version,
  ) : touched = store.now();
  int get postId => int.tryParse(path.split('/').elementAtOrNull(2) ?? '') ?? 0;
  String get logKey => PostMediaDiagnostics.key(path);
  DateTime touched;
  ui.Image? image;
  VideoPlayerController? player;
  bool released = false, error = false, initializing = false, wantsPlay = false;
  bool visible = false;
  Duration position = Duration.zero;
  int _generation = 0;
  bool _scheduled = false;
  Future<void>? _loadingImage, _loadingPlayer;
  int get imageBytes => image == null ? 0 : image!.width * image!.height * 4;

  void _changed() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      notifyListeners();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  Future<void> loadImage() => _loadingImage ??= _image();
  void retryImage() {
    if (!released && image == null && error) {
      error = false;
      _loadingImage = null;
      unawaited(loadImage());
    }
  }

  Future<void> _image() async {
    if (released || image != null) return;
    ui.Codec? codec;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      final bytes = await store.auth.postImage(poster ?? path);
      if (released) return;
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      // Bound both dimensions, including extremely tall/panoramic source files.
      final scale = math.min(
        1.0,
        math.min(
          600 / descriptor.width,
          math.sqrt(1000000 / (descriptor.width * descriptor.height)),
        ),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      final decoded = (await codec.getNextFrame()).image;
      if (released) {
        decoded.dispose();
        return;
      }
      image = decoded;
      error = false;
      PostMediaDiagnostics.event(
        'image_decode',
        logKey,
        values: {'width': decoded.width, 'decodedBytes': imageBytes},
      );
      store._trim(protect: this);
      _changed();
    } catch (e) {
      if (!released) {
        error = true;
        store._denied(this, e);
        _changed();
      }
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  Future<void> prepare({bool warm = true}) {
    if (released || !store.enabled || !video) return Future.value();
    if (!warm) wantsPlay = true;
    if (player?.value.isInitialized == true) return Future.value();
    if (_loadingPlayer != null) return _loadingPlayer!;
    if (!store.reservePlayer(this, warm: warm)) return Future.value();
    return _loadingPlayer ??= _prepare();
  }

  Future<void> _prepare() async {
    initializing = true;
    error = false;
    _changed();
    final request = _generation;
    try {
      await store._disposals;
      final access = await store.auth.postMediaAccess(path);
      if (released || request != _generation) return;
      final p = VideoPlayerController.networkUrl(
        access.uri,
        httpHeaders: access.headers,
      );
      player = p;
      PostMediaDiagnostics.event(
        'player_init',
        logKey,
        values: {'player': identityHashCode(p)},
      );
      bool? buffering;
      p.addListener(() {
        if (released || player != p) return;
        if (buffering != p.value.isBuffering) {
          buffering = p.value.isBuffering;
          PostMediaDiagnostics.event(
            'player_buffer',
            logKey,
            values: {'buffering': buffering == true ? 1 : 0},
          );
        }
        if (p.value.hasError && !error) {
          error = true;
          final status = RegExp(
            r'(?:response code:|status code[:=]?)\s*(401|403|404)',
            caseSensitive: false,
          ).firstMatch(p.value.errorDescription ?? '');
          if (status != null) {
            store._denied(
              this,
              ApiException(int.parse(status[1]!), 'POST_MEDIA_UNAVAILABLE', ''),
            );
          }
          _changed();
        }
      });
      await p.initialize();
      if (released || request != _generation || player != p) return;
      if (position > Duration.zero) await p.seekTo(position);
      if (!released &&
          request == _generation &&
          wantsPlay &&
          visible &&
          store.enabled) {
        store.playOnly(this);
        await p.play();
      }
    } catch (e) {
      if (!released && request == _generation) {
        error = true;
        store._denied(this, e);
        _releasePlayer();
      }
    } finally {
      if (!released && request == _generation) {
        initializing = false;
        _changed();
      }
      if (request == _generation) _loadingPlayer = null;
    }
  }

  Future<void> toggle() async {
    if (released || !visible || !store.enabled) return;
    store.touch(this);
    try {
      // Retained decoders cannot update native HTTP headers in place.
      final retained = player;
      if (retained?.value.isInitialized == true && !retained!.value.isPlaying) {
        final access = await store.auth.postMediaAccess(path);
        if (released || !visible || !store.enabled) return;
        if (identical(player, retained) &&
            (retained.httpHeaders['Authorization'] !=
                    access.headers['Authorization'] ||
                retained.dataSource != access.uri.toString())) {
          PostMediaDiagnostics.event('player_credential_renew', logKey);
          _releasePlayer();
        }
      }
      if (player?.value.isInitialized == true) {
        final p = player!;
        if (p.value.isPlaying) {
          pause();
        } else {
          wantsPlay = true;
          store.playOnly(this);
          if (p.value.position >= p.value.duration)
            await p.seekTo(Duration.zero);
          if (!released && player == p && store.enabled && visible) {
            await p.play();
          }
        }
        _changed();
      } else {
        await prepare(warm: false);
      }
    } catch (e) {
      if (!released) {
        error = true;
        store._denied(this, e);
        _releasePlayer();
      }
    }
  }

  void pause() {
    wantsPlay = false;
    final p = player;
    if (p != null && p.value.isPlaying) {
      unawaited(p.pause().catchError((_) {}));
      _changed();
    }
  }

  void _releasePlayer() {
    _generation++;
    final p = player;
    if (p != null) {
      position = p.value.position;
      store._disposePlayer(p, logKey);
    }
    player = null;
    store._players.remove(this);
    initializing = wantsPlay = false;
    _loadingPlayer = null;
    _changed();
  }

  void _release() {
    if (released) return;
    released = true;
    _releasePlayer();
    image?.dispose();
    image = null;
    _changed();
  }
}
