import 'auth_provider_type.dart';

enum AuthFailureCode {
  cancelled,
  invalidCredentials,
  emailNotVerified,
  emailAlreadyInUse,
  accountAlreadyExists,
  accountExistsWithDifferentCredential,
  credentialAlreadyInUse,
  requiresRecentLogin,
  network,
  pendingCredentialNotFound,
  unknown,
}

class AuthFailureException implements Exception {
  final AuthFailureCode code;
  final String? email;
  final List<AuthProviderType> existingProviders;
  final AuthProviderType? pendingProvider;
  final String? debugMessage;

  const AuthFailureException({
    required this.code,
    this.email,
    this.existingProviders = const [],
    this.pendingProvider,
    this.debugMessage,
  });

  @override
  String toString() {
    final details = debugMessage == null ? '' : ': $debugMessage';
    return 'AuthFailureException($code$details)';
  }
}
