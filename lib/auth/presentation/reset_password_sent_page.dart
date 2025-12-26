import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ResetPasswordSentPage extends StatelessWidget {
  const ResetPasswordSentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check your email')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'If an account exists for that email, a reset link has been sent.',
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
