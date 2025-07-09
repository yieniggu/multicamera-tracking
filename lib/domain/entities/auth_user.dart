class AuthUser {
  final String id;
  final String? email;
  final bool isAnonymous;

  const AuthUser({
    required this.id,
    this.email,
    this.isAnonymous = false,
  });
}
  