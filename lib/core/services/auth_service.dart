import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';
import '../diagnostics/post_media_diagnostics.dart';
import '../network/api_exception.dart';
import 'session_store.dart';

/// Flutter chỉ gọi API; không giữ mật khẩu PostgreSQL hoặc mật khẩu người dùng.
class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService();
  final http.Client _client;
  final SessionStore _store;
  final String? _baseUrl;
  String? _postApiBase;
  String? _accessToken;
  String? _refreshToken;
  bool _remember = false;
  Map<String, dynamic>? _user;
  Future<void>? _refreshing;
  int _generation = 0;
  int _credentialRevision = 0;
  final beforeLogout = <Future<void> Function()>[];

  AuthService({http.Client? client, SessionStore? store, String? baseUrl})
    : _client = client ?? http.Client(),
      _store = store ?? SecureSessionStore(),
      _baseUrl = baseUrl;

  Map<String, dynamic>? get user =>
      _user == null ? null : Map.unmodifiable(_user!);
  bool get signedIn => _user != null && _accessToken != null;
  int get credentialRevision => _credentialRevision;
  int get sessionGeneration => _generation;
  bool get onboardingCompleted => _user?['onboardingCompleted'] == true;

  /// Authenticated streaming uses the same API candidates and refresh session.
  /// The caller owns this dedicated client so logout can abort the open socket.
  Future<http.StreamedResponse> openEventStream(
    http.Client client, {
    String path = '/notifications/stream',
  }) async {
    if (path != '/notifications/stream' &&
        !RegExp(r'^/trips/[0-9a-fA-F-]{36}/locations/stream$').hasMatch(path)) {
      throw ArgumentError('Unsupported authenticated event stream path');
    }
    final generation = _generation;
    final sentToken = _accessToken;
    if (sentToken == null) {
      throw const ApiException(401, 'UNAUTHORIZED', 'Vui lòng đăng nhập.');
    }
    var response = await _sendEventStream(client, sentToken, path);
    if (generation != _generation) throw StateError('Phiên đã thay đổi');
    if (response.statusCode == 401) {
      await response.stream.drain<void>();
      if (sentToken == _accessToken) await _refreshOnce();
      if (generation != _generation) throw StateError('Phiên đã thay đổi');
      response = await _sendEventStream(client, _accessToken!, path);
    }
    if (generation != _generation) throw StateError('Phiên đã thay đổi');
    if (response.statusCode != 200) {
      _decode(await http.Response.fromStream(response));
      throw const FormatException('Invalid notification stream response');
    }
    if (!(response.headers['content-type'] ?? '').startsWith(
      'text/event-stream',
    )) {
      throw const FormatException('Expected notification event stream');
    }
    return response;
  }

  Future<http.StreamedResponse> _sendEventStream(
    http.Client client,
    String token,
    String path,
  ) async {
    final bases = _baseUrl == null ? ApiConfig.candidateBaseUrls : [_baseUrl];
    for (var index = 0; index < bases.length; index++) {
      final uri = Uri.parse('${bases[index]}$path');
      if (kReleaseMode && uri.scheme != 'https') {
        throw const ApiException(0, 'CONFIG_ERROR', 'Realtime yêu cầu HTTPS.');
      }
      try {
        return await client
            .send(
              http.Request('GET', uri)
                ..headers['Accept'] = 'text/event-stream'
                ..headers['Authorization'] = 'Bearer $token',
            )
            .timeout(const Duration(seconds: 6));
      } on TimeoutException {
        if (index == bases.length - 1) rethrow;
      } on http.ClientException {
        if (index == bases.length - 1) rethrow;
      }
    }
    throw const ApiException(
      0,
      'NETWORK_ERROR',
      'Realtime không kết nối được.',
    );
  }

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
        final response = await (() async => http.Response.fromStream(
          await _client.send(request),
        ))().timeout(const Duration(seconds: 6));
        final postFeed =
            path == '/feed' ||
            path.startsWith('/feed?') ||
            path == '/feed/recommended' ||
            path.startsWith('/feed/recommended?');
        if (path.startsWith('/comments') ||
            path.startsWith('/me/reports') ||
            path.startsWith('/posts') ||
            postFeed ||
            RegExp(r'^/users/[^/]+/posts(?:\?|$)').hasMatch(path))
          _postApiBase = base;
        if (postFeed)
          PostMediaDiagnostics.event(
            'feed_http',
            'feed',
            values: {
              'status': response.statusCode,
              'bytes': response.bodyBytes.length,
            },
          );
        return response;
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

  Future<http.Response> _sendMultipart(
    String path, {
    required String fileField,
    required String filePath,
    required String token,
    Map<String, String>? fields,
    Duration timeout = const Duration(seconds: 20),
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
      final request = http.MultipartRequest('POST', url)
        ..headers['Accept'] = 'application/json'
        ..headers['Authorization'] = 'Bearer $token';
      if (fields != null) request.fields.addAll(fields);
      request.files.add(
        await http.MultipartFile.fromPath(
          fileField,
          filePath,
          contentType: _mediaTypeForPath(filePath),
        ),
      );
      try {
        final response = await (() async => http.Response.fromStream(
          await _client.send(request),
        ))().timeout(timeout);
        if (path.startsWith('/comments') ||
            path.startsWith('/me/reports') ||
            path.startsWith('/posts') ||
            path == '/feed' ||
            path.startsWith('/feed?') ||
            RegExp(r'^/users/[^/]+/posts(?:\?|$)').hasMatch(path))
          _postApiBase = base;
        return response;
      } on TimeoutException catch (error) {
        lastNetworkError = error.message ?? 'Request timed out';
      } on http.ClientException catch (error) {
        lastNetworkError = error.message;
      }
    }
    throw ApiException(
      0,
      'NETWORK_ERROR',
      'Không kết nối được máy chủ. Hãy kiểm tra backend GoMate và mạng nội bộ.'
          '${lastNetworkError == null ? '' : '\n$lastNetworkError'}',
    );
  }

  MediaType _mediaTypeForPath(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'heic' => MediaType('image', 'heic'),
      'mp4' => MediaType('video', 'mp4'),
      'mov' => MediaType('video', 'quicktime'),
      'webm' => MediaType('video', 'webm'),
      _ => MediaType('image', 'jpeg'),
    };
  }

  Object? _decodeJson(http.Response response) {
    Object? result = <String, dynamic>{};
    try {
      if (response.bodyBytes.isNotEmpty) {
        result = jsonDecode(utf8.decode(response.bodyBytes));
      }
    } catch (_) {
      throw ApiException(
        response.statusCode,
        'INVALID_RESPONSE',
        'Máy chủ trả dữ liệu không hợp lệ. Kiểm tra địa chỉ API.',
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return result;
    }
    final errorMap = result is Map<String, dynamic>
        ? result
        : const <String, dynamic>{};
    final code = errorMap['code'] as String? ?? 'HTTP_ERROR';
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
      _ => errorMap['message'] as String? ?? 'Không thể thực hiện yêu cầu.',
    };
    throw ApiException(response.statusCode, code, message);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final result = _decodeJson(response);
    if (result is Map<String, dynamic>) return result;
    throw ApiException(
      response.statusCode,
      'INVALID_RESPONSE',
      'Máy chủ trả dữ liệu không hợp lệ. Kiểm tra địa chỉ API.',
    );
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
    _credentialRevision++;
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
    _credentialRevision++;
    try {
      await _persist();
    } catch (_) {
      _remember = false;
    }
    notifyListeners();
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

  Future<Object?> requestJson(
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
      return _decodeJson(response);
    } on ApiException catch (error) {
      if (error.status == 401 && generation == _generation) await clearLocal();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> multipartRequest(
    String path, {
    required String fileField,
    required String filePath,
    Map<String, String>? fields,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final sentToken = _accessToken;
    if (sentToken == null) {
      throw const ApiException(401, 'UNAUTHORIZED', 'Vui lòng đăng nhập.');
    }
    final generation = _generation;
    var response = await _sendMultipart(
      path,
      fileField: fileField,
      filePath: filePath,
      token: sentToken,
      fields: fields,
      timeout: timeout,
    );
    if (generation != _generation) {
      throw const ApiException(401, 'UNAUTHORIZED', 'Phiên đã thay đổi.');
    }
    try {
      if (response.statusCode == 401) {
        if (sentToken == _accessToken) await _refreshOnce();
        response = await _sendMultipart(
          path,
          fileField: fileField,
          filePath: filePath,
          token: _accessToken!,
          fields: fields,
          timeout: timeout,
        );
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

  Future<({Uri uri, Map<String, String> headers})> postMediaAccess(
    String path,
  ) async {
    if (!RegExp(
      r'^/(posts|comments)/[0-9]+/media/[0-9a-fA-F-]{36}(/thumbnail)?$',
    ).hasMatch(path)) {
      throw ArgumentError('Invalid protected Post media path');
    }
    final generation = _generation;
    if (_accessToken == null) throw StateError('Signed out');
    bool expiresSoon = false;
    try {
      final parts = _accessToken!.split('.');
      if (parts.length == 3) {
        final payload =
            jsonDecode(
                  utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
                )
                as Map;
        expiresSoon =
            (payload['exp'] as num).toInt() <
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + 90;
      }
    } on FormatException {
      // Spring validates opaque/test tokens, not this expiration optimization.
    }
    if (expiresSoon) await _refreshOnce();
    if (generation != _generation || _accessToken == null) {
      throw StateError('Session changed');
    }
    final uri = Uri.parse(
      '${_postApiBase ?? _baseUrl ?? ApiConfig.candidateBaseUrls.first}$path',
    );
    if (kReleaseMode && uri.scheme != 'https') {
      throw StateError('Release API must use HTTPS');
    }
    return (
      uri: uri,
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Cache-Control': 'no-store',
      },
    );
  }

  Future<Uint8List> postImage(String path) async {
    final generation = _generation;
    final access = await postMediaAccess(path);
    var response = await _client
        .get(access.uri, headers: access.headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 401 && generation == _generation) {
      await _refreshOnce();
      final retry = await postMediaAccess(path);
      response = await _client
          .get(retry.uri, headers: retry.headers)
          .timeout(const Duration(seconds: 30));
    }
    PostMediaDiagnostics.event(
      'image_http',
      PostMediaDiagnostics.key(path),
      values: {
        'status': response.statusCode,
        'bytes': response.bodyBytes.length,
      },
    );
    if (generation != _generation) throw StateError('Session changed');
    if (response.statusCode != 200) {
      throw ApiException(
        response.statusCode,
        'POST_MEDIA_UNAVAILABLE',
        'Không tải được media bài viết.',
      );
    }
    return response.bodyBytes;
  }

  Future<void> loadProfile() async {
    final generation = _generation;
    final profile = await request('GET', '/users/me');
    if (generation != _generation) return;
    _user = profile;
    notifyListeners();
  }

  Future<void> updateProfile({
    String? nickname,
    String? fullName,
    String? city,
    String? bio,
    String? avatarUrl,
  }) async {
    _user = await request(
      'PATCH',
      '/users/me/profile',
      body: {
        if (nickname != null) 'nickname': nickname.trim(),
        if (fullName != null) 'fullName': fullName.trim(),
        if (city != null) 'city': city.trim(),
        if (bio != null) 'bio': bio.trim(),
        if (avatarUrl != null) 'avatarUrl': avatarUrl.trim(),
      },
    );
    notifyListeners();
  }

  Future<void> updatePrivacy(bool isPrivate) async {
    final generation = _generation;
    final profile = await request(
      'PATCH',
      '/users/me/profile',
      body: {'isPrivate': isPrivate},
    );
    if (generation != _generation) return;
    _user = profile;
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await request(
      'POST',
      '/auth/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
    await clearLocal();
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
    for (final callback in List.of(beforeLogout)) {
      try {
        await callback();
      } catch (_) {
        /* Delivery cleanup cannot block logout. */
      }
    }
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
    _credentialRevision++;
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    _remember = false;
    await _store.clear();
    notifyListeners();
  }
}
