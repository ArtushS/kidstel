import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_controller.dart';
import '../state/auth_state.dart';

class ProviderLinkPage extends StatefulWidget {
  const ProviderLinkPage({super.key});

  @override
  State<ProviderLinkPage> createState() => _ProviderLinkPageState();
}

class _ProviderLinkPageState extends State<ProviderLinkPage> {
  Future<void> _handleLinkFacebook() async {
    final auth = context.read<AuthController>();
    await auth.linkWithFacebook();
    if (!mounted) return;

    final failure = auth.state.failure;

    if (failure == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Facebook linked.')));
      return;
    }

    if (failure.code == 'credential-already-in-use') {
      // We guard with `mounted`, but the lint still flags `context` usage after
      // an async gap. This dialog is safe because we return early when unmounted.
      // ignore: use_build_context_synchronously
      final doSignIn = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Facebook already linked'),
          content: Text(
            '${failure.message}\n\nDo you want to sign in with Facebook instead?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign in with Facebook'),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (doSignIn == true) {
        await auth.signInWithFacebook();
        if (!mounted) return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${failure.message} (${failure.code})')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.state.user;
    final isLoading = auth.state.status == AuthStatus.loading;
    final isFacebookLinked = (user?.providerIds ?? const []).contains(
      'facebook.com',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Linked accounts')),
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
              ListTile(
                leading: Icon(
                  isFacebookLinked ? Icons.check_circle : Icons.link,
                  color: isFacebookLinked ? Colors.green : null,
                ),
                title: const Text('Facebook'),
                subtitle: Text(isFacebookLinked ? 'Linked' : 'Not linked'),
                trailing: isFacebookLinked
                    ? null
                    : FilledButton(
                        onPressed: isLoading ? null : _handleLinkFacebook,
                        child: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Link'),
                      ),
              ),
              const Spacer(),
              Text(
                'Tip: Linking works for anonymous users too (account upgrade).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
