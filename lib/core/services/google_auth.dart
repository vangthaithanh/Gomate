import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../network/api_exception.dart';

/// Giữ interface GoogleAuth.idToken() của mobile cũ, nhưng trả Firebase ID token.
/// Backend GoMate phát accessToken/refreshToken và quản lý phiên sau bước này.
class GoogleAuth {
  static Future<void>? _initializing;
  static bool _busy = false;

  static Future<void> _initialize() async {
    // Android đọc cấu hình từ google-services.json qua Google Services plugin.
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    await GoogleSignIn.instance.initialize(
      serverClientId: webClientId.isEmpty ? null : webClientId,
    );
  }

  static Future<String?> idToken() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const ApiException(
        0,
        'PLATFORM_UNSUPPORTED',
        'Bản tích hợp này dùng Android. Trong Android Studio hãy chọn máy ảo Android có Google Play.',
      );
    }
    if (_busy) return null;
    _busy = true;
    try {
      _initializing ??= _initialize();
      try {
        await _initializing;
      } catch (_) {
        _initializing = null;
        rethrow;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final googleToken = account.authentication.idToken;
      if (googleToken == null || googleToken.isEmpty) {
        throw const ApiException(
          0,
          'GOOGLE_TOKEN_MISSING',
          'Chưa lấy được Google token. Kiểm tra google-services.json và SHA-1.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: googleToken);
      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      // Token gửi backend lấy từ Firebase user, không gửi googleToken ở trên.
      final firebaseToken = await result.user?.getIdToken(true);
      if (firebaseToken == null || firebaseToken.isEmpty) {
        throw const ApiException(
          0,
          'FIREBASE_TOKEN_MISSING',
          'Firebase chưa cấp ID token. Vui lòng đăng nhập Google lại.',
        );
      }
      return firebaseToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw const ApiException(
        0,
        'GOOGLE_FAILED',
        'Không đăng nhập Google được. Kiểm tra package Android, SHA-1/SHA-256 và google-services.json.',
      );
    } on FirebaseAuthException catch (error) {
      final message = switch (error.code) {
        'operation-not-allowed' =>
          'Hãy bật Google trong Firebase Authentication > Sign-in method.',
        'user-disabled' => 'Tài khoản Firebase đã bị khóa.',
        'network-request-failed' =>
          'Không kết nối được Firebase. Kiểm tra Internet rồi thử lại.',
        'account-exists-with-different-credential' =>
          'Email này đã dùng phương thức đăng nhập Firebase khác.',
        _ =>
          'Firebase chưa xác thực được Google. Kiểm tra hai bên dùng cùng Firebase project.',
      };
      throw ApiException(0, 'FIREBASE_AUTH_FAILED', message);
    } on FirebaseException {
      throw const ApiException(
        0,
        'FIREBASE_CONFIG_ERROR',
        'Chưa cấu hình Firebase Android. Kiểm tra google-services.json và Google Services plugin rồi build lại app.',
      );
    } finally {
      // Firebase chỉ dùng để xác minh Google. Phiên lưu lâu dài do GoMate quản lý.
      // signOut ở client không thu hồi ID token vừa lấy, backend vẫn xác minh được.
      await _clearProviderSession();
      _busy = false;
    }
  }

  static Future<void> _clearProviderSession() async {
    try {
      if (Firebase.apps.isNotEmpty) await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Lỗi dọn phiên provider không được che mất kết quả đăng nhập chính.
    }
    try {
      if (_initializing != null) await GoogleSignIn.instance.signOut();
    } catch (_) {
      // GoMate chỉ lưu phiên do backend phát hành.
    }
  }
}
