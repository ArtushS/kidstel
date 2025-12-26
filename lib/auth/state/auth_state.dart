import 'package:flutter/foundation.dart';

import '../domain/auth_failure.dart';
import '../domain/auth_user.dart';

enum AuthStatus { unknown, loading, authenticated, unauthenticated }

@immutable
class AuthState {
  final AuthStatus status;
  final AuthUser? user;
  final AuthFailure? failure;

  const AuthState({
    required this.status,
    required this.user,
    required this.failure,
  });

  factory AuthState.initial() =>
      const AuthState(status: AuthStatus.unknown, user: null, failure: null);

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    AuthFailure? failure,
    bool clearFailure = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}
