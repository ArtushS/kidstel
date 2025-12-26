enum AuthProviderId { password, google, apple, facebook, anonymous }

extension AuthProviderIdX on AuthProviderId {
  String get id {
    switch (this) {
      case AuthProviderId.password:
        return 'password';
      case AuthProviderId.google:
        return 'google.com';
      case AuthProviderId.apple:
        return 'apple.com';
      case AuthProviderId.facebook:
        return 'facebook.com';
      case AuthProviderId.anonymous:
        return 'anonymous';
    }
  }
}
