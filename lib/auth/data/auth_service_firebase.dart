import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

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
      case 'account-exists-with-different-credential':
        return const AuthFailure(
          code: 'account-exists-with-different-credential',
          message:
              'An account already exists with a different sign-in method. Please sign in using that method and then link Facebook from Account settings.',
        );
      case 'credential-already-in-use':
        return const AuthFailure(
          code: 'credential-already-in-use',
          message:
              'This Facebook account is already linked to another user. Please sign in with Facebook instead.',
        );
      default:
        return AuthFailure.unknown;
    }
  }

  void _logFb(String message) {
    if (kDebugMode) {
      debugPrint('[FB] $message');
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
    try {
      _logFb('signIn start');

      // Force browser-based login so Android emulator works without the FB app.
      final result = await FacebookAuth.i.login(
        permissions: const ['email', 'public_profile'],
        loginBehavior: LoginBehavior.webOnly,
      );

      _logFb('login result status=${result.status}');

      switch (result.status) {
        case LoginStatus.success:
          final token = result.accessToken?.tokenString;
          if (token == null || token.isEmpty) {
            throw const AuthFailure(
              code: 'facebook-missing-token',
              message: 'Facebook sign-in failed. Please try again.',
            );
          }

          final credential = fb.FacebookAuthProvider.credential(token);
          final cred = await _auth.signInWithCredential(credential);
          final user = cred.user;
          if (user == null) throw AuthFailure.unknown;
          _logFb('firebase signInWithCredential ok uid=${user.uid}');
          return _mapUser(user);

        case LoginStatus.cancelled:
          throw const AuthFailure(
            code: 'facebook-cancelled',
            message: 'Facebook sign-in was cancelled.',
          );

        case LoginStatus.failed:
          _logFb('login failed message=${result.message}');
          throw AuthFailure(
            code: 'facebook-failed',
            message: result.message?.trim().isNotEmpty == true
                ? result.message!.trim()
                : 'Facebook sign-in failed. Please try again.',
          );

        case LoginStatus.operationInProgress:
          throw const AuthFailure(
            code: 'facebook-in-progress',
            message: 'Facebook sign-in is already in progress.',
          );
      }
    } on AuthFailure {
      rethrow;
    } on fb.FirebaseAuthException catch (e) {
      _logFb('firebase_auth_exception code=${e.code} msg=${e.message}');
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      _logFb('facebook signIn unknown error: $e');
      throw AuthFailure(
        code: 'facebook-unknown',
        message: 'Facebook sign-in failed. Please try again.',
      );
    }
  }

  @override
  Future<AuthUser> linkWithFacebook() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure(code: 'not-signed-in', message: 'Not signed in.');
    }

    try {
      _logFb('link start uid=${user.uid} anon=${user.isAnonymous}');

      final result = await FacebookAuth.i.login(
        permissions: const ['email', 'public_profile'],
        loginBehavior: LoginBehavior.webOnly,
      );

      _logFb('link login result status=${result.status}');

      if (result.status == LoginStatus.cancelled) {
        throw const AuthFailure(
          code: 'facebook-cancelled',
          message: 'Facebook linking was cancelled.',
        );
      }

      if (result.status != LoginStatus.success) {
        throw AuthFailure(
          code: 'facebook-link-failed',
          message: result.message?.trim().isNotEmpty == true
              ? result.message!.trim()
              : 'Could not link Facebook. Please try again.',
        );
      }

      final token = result.accessToken?.tokenString;
      if (token == null || token.isEmpty) {
        throw const AuthFailure(
          code: 'facebook-missing-token',
          message: 'Could not link Facebook. Please try again.',
        );
      }

      final credential = fb.FacebookAuthProvider.credential(token);
      final cred = await user.linkWithCredential(credential);
      final linked = cred.user;
      if (linked == null) throw AuthFailure.unknown;
      _logFb('link ok uid=${linked.uid}');
      return _mapUser(linked);
    } on AuthFailure catch (f) {
      _logFb('link auth failure code=${f.code}');
      rethrow;
    } on fb.FirebaseAuthException catch (e) {
      _logFb('link firebase_auth_exception code=${e.code} msg=${e.message}');
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      _logFb('facebook link unknown error: $e');
      throw AuthFailure(
        code: 'facebook-link-unknown',
        message: 'Could not link Facebook. Please try again.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    // Best-effort: clear Facebook session so next sign-in shows the web UI.
    try {
      await FacebookAuth.i.logOut();
    } catch (_) {
      // Ignore.
    }
    await _auth.signOut();
  }
}
