import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../network/api_exception.dart';
import 'session_store.dart';

/// Flutter chỉ gọi API; không giữ mật khẩu PostgreSQL hoặc mật khẩu người dùng.
class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService();
  final http.Client _client;
  final SessionStore _store;
  final String? _baseUrl;
  String? _accessToken;
  String? _refreshToken;
  bool _remember = false;
  Map<String, dynamic>? _user;
  Future<void>? _refreshing;
  int _generation = 0;

  AuthService({http.Client? client, SessionStore? store, String? baseUrl})
    : _client = client ?? http.Client(),
      _store = store ?? SecureSessionStore(),
      _baseUrl = baseUrl;

  Map<String, dynamic>? get user =>
      _user == null ? null : Map.unmodifiable(_user!);
  bool get signedIn => _user != null && _accessToken != null;
  bool get onboardingCompleted => _user?['onboardingCompleted'] == true;

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final bases = _baseUrl == null ? ApiConfig.candidateBaseUrls : [_baseUrl];
    String? lastNetworkError;
    for (final base in bases) {
      final url = Uri.parse('$base$path');
      if (kReleaseMode && url.scheme != 'https') {
        throw const ApiException(
          0,
          'CONFIG_ERROR',
          'Bản phát hành yêu cầu kết nối HTTPS.',
        );
      }
      final request = http.Request(method, url)
        ..headers['Accept'] = 'application/json';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json; charset=utf-8';
        request.body = jsonEncode(body);
      }
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      try {
        return await (() async => http.Response.fromStream(
          await _client.send(request),
        ))().timeout(const Duration(seconds: 6));
      } on TimeoutException catch (error) {
        lastNetworkError = error.message ?? 'Request timed out';
      } on http.ClientException catch (error) {
        lastNetworkError = error.message;
      }
    }
    throw ApiException(
      0,
      'NETWORK_ERROR',
      'Không kết nối được máy chủ. Hãy chạy scripts/run-android-dev.ps1 để app tự nhận IP LAN của PC, hoặc kiểm tra backend GoMate và cổng 8081.'
          '${lastNetworkError == null ? '' : '\n$lastNetworkError'}',
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> result = {};
    try {
      if (response.bodyBytes.isNotEmpty) {
        result =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {
      throw ApiException(
        response.statusCode,
        'INVALID_RESPONSE',
        'Máy chủ trả dữ liệu không hợp lệ. Kiểm tra địa chỉ API.',
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return result;
    final code = result['code'] as String? ?? 'HTTP_ERROR';
    final message = switch (code) {
      'INVALID_CREDENTIALS' => 'Email hoặc mật khẩu không đúng.',
      'ACCOUNT_LOCKED' => 'Tài khoản đã bị khóa.',
      'EMAIL_TAKEN' => 'Email này đã được đăng ký.',
      'NICKNAME_TAKEN' => 'Biệt danh đã có người sử dụng.',
      'DATA_CONFLICT' => 'Email hoặc biệt danh đã có người sử dụng.',
      'UNAUTHORIZED' => 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
      'RATE_LIMITED' => 'Bạn thao tác quá nhiều. Vui lòng đợi một phút.',
      'VALIDATION_ERROR' =>
        'Thông tin chưa hợp lệ. Kiểm tra email, biệt danh và mật khẩu.',
      _ => result['message'] as String? ?? 'Không thể thực hiện yêu cầu.',
    };
    throw ApiException(response.statusCode, code, message);
  }

  Future<void> _persist() async {
    if (_remember) {
      await _store.write(
        jsonEncode({
          'accessToken': _accessToken,
          'refreshToken': _refreshToken,
        }),
      );
    }
  }

  Future<void> _accept(Map<String, dynamic> data, bool remember) async {
    final access = data['accessToken'];
    final refresh = data['refreshToken'];
    if (access is! String || refresh is! String || data['user'] is! Map) {
      throw const ApiException(
        0,
        'INVALID_RESPONSE',
        'Dữ liệu đăng nhập không hợp lệ.',
      );
    }
    await _store.clear();
    _generation++;
    _accessToken = access;
    _refreshToken = refresh;
    _remember = remember;
    _user = Map<String, dynamic>.from(data['user'] as Map);
    try {
      await _persist();
    } catch (_) {
      // Không báo đăng ký thất bại khi tài khoản đã được tạo: giữ phiên trong RAM.
      _remember = false;
    }
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final response = await _send(
      'POST',
      '/auth/register',
      body: {
        'email': email.trim(),
        'password': password,
        'nickname': nickname.trim(),
      },
    );
    await _accept(_decode(response), false);
  }

  Future<void> login({
    required String email,
    required String password,
    required bool remember,
  }) async {
    final response = await _send(
      'POST',
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
    );
    await _accept(_decode(response), remember);
  }

  Future<void> google(String idToken, {bool remember = true}) async {
    await _accept(
      _decode(await _send('POST', '/auth/google', body: {'idToken': idToken})),
      remember,
    );
  }

  Future<void> linkGoogle(String idToken) async {
    _user = await request(
      'POST',
      '/auth/google/link',
      body: {'idToken': idToken},
    );
    notifyListeners();
  }

  Future<bool> restore() async {
    final saved = await _store.read();
    if (saved == null) return false;
    try {
      final data = jsonDecode(saved) as Map<String, dynamic>;
      _accessToken = data['accessToken'] as String;
      _refreshToken = data['refreshToken'] as String;
      _remember = true;
    } catch (_) {
      await clearLocal();
      return false;
    }
    try {
      await loadProfile();
      return true;
    } on ApiException catch (error) {
      if (error.status == 401 || error.status == 403) {
        await clearLocal();
        return false;
      }
      rethrow; // Mất mạng không xóa phiên đã lưu; màn mở app cho phép thử lại.
    }
  }

  Future<void> _refreshOnce() async {
    if (_refreshing != null) return _refreshing!;
    final task = _rotate();
    _refreshing = task;
    try {
      await task;
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _rotate() async {
    final generation = _generation;
    final refresh = _refreshToken;
    if (refresh == null) {
      throw const ApiException(401, 'UNAUTHORIZED', 'Vui lòng đăng nhập lại.');
    }
    final result = _decode(
      await _send('POST', '/auth/refresh', body: {'refreshToken': refresh}),
    );
    if (generation != _generation) {
      throw const ApiException(401, 'UNAUTHORIZED', 'Phiên đã thay đổi.');
    }
    _accessToken = result['accessToken'] as String;
    _refreshToken = result['refreshToken'] as String;
    _user = Map<String, dynamic>.from(result['user'] as Map);
    try {
      await _persist();
    } catch (_) {
      _remember = false;
    }
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final sentToken = _accessToken;
    if (sentToken == null) {
      throw const ApiException(401, 'UNAUTHORIZED', 'Vui lòng đăng nhập.');
    }
    final generation = _generation;
    var response = await _send(method, path, body: body, token: sentToken);
    if (generation != _generation) {
      throw const ApiException(401, 'UNAUTHORIZED', 'Phiên đã thay đổi.');
    }
    try {
      if (response.statusCode == 401) {
        if (sentToken == _accessToken) await _refreshOnce();
        response = await _send(method, path, body: body, token: _accessToken);
      }
      if (generation != _generation) {
        throw const ApiException(401, 'UNAUTHORIZED', 'Phiên đã thay đổi.');
      }
      return _decode(response);
    } on ApiException catch (error) {
      if (error.status == 401 && generation == _generation) await clearLocal();
      rethrow;
    }
  }

  Future<void> loadProfile() async {
    _user = await request('GET', '/users/me');
    notifyListeners();
  }

  Future<void> saveOnboarding(List<String> codes) async {
    _user = await request(
      'PUT',
      '/users/me/onboarding',
      body: {'optionCodes': codes},
    );
    notifyListeners();
  }

  Future<void> logout() async {
    // Chỉ thoát khi server đã thu hồi phiên; mất mạng hiển thị lỗi để thử lại.
    try {
      await request('POST', '/auth/logout');
    } on ApiException catch (error) {
      if (error.status != 401) rethrow;
    }
    await clearLocal();
  }

  Future<void> clearLocal() async {
    _generation++;
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    _remember = false;
    await _store.clear();
    notifyListeners();
  }
}
