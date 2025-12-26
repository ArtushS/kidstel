import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final bool isAnonymous;
  final List<String> providerIds;

  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.isAnonymous,
    required this.providerIds,
  });
}
