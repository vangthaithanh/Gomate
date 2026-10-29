import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';

/// Immediately hide a private Post sheet when its originating session changes.
class PostSessionGate extends StatelessWidget {
  final AuthService auth;
  final String? actor;
  final Widget child;
  const PostSessionGate({
    super.key,
    required this.auth,
    required this.actor,
    required this.child,
  });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: auth,
    builder: (context, _) {
      if (actor != null && actor == auth.user?['id']?.toString()) return child;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && ModalRoute.of(context)?.isCurrent == true)
          Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    },
  );
}
