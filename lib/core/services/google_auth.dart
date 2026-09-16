import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../network/api_exception.dart';

class GoogleAuth {
  static const _defaultWebClientId =
      '980847602126-87i5jn0v2e88pkuns02ej260mfqbd9bl.apps.googleusercontent.com';

  static Future<void>? _initializing;
  static Future<String?> idToken() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      throw const ApiException(
        0,
        'PLATFORM_UNSUPPORTED',
        'Nút Google của bản này dùng trên Android/iOS/macOS. Trên Windows hãy chạy ứng dụng bằng máy ảo Android.',
      );
    }
    const configuredServerId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    final serverId = configuredServerId.isEmpty
        ? _defaultWebClientId
        : configuredServerId;
    const iosId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
    if (serverId.isEmpty) {
      throw const ApiException(
        0,
        'CONFIG_ERROR',
        'Chưa cấu hình GOOGLE_WEB_CLIENT_ID khi chạy Flutter.',
      );
    }
    try {
      _initializing ??= GoogleSignIn.instance.initialize(
        serverClientId: serverId,
        clientId: iosId.isEmpty ? null : iosId,
      );
      await _initializing;
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) {
        throw const ApiException(
          0,
          'GOOGLE_TOKEN_MISSING',
          'Google chưa cấp ID token. Kiểm tra Web Client ID.',
        );
      }
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;

      _initializing = null;

      throw ApiException(
        0,
        'GOOGLE_FAILED',
        'Google lỗi: ${e.code.name}\n'
            '${e.description ?? ''}\n'
            '${e.details ?? ''}',
      );
    }
  }
}
