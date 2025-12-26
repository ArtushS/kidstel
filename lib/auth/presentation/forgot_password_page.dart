import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../state/auth_state.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool _isValidEmail(String v) {
    final s = v.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final failure = auth.state.failure;

    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Enter your email and we will send a reset link.'),
            const SizedBox(height: 12),
            if (failure != null) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(failure.message),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Enter your email';
                  if (!_isValidEmail(value)) return 'Invalid email';
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: auth.state.status == AuthStatus.loading
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      final controller = context.read<AuthController>();
                      await controller.sendPasswordReset(_email.text);
                      if (!context.mounted) return;
                      if (controller.state.failure == null) {
                        context.go('/reset-sent');
                      }
                    },
              child: const Text('Send reset link'),
            ),
          ],
        ),
      ),
    );
  }
}
