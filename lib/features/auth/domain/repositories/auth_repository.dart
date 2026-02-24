import '../entities/auth_user.dart';
import '../entities/auth_provider_type.dart';
import '../entities/pending_auth_link.dart';

abstract class AuthRepository {
  Stream<AuthUser?> authStateChanges();
  Future<AuthUser?> signInWithEmail(String email, String password);
  Future<AuthUser?> registerWithEmail(String email, String password);
  Future<void> sendPasswordResetEmail(String email);
  Future<AuthUser?> signInWithGoogle();
  Future<AuthUser?> signInWithMicrosoft({String? emailHint});
  Future<AuthUser?> signInAnonymously();
  Future<bool> linkPendingCredentialToCurrentUser();
  PendingAuthLink? get pendingAuthLink;
  void clearPendingAuthLink();
  Future<void> signOut();
  Future<List<AuthProviderType>> getLinkedSignInMethods();
  Future<String?> getContactEmail();
  Future<void> setPassword(String newPassword);
  Future<void> changePassword(String newPassword);
  Future<void> changeEmail(String newEmail);
  Future<void> reauthenticateWithPassword({
    required String email,
    required String password,
  });
  Future<void> reauthenticateWithGoogle();
  Future<void> reauthenticateWithMicrosoft();
  Future<String?> getPendingEmailVerificationEmail();
  Future<String?> refreshPendingEmailVerificationEmail();
  Future<void> sendEmailVerificationToCurrentUser();

  AuthUser? get currentUser;
}
