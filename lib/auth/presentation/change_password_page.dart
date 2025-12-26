import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../state/auth_state.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPass = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _newPass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final failure = auth.state.failure;

    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
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
                    controller: _current,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                    ),
                    validator: (v) {
                      if ((v ?? '').isEmpty) {
                        return 'Enter current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPass,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                    ),
                    validator: (v) {
                      final value = (v ?? '');
                      if (value.isEmpty) {
                        return 'Enter new password';
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
                      labelText: 'Confirm new password',
                    ),
                    validator: (v) {
                      if ((v ?? '') != _newPass.text) {
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
                            final c = context.read<AuthController>();
                            await c.changePassword(
                              _current.text,
                              _newPass.text,
                            );
                            if (!context.mounted) return;
                            if (c.state.failure == null) {
                              context.pop();
                            }
                          },
                    child: const Text('Update password'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
