import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/auth_service.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_user.dart';
import 'auth_state.dart';

class AuthController extends ChangeNotifier {
  final AuthService _service;
  final bool devBypass;

  AuthState _state = AuthState.initial();
  AuthState get state => _state;

  StreamSubscription<AuthUser?>? _sub;
  bool _bootstrapped = false;
  bool _autoSignInAttempted = false;

  AuthController({required AuthService service, required this.devBypass})
    : _service = service;

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    _state = _state.copyWith(status: AuthStatus.loading, clearFailure: true);
    notifyListeners();

    _sub = _service.authStateChanges().listen(
      (user) async {
        if (user == null) {
          _state = _state.copyWith(
            status: AuthStatus.unauthenticated,
            user: null,
            clearFailure: true,
          );
          notifyListeners();

          if (devBypass && !_autoSignInAttempted) {
            _autoSignInAttempted = true;
            await signInAnonymously();
          }

          return;
        }

        _state = _state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          clearFailure: true,
        );
        notifyListeners();
      },
      onError: (Object e, StackTrace st) {
        debugPrint('authStateChanges error: $e');
        _state = _state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
          failure: AuthFailure.unknown,
        );
        notifyListeners();
      },
    );

    // In case the stream is slow to emit, ensure we don't get stuck in loading.
    // The stream listener above will override this.
    _state = _state.copyWith(status: AuthStatus.unauthenticated);
    notifyListeners();
  }

  Future<void> signInAnonymously() async {
    await _runAuth(() => _service.signInAnonymously());
  }

  Future<void> signInWithEmail(String email, String pass) async {
    await _runAuth(() => _service.signInWithEmail(email, pass));
  }

  Future<void> registerWithEmail(String email, String pass) async {
    await _runAuth(() => _service.registerWithEmail(email, pass));
  }

  Future<void> sendPasswordReset(String email) async {
    await _runVoid(() => _service.sendPasswordReset(email));
  }

  Future<void> changePassword(String currentPass, String newPass) async {
    await _runVoid(
      () => _service.changePassword(
        currentPassword: currentPass,
        newPassword: newPass,
      ),
    );
  }

  Future<void> signInWithGoogle() async {
    await _runAuth(() => _service.signInWithGoogle());
  }

  Future<void> signInWithApple() async {
    await _runAuth(() => _service.signInWithApple());
  }

  Future<void> signInWithFacebook() async {
    await _runAuth(() => _service.signInWithFacebook());
  }

  Future<void> signOut() async {
    await _runVoid(() => _service.signOut());
  }

  Future<void> _runAuth(Future<AuthUser> Function() op) async {
    _state = _state.copyWith(status: AuthStatus.loading, clearFailure: true);
    notifyListeners();

    try {
      final user = await op();
      _state = _state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        clearFailure: true,
      );
      notifyListeners();
    } on AuthFailure catch (f) {
      _state = _state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        failure: f,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Auth op failed: $e');
      _state = _state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        failure: AuthFailure.unknown,
      );
      notifyListeners();
    }
  }

  Future<void> _runVoid(Future<void> Function() op) async {
    _state = _state.copyWith(status: AuthStatus.loading, clearFailure: true);
    notifyListeners();

    try {
      await op();
      // Keep current status/user; just clear failure/loading.
      _state = _state.copyWith(
        status: _state.user == null
            ? AuthStatus.unauthenticated
            : AuthStatus.authenticated,
        clearFailure: true,
      );
      notifyListeners();
    } on AuthFailure catch (f) {
      _state = _state.copyWith(failure: f);
      notifyListeners();
    } catch (e) {
      debugPrint('Auth void op failed: $e');
      _state = _state.copyWith(failure: AuthFailure.unknown);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
