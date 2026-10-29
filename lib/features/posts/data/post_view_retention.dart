import 'dart:math' as math;
import '../../../core/diagnostics/post_media_diagnostics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Metadata only. The original mounted widgets continue owning private bytes.
class PostViewRetention extends ChangeNotifier {
  final int maxPosts;
  final int maxEstimatedBytes;
  final int maxVideos;
  PostViewRetention({
    this.maxPosts = 6,
    this.maxEstimatedBytes = 64 * 1024 * 1024,
    this.maxVideos = 2,
  });
  final _entries = <Object, PostRetentionCost>{};
  bool _scheduled = false;
  bool _disposed = false;
  bool contains(Object owner) => _entries.containsKey(owner);
  int get length => _entries.length;
  int get estimatedBytes => _entries.values.fold(0, (n, c) => n + c.bytes);
  int get videos => _entries.values.fold(0, (n, c) => n + c.videos);

  void retain(Object owner, PostRetentionCost cost) {
    if (_disposed) return;
    _entries.remove(owner);
    if (cost.bytes <= maxEstimatedBytes && cost.videos <= maxVideos) {
      _entries[owner] = cost;
    }
    while (_entries.length > maxPosts ||
        estimatedBytes > maxEstimatedBytes ||
        videos > maxVideos) {
      PostMediaDiagnostics.event(
        'tile_evict',
        'home',
        values: {'entries': _entries.length, 'bytes': estimatedBytes},
      );
      _entries.remove(_entries.keys.first);
    }
    _changed();
  }

  void release(Object owner) {
    if (!_disposed && _entries.remove(owner) != null) _changed();
  }

  void clear() {
    if (_disposed || _entries.isEmpty) return;
    _entries.clear();
    _changed();
  }

  void _changed() {
    if (_scheduled) return;
    _scheduled = true;
    // A new list child can evict a sibling while the sliver is building.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_disposed) notifyListeners();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    _entries.clear();
    super.dispose();
  }
}

@immutable
class PostRetentionCost {
  final int bytes;
  final int videos;
  const PostRetentionCost(this.bytes, this.videos);

  factory PostRetentionCost.fromMedia(
    List<dynamic> media,
    double physicalWidth,
  ) {
    int bytes = 0, videos = 0;
    for (final m in media.take(12)) {
      if (m['kind'] == 'VIDEO') {
        // Home keeps only the cover here; decoders have their own two-slot pool.
        bytes += 2 * 1024 * 1024;
      } else {
        final w = (m['width'] as num?)?.toDouble() ?? physicalWidth;
        final h = (m['height'] as num?)?.toDouble() ?? physicalWidth;
        final scale = w > 0 ? math.min(1.0, physicalWidth / w) : 1.0;
        bytes +=
            ((m['bytes'] as num?)?.toInt() ?? 2 * 1024 * 1024) +
            (math.max(1, w) * math.max(1, h) * scale * scale * 4).ceil();
      }
    }
    return PostRetentionCost(bytes, videos);
  }
}
