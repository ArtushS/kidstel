import '../domain/auth_user.dart';

abstract class AuthService {
  Stream<AuthUser?> authStateChanges();

  Future<AuthUser> signInAnonymously();

  Future<AuthUser> signInWithEmail(String email, String password);

  Future<AuthUser> registerWithEmail(String email, String password);

  Future<void> sendPasswordReset(String email);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<AuthUser> signInWithGoogle();

  Future<AuthUser> signInWithApple();

  Future<AuthUser> signInWithFacebook();

  Future<void> signOut();
}
