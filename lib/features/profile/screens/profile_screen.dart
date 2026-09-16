import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/google_auth.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _busy = false;
  Future<void> _action(bool logout) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (logout) {
        await AuthService.instance.logout();
        if (mounted)
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
      } else {
        final token = await GoogleAuth.idToken();
        if (token != null) await AuthService.instance.linkGoogle(token);
      }
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa thực hiện được. Vui lòng thử lại.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.user;
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản GoMate')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?['nickname'] as String? ?? 'GoMate',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(user?['email'] as String? ?? ''),
            const SizedBox(height: 24),
            if (user?['googleLinked'] == true)
              const Text('Đã liên kết Google')
            else
              OutlinedButton(
                onPressed: _busy ? null : () => _action(false),
                child: const Text('Liên kết Google'),
              ),
            FilledButton(
              onPressed: _busy ? null : () => _action(true),
              child: const Text('Đăng xuất'),
            ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
