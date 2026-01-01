import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  void _handleBack(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }

    if (context.canPop()) {
      // GoRouter stack (if different from Navigator stack).
      context.pop();
      return;
    }

    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.state.user;

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Account'),
          automaticallyImplyLeading: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBack(context),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('uid: ${user?.uid ?? '-'}'),
                        const SizedBox(height: 6),
                        Text('email: ${user?.email ?? '-'}'),
                        const SizedBox(height: 6),
                        Text('anonymous: ${user?.isAnonymous ?? false}'),
                        const SizedBox(height: 6),
                        Text(
                          'providers: ${(user?.providerIds ?? const []).join(', ')}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: user == null || (user.email == null)
                      ? null
                      : () => context.push('/change-password'),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Change password'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await context.read<AuthController>().signOut();
                    if (context.mounted) context.go('/auth');
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
