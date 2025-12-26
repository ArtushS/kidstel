import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../state/auth_state.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
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
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
              child: Column(
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) {
                        return 'Enter your email';
                      }
                      if (!_isValidEmail(value)) {
                        return 'Invalid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) {
                      final value = (v ?? '');
                      if (value.isEmpty) {
                        return 'Enter a password';
                      }
                      if (value.length < 6) {
                        return 'Min 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirm,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                    ),
                    validator: (v) {
                      final value = (v ?? '');
                      if (value != _password.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: auth.state.status == AuthStatus.loading
                        ? null
                        : () async {
                            if (!_formKey.currentState!.validate()) return;
                            await context
                                .read<AuthController>()
                                .registerWithEmail(_email.text, _password.text);
                          },
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Back to sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
