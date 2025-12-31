import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../state/auth_state.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthController>();
      auth.bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, c, _) {
        final s = c.state;

        if (s.status == AuthStatus.loading || s.status == AuthStatus.unknown) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (s.status == AuthStatus.unauthenticated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final loc = GoRouterState.of(context).uri.path;
            if (loc != '/login') {
              context.go('/login');
            }
          });

          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Authenticated: redirect will send to '/'.
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
