import '../entities/auth_user.dart';

abstract class AuthRepository {
  Stream<AuthUser?> authStateChanges();
  Future<AuthUser?> signInWithEmail(String email, String password);
  Future<AuthUser?> registerWithEmail(String email, String password);
  Future<AuthUser?> signInAnonymously();
  Future<void> signOut();

  AuthUser? get currentUser;
}
