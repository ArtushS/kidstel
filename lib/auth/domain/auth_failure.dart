import 'package:flutter/foundation.dart';

@immutable
class AuthFailure {
  final String code;
  final String message;

  const AuthFailure({required this.code, required this.message});

  static const AuthFailure unknown = AuthFailure(
    code: 'unknown',
    message: 'Something went wrong. Please try again.',
  );

  static AuthFailure messageOnly(String message) =>
      AuthFailure(code: 'message', message: message);
}
