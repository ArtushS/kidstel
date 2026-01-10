import 'dart:async';

import '../domain/auth_failure.dart';
import '../domain/auth_user.dart';
import 'auth_service.dart';

class AuthServiceMock implements AuthService {
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  void _emit(AuthUser? user) {
    _current = user;
    _controller.add(_current);
  }

  @override
  Future<AuthUser> signInAnonymously() async {
    final user = AuthUser(
      uid: 'mock_${DateTime.now().microsecondsSinceEpoch}',
      email: null,
      displayName: 'Dev User',
      isAnonymous: true,
      providerIds: const ['anonymous'],
    );
    _emit(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    if (email.trim().isEmpty || password.length < 6) {
      throw const AuthFailure(
        code: 'invalid-credentials',
        message: 'Invalid email or password.',
      );
    }

    final user = AuthUser(
      uid: 'mock_email_${email.hashCode}',
      email: email.trim(),
      displayName: null,
      isAnonymous: false,
      providerIds: const ['password'],
    );
    _emit(user);
    return user;
  }

  @override
  Future<AuthUser> registerWithEmail(String email, String password) async {
    return signInWithEmail(email, password);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (!email.contains('@')) {
      throw const AuthFailure(code: 'invalid-email', message: 'Invalid email.');
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // DEV stub.
    if (newPassword.length < 6) {
      throw const AuthFailure(
        code: 'weak-password',
        message: 'Password must be at least 6 characters.',
      );
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    throw const AuthFailure(code: 'todo', message: 'TODO: Google sign-in');
  }

  @override
  Future<AuthUser> signInWithApple() async {
    throw const AuthFailure(code: 'todo', message: 'TODO: Apple sign-in');
  }

  @override
  Future<AuthUser> signInWithFacebook() async {
    throw const AuthFailure(code: 'todo', message: 'TODO: Facebook sign-in');
  }

  @override
  Future<AuthUser> linkWithFacebook() async {
    final u = _current;
    if (u == null) {
      throw const AuthFailure(code: 'not-signed-in', message: 'Not signed in.');
    }

    final next = AuthUser(
      uid: u.uid,
      email: u.email,
      displayName: u.displayName,
      isAnonymous: false,
      providerIds: {...u.providerIds, 'facebook.com'}.toList(growable: false),
    );
    _emit(next);
    return next;
  }

  @override
  Future<void> signOut() async {
    _emit(null);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
