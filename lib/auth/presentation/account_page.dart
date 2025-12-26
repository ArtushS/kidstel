import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.state.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
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
    );
  }
}
