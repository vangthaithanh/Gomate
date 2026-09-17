import 'package:flutter/foundation.dart';

class ApiConfig {
  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'/+$'), '');

  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return _normalize(configured);
    if (kReleaseMode) {
      throw StateError(
        'Bản release cần --dart-define=API_BASE_URL=https://.../api/v1',
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api/v1';
    }
    return 'http://localhost:8080/api/v1';
  }

  static List<String> get candidateBaseUrls {
    const configuredMany = String.fromEnvironment('API_BASE_URLS');
    if (configuredMany.isNotEmpty) {
      return configuredMany
          .split(',')
          .map(_normalize)
          .where((url) => url.isNotEmpty)
          .toList(growable: false);
    }

    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) {
      return [_normalize(configured)];
    }

    final primary = baseUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return [primary];
    }
    return [primary];
  }
}
