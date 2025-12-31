import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class FirebaseSanityPage extends StatefulWidget {
  const FirebaseSanityPage({super.key});

  @override
  State<FirebaseSanityPage> createState() => _FirebaseSanityPageState();
}

class _FirebaseSanityPageState extends State<FirebaseSanityPage> {
  bool _busy = false;
  String _lastResult = '';

  User? get _user => FirebaseAuth.instance.currentUser;

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _run(String label, Future<String> Function(User u) op) async {
    final u = _user;
    if (u == null) {
      _snack('Not signed in');
      return;
    }

    setState(() {
      _busy = true;
      _lastResult = 'Running: $label…';
    });

    try {
      final res = await op(u);
      if (!mounted) return;
      setState(() => _lastResult = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastResult = 'ERROR ($label): $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  DocumentReference<Map<String, dynamic>> _debugDocFor(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('debug')
        .doc('ping');
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final providerIds = (u?.providerData ?? const <UserInfo>[])
        .map((p) => p.providerId)
        .where((s) => s.trim().isNotEmpty)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Firebase sanity check')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Auth', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _InfoRow(label: 'uid', value: u?.uid ?? '(null)'),
          _InfoRow(label: 'email', value: u?.email ?? '(null)'),
          _InfoRow(
            label: 'isAnonymous',
            value: u == null ? '(null)' : u.isAnonymous.toString(),
          ),
          _InfoRow(
            label: 'providerIds',
            value: providerIds.isEmpty ? '(empty)' : providerIds.join(', '),
          ),
          const SizedBox(height: 16),
          Text('Firestore', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _run('WRITE Firestore test', (u) async {
                    final doc = _debugDocFor(u.uid);
                    await doc.set({
                      'ping': 'pong',
                      'updatedAt': FieldValue.serverTimestamp(),
                      'clientUpdatedAt': DateTime.now().toIso8601String(),
                    }, SetOptions(merge: true));
                    return 'OK: wrote ${doc.path}';
                  }),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('WRITE Firestore test'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _run('READ Firestore test', (u) async {
                    final doc = _debugDocFor(u.uid);
                    final snap = await doc.get();
                    final data = snap.data();
                    return snap.exists
                        ? 'OK: read ${doc.path}\n$data'
                        : 'OK: doc does not exist: ${doc.path}';
                  }),
            icon: const Icon(Icons.download_outlined),
            label: const Text('READ Firestore test'),
          ),
          const SizedBox(height: 16),
          Text('Storage', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _run('GET Storage URL (public icon)', (u) async {
                    final ref = FirebaseStorage.instance.ref(
                      'heroes_icons/hero_bear.png',
                    );
                    final url = await ref.getDownloadURL();
                    return 'OK: downloadURL\n$url';
                  }),
            icon: const Icon(Icons.link_outlined),
            label: const Text('GET Storage URL (public icon)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _run('GET Storage URL (user path sample)', (u) async {
                    final ref = FirebaseStorage.instance.ref(
                      'users/${u.uid}/test.txt',
                    );
                    final url = await ref.getDownloadURL();
                    return 'OK: downloadURL\n$url';
                  }),
            icon: const Icon(Icons.person_outline),
            label: const Text('GET Storage URL (user path sample)'),
          ),
          const SizedBox(height: 16),
          Text('Result', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _lastResult.isEmpty ? '—' : _lastResult,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '''Notes: All actions require a signed-in user.
If you see 403/permission-denied, that's typically Firebase rules/App Check.
If you see object-not-found, that's a missing file.''',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
