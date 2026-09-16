import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../navigation/auth_flow.dart';
import 'login_screen.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late Future<bool> _session;
  @override
  void initState() {
    super.initState();
    _session = AuthService.instance.restore();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _session,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Chưa kết nối được máy chủ để khôi phục phiên.'),
                FilledButton(
                  onPressed: () => setState(() {
                    _session = AuthService.instance.restore();
                  }),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        );
      }
      if (snapshot.data != true) return const LoginScreen();
      return AuthFlow.destination();
    },
  );
}
