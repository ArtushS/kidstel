import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../state/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (failure != null) ...[
              _ErrorCard(message: failure.message),
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
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) {
                      final value = (v ?? '');
                      if (value.isEmpty) {
                        return 'Enter your password';
                      }
                      if (value.length < 6) {
                        return 'Min 6 characters';
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
                                .signInWithEmail(_email.text, _password.text);
                          },
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.push('/register'),
              child: const Text('Create account'),
            ),
            TextButton(
              onPressed: () => context.push('/forgot-password'),
              child: const Text('Forgot password?'),
            ),
            const Divider(height: 32),
            _SocialButtons(),
          ],
        ),
      ),
    );
  }
}

class _SocialButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('TODO: Google sign-in')),
            );
          },
          icon: const Icon(Icons.g_mobiledata),
          label: const Text('Continue with Google'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('TODO: Apple sign-in')),
            );
          },
          icon: const Icon(Icons.apple),
          label: const Text('Continue with Apple'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('TODO: Facebook sign-in')),
            );
          },
          icon: const Icon(Icons.facebook),
          label: const Text('Continue with Facebook'),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
