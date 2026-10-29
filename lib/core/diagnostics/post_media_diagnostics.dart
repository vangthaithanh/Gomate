import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Opt-in lifecycle counters. Never log URLs, headers, payloads or private bytes.
class PostMediaDiagnostics {
  static const enabled = bool.fromEnvironment('POST_MEDIA_DIAGNOSTICS');
  static final _counts = <String, int>{};
  static final _clock = Stopwatch()..start();
  static String key(String path) {
    final m = RegExp(
      r'^/(posts|comments)/([0-9]+)/media/([0-9a-fA-F-]{36})(/thumbnail)?$',
    ).firstMatch(path);
    return m == null
        ? 'metadata'
        : '${m[1]}:${m[2]}:${m[3]}:${m[4] == null ? 'original' : 'thumbnail'}';
  }

  static void event(
    String event,
    String key, {
    Map<String, num> values = const {},
    bool sampled = false,
  }) {
    if (!enabled) return;
    final n = (_counts[event] ?? 0) + 1;
    _counts[event] = n;
    if (sampled && n > 1 && (n & (n - 1)) != 0) return;
    debugPrint(
      '[PostMedia] ${jsonEncode({'ms': _clock.elapsedMilliseconds, 'event': event, 'key': key, ...values, 'n': n})}',
    );
  }

  static void snapshot(String reason) {
    if (enabled) {
      debugPrint(
        '[PostMedia] ${jsonEncode({'ms': _clock.elapsedMilliseconds, 'snapshot': reason, 'counts': _counts})}',
      );
    }
  }
}
