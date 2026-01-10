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

  /// Link Facebook to the currently signed-in Firebase user.
  ///
  /// Typical cases:
  /// - Anonymous user: this upgrades the account.
  /// - Email/password user: adds Facebook as an additional provider.
  Future<AuthUser> linkWithFacebook();

  Future<void> signOut();
}
