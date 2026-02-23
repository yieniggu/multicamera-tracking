import '../entities/auth_user.dart';
import '../entities/pending_auth_link.dart';

abstract class AuthRepository {
  Stream<AuthUser?> authStateChanges();
  Future<AuthUser?> signInWithEmail(String email, String password);
  Future<AuthUser?> registerWithEmail(String email, String password);
  Future<AuthUser?> signInWithGoogle();
  Future<AuthUser?> signInWithMicrosoft();
  Future<AuthUser?> signInAnonymously();
  Future<bool> linkPendingCredentialToCurrentUser();
  PendingAuthLink? get pendingAuthLink;
  void clearPendingAuthLink();
  Future<void> signOut();

  AuthUser? get currentUser;
}
