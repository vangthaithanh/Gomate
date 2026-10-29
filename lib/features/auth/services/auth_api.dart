import '../../../core/services/auth_service.dart';
export '../../../core/network/api_exception.dart';

class AuthApi {
  static Future<void> register({
    required String identifier,
    required String password,
    required String fullName,
  }) => AuthService.instance.register(
    email: identifier,
    password: password,
    nickname: fullName,
  );
  static Future<void> login({
    required String identifier,
    required String password,
    bool remember = false,
  }) => AuthService.instance.login(
    email: identifier,
    password: password,
    remember: remember,
  );
}
