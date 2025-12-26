import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../domain/auth_failure.dart';
import '../domain/auth_user.dart';
import 'auth_service.dart';

class AuthServiceFirebase implements AuthService {
  final fb.FirebaseAuth _auth;

  AuthServiceFirebase({fb.FirebaseAuth? auth})
    : _auth = auth ?? fb.FirebaseAuth.instance;

  AuthUser _mapUser(fb.User u) {
    return AuthUser(
      uid: u.uid,
      email: u.email,
      displayName: u.displayName,
      isAnonymous: u.isAnonymous,
      providerIds: u.providerData
          .map((e) => e.providerId)
          .toList(growable: false),
    );
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    return _auth.authStateChanges().map((u) => u == null ? null : _mapUser(u));
  }

  AuthFailure _mapFirebaseAuthException(fb.FirebaseAuthException e) {
    // Keep messages user-friendly; avoid leaking technical details.
    switch (e.code) {
      case 'invalid-email':
        return const AuthFailure(
          code: 'invalid-email',
          message: 'Invalid email address.',
        );
      case 'user-disabled':
        return const AuthFailure(
          code: 'user-disabled',
          message: 'This account is disabled.',
        );
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return const AuthFailure(
          code: 'invalid-credentials',
          message: 'Invalid email or password.',
        );
      case 'email-already-in-use':
        return const AuthFailure(
          code: 'email-already-in-use',
          message: 'Email is already in use.',
        );
      case 'weak-password':
        return const AuthFailure(
          code: 'weak-password',
          message: 'Password is too weak.',
        );
      case 'requires-recent-login':
        return const AuthFailure(
          code: 'requires-recent-login',
          message: 'Please sign in again and retry.',
        );
      default:
        return AuthFailure.unknown;
    }
  }

  @override
  Future<AuthUser> signInAnonymously() async {
    try {
      final cred = await _auth.signInAnonymously();
      final user = cred.user;
      if (user == null) throw AuthFailure.unknown;
      return _mapUser(user);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) throw AuthFailure.unknown;
      return _mapUser(user);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<AuthUser> registerWithEmail(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) throw AuthFailure.unknown;
      return _mapUser(user);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const AuthFailure(code: 'not-signed-in', message: 'Not signed in.');
    }

    try {
      final credential = fb.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
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
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
