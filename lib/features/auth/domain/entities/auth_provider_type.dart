enum AuthProviderType {
  password,
  google,
  microsoft,
  unknown;

  static AuthProviderType fromSignInMethod(String? method) {
    switch (method) {
      case 'password':
      case 'emailLink':
        return AuthProviderType.password;
      case 'google.com':
        return AuthProviderType.google;
      case 'microsoft.com':
        return AuthProviderType.microsoft;
      default:
        return AuthProviderType.unknown;
    }
  }
}
