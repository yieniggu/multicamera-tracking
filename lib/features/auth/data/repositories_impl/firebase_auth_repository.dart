import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/auth_failure_exception.dart';
import '../../domain/entities/auth_provider_type.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/pending_auth_link.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/services/display_name_policy.dart';

class FirebaseAuthRepository implements AuthRepository {
  static const String _localGuestUserId = 'local_guest';

  final fb.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  fb.AuthCredential? _pendingCredential;
  PendingAuthLink? _pendingAuthLink;
  bool _localGuestActive = false;

  FirebaseAuthRepository(this._firebaseAuth, {GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email']);

  AuthUser? _userFromFirebase(fb.User? user) {
    if (user == null) {
      if (_localGuestActive) {
        return const AuthUser(id: _localGuestUserId, isAnonymous: true);
      }
      return null;
    }
    if (user.isAnonymous) {
      return _localGuestActive
          ? const AuthUser(id: _localGuestUserId, isAnonymous: true)
          : null;
    }
    return AuthUser(id: user.uid, email: user.email, isAnonymous: false);
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_userFromFirebase);
  }

  @override
  Future<AuthUser?> signInWithEmail(String email, String password) async {
    try {
      final userCred = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCred.user;
      if (user == null || user.isAnonymous) {
        throw const AuthFailureException(
          code: AuthFailureCode.unknown,
          debugMessage: 'Email sign-in did not return an authenticated user',
        );
      }
      await _completePostAuth(user);
      return _userFromFirebase(user);
    } on fb.FirebaseAuthException catch (e) {
      throw await _mapFirebaseException(
        e,
        pendingProvider: AuthProviderType.password,
      );
    }
  }

  @override
  Future<AuthUser?> registerWithEmail(String email, String password) async {
    try {
      if (_firebaseAuth.currentUser?.isAnonymous == true) {
        await _firebaseAuth.signOut();
      }
      final userCred = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCred.user;
      if (user == null || user.isAnonymous) {
        throw const AuthFailureException(
          code: AuthFailureCode.unknown,
          debugMessage:
              'Email registration did not return an authenticated user',
        );
      }
      await _completePostAuth(user);
      return _userFromFirebase(user);
    } on fb.FirebaseAuthException catch (e) {
      throw await _mapFirebaseException(
        e,
        pendingProvider: AuthProviderType.password,
      );
    }
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    GoogleSignInAccount? googleUser;
    try {
      googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthFailureException(code: AuthFailureCode.cancelled);
      }

      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      if (_firebaseAuth.currentUser?.isAnonymous == true) {
        await _firebaseAuth.signOut();
      }
      final userCred = await _firebaseAuth.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null || user.isAnonymous) {
        throw const AuthFailureException(
          code: AuthFailureCode.unknown,
          debugMessage: 'Google sign-in did not return an authenticated user',
        );
      }

      await _completePostAuth(
        user,
        providerDisplayName: googleUser.displayName,
      );
      return _userFromFirebase(user);
    } on fb.FirebaseAuthException catch (e) {
      throw await _mapFirebaseException(
        e,
        pendingProvider: AuthProviderType.google,
        fallbackEmail: googleUser?.email,
        fallbackCredential: e.credential,
      );
    } on PlatformException catch (e) {
      throw _mapGooglePlatformException(e);
    } on AuthFailureException {
      rethrow;
    }
  }

  @override
  Future<AuthUser?> signInWithMicrosoft() async {
    try {
      final provider = fb.OAuthProvider('microsoft.com');
      if (_firebaseAuth.currentUser?.isAnonymous == true) {
        await _firebaseAuth.signOut();
      }
      final userCred = await _firebaseAuth.signInWithProvider(provider);
      final user = userCred.user;
      if (user == null || user.isAnonymous) {
        throw const AuthFailureException(
          code: AuthFailureCode.unknown,
          debugMessage:
              'Microsoft sign-in did not return an authenticated user',
        );
      }

      await _completePostAuth(user);
      return _userFromFirebase(user);
    } on fb.FirebaseAuthException catch (e) {
      throw await _mapFirebaseException(
        e,
        pendingProvider: AuthProviderType.microsoft,
        fallbackEmail: e.email,
        fallbackCredential: e.credential,
      );
    }
  }

  @override
  Future<AuthUser?> signInAnonymously() async {
    try {
      if (_firebaseAuth.currentUser != null) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
        await _firebaseAuth.signOut();
      }
      _localGuestActive = true;
      await _setGuestMode(true);
      return const AuthUser(id: _localGuestUserId, isAnonymous: true);
    } catch (_) {
      throw const AuthFailureException(
        code: AuthFailureCode.unknown,
        debugMessage: 'Failed to activate local guest session',
      );
    }
  }

  @override
  Future<bool> linkPendingCredentialToCurrentUser() async {
    if (_pendingAuthLink == null) return false;
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthFailureException(
        code: AuthFailureCode.pendingCredentialNotFound,
      );
    }
    if (_pendingCredential == null) {
      throw AuthFailureException(
        code: AuthFailureCode.pendingCredentialNotFound,
        email: _pendingAuthLink?.email,
        existingProviders: _pendingAuthLink?.existingProviders ?? const [],
        pendingProvider: _pendingAuthLink?.pendingProvider,
      );
    }

    try {
      await user.linkWithCredential(_pendingCredential!);
      await _ensureDisplayName(user);
      clearPendingAuthLink();
      return true;
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        clearPendingAuthLink();
        return true;
      }
      if (e.code == 'credential-already-in-use') {
        await _firebaseAuth.signInWithCredential(_pendingCredential!);
        clearPendingAuthLink();
        return true;
      }
      throw await _mapFirebaseException(
        e,
        pendingProvider:
            _pendingAuthLink?.pendingProvider ?? AuthProviderType.unknown,
        fallbackEmail: _pendingAuthLink?.email,
        fallbackCredential: _pendingCredential,
      );
    }
  }

  @override
  PendingAuthLink? get pendingAuthLink => _pendingAuthLink;

  @override
  void clearPendingAuthLink() {
    _pendingCredential = null;
    _pendingAuthLink = null;
  }

  @override
  Future<void> signOut() async {
    clearPendingAuthLink();

    if (_localGuestActive) {
      _localGuestActive = false;
      await _setGuestMode(false);
      return;
    }

    _localGuestActive = false;

    await _setGuestMode(false);
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _firebaseAuth.signOut();
  }

  @override
  AuthUser? get currentUser {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.isAnonymous) {
      return AuthUser(id: user.uid, email: user.email, isAnonymous: false);
    }
    if (_localGuestActive) {
      return const AuthUser(id: _localGuestUserId, isAnonymous: true);
    }
    return null;
  }

  Future<void> _completePostAuth(
    fb.User? user, {
    String? providerDisplayName,
  }) async {
    _localGuestActive = false;
    await _setGuestMode(false);
    if (user == null) return;
    await _ensureDisplayName(user, providerDisplayName: providerDisplayName);
  }

  Future<void> _setGuestMode(bool isGuest) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', isGuest);
  }

  Future<void> _ensureDisplayName(
    fb.User user, {
    String? providerDisplayName,
  }) async {
    final existing = user.displayName?.trim();
    if (existing != null && existing.isNotEmpty) return;

    final nextName = resolveDisplayName(
      email: user.email,
      providerDisplayName: providerDisplayName,
    );

    await user.updateDisplayName(nextName);
    await user.reload();
  }

  Future<AuthFailureException> _mapFirebaseException(
    fb.FirebaseAuthException e, {
    required AuthProviderType pendingProvider,
    String? fallbackEmail,
    fb.AuthCredential? fallbackCredential,
  }) async {
    if (e.code == 'account-exists-with-different-credential') {
      final email = e.email ?? fallbackEmail;
      final providers = _candidateSignInProviders(pendingProvider);
      _pendingCredential = e.credential ?? fallbackCredential;
      _pendingAuthLink = PendingAuthLink(
        email: email ?? '',
        existingProviders: providers,
        pendingProvider: pendingProvider,
        canLinkImmediately: _pendingCredential != null,
      );
      return AuthFailureException(
        code: AuthFailureCode.accountExistsWithDifferentCredential,
        email: email,
        existingProviders: providers,
        pendingProvider: pendingProvider,
        debugMessage: e.message,
      );
    }

    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
      case 'invalid-email':
        return AuthFailureException(
          code: AuthFailureCode.invalidCredentials,
          debugMessage: e.message,
        );
      case 'email-already-in-use':
      case 'email-already-exists':
        return AuthFailureException(
          code: AuthFailureCode.emailAlreadyInUse,
          debugMessage: e.message,
        );
      case 'requires-recent-login':
        return AuthFailureException(
          code: AuthFailureCode.requiresRecentLogin,
          debugMessage: e.message,
        );
      case 'credential-already-in-use':
        return AuthFailureException(
          code: AuthFailureCode.credentialAlreadyInUse,
          debugMessage: e.message,
        );
      case 'network-request-failed':
        return AuthFailureException(
          code: AuthFailureCode.network,
          debugMessage: e.message,
        );
      case 'web-context-canceled':
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return AuthFailureException(
          code: AuthFailureCode.cancelled,
          debugMessage: e.message,
        );
      default:
        return AuthFailureException(
          code: AuthFailureCode.unknown,
          debugMessage: e.message,
        );
    }
  }

  List<AuthProviderType> _candidateSignInProviders(
    AuthProviderType pendingProvider,
  ) {
    return [
      AuthProviderType.password,
      AuthProviderType.google,
      AuthProviderType.microsoft,
    ].where((provider) => provider != pendingProvider).toList();
  }

  AuthFailureException _mapGooglePlatformException(PlatformException e) {
    switch (e.code) {
      case 'sign_in_canceled':
      case 'sign_in_cancelled':
        return AuthFailureException(
          code: AuthFailureCode.cancelled,
          debugMessage: e.message,
        );
      case 'network_error':
        return AuthFailureException(
          code: AuthFailureCode.network,
          debugMessage: e.message,
        );
      case 'sign_in_failed':
      case 'google_sign_in':
      case 'channel-error':
      case 'null-error':
      default:
        return AuthFailureException(
          code: AuthFailureCode.unknown,
          debugMessage: '${e.code}: ${e.message}',
        );
    }
  }
}
