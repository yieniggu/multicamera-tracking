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
  static const String _microsoftMethod = 'microsoft.com';

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
      final normalizedEmail = email.trim();
      final methods = await _fetchSignInMethodsForEmailBestEffort(
        normalizedEmail,
      );
      if (methods.isNotEmpty && !methods.contains('password')) {
        final existingProviders = _providersFromSignInMethods(
          methods,
          excludeProvider: AuthProviderType.password,
        );
        _setPendingLink(
          email: normalizedEmail,
          pendingProvider: AuthProviderType.password,
          existingProviders: existingProviders,
          credential: null,
        );
        throw AuthFailureException(
          code: AuthFailureCode.accountExistsWithDifferentCredential,
          email: normalizedEmail,
          existingProviders: existingProviders,
          pendingProvider: AuthProviderType.password,
        );
      }

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
      await _enforcePasswordOnlyEmailVerification(user);
      await _completePostAuth(user);
      return _userFromFirebase(user);
    } on fb.FirebaseAuthException catch (e) {
      if (_isEmailSignInProviderMismatchCode(e.code)) {
        final providerMismatch = await _emailSignInProviderMismatchFailure(
          email,
        );
        if (providerMismatch != null) {
          throw providerMismatch;
        }
      }
      throw await _mapFirebaseException(
        e,
        pendingProvider: AuthProviderType.password,
      );
    }
  }

  @override
  Future<AuthUser?> registerWithEmail(String email, String password) async {
    try {
      final methods = await _fetchSignInMethodsForEmailBestEffort(email);
      if (methods.isNotEmpty) {
        throw const AuthFailureException(
          code: AuthFailureCode.accountAlreadyExists,
        );
      }

      await _clearAnonymousSessionIfNeeded();
      final userCred = await _createUserWithEmailAndPasswordWithRetry(
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
      await _enforcePasswordOnlyEmailVerification(user);
      await _completePostAuth(user);
      return _userFromFirebase(user);
    } on fb.FirebaseAuthException catch (e) {
      throw await _mapFirebaseException(
        e,
        pendingProvider: AuthProviderType.password,
        mapEmailInUseToAccountAlreadyExists: true,
      );
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final normalized = email.trim();
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: normalized);
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return;
      }
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

      await _clearAnonymousSessionIfNeeded();
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
      if (e.code == 'account-exists-with-different-credential') {
        throw AuthFailureException(
          code: AuthFailureCode.accountAlreadyExists,
          debugMessage: _firebaseDebug(e),
        );
      }
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
  Future<AuthUser?> signInWithMicrosoft({String? emailHint}) async {
    try {
      final provider = fb.OAuthProvider(_microsoftMethod);
      final normalizedHint = (emailHint ?? '').trim();
      if (normalizedHint.isNotEmpty) {
        provider.setCustomParameters({'login_hint': normalizedHint});
      }

      await _clearAnonymousSessionIfNeeded();
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
      if (e.code == 'account-exists-with-different-credential') {
        throw AuthFailureException(
          code: AuthFailureCode.accountAlreadyExists,
          debugMessage: _firebaseDebug(e),
        );
      }
      throw await _mapFirebaseException(
        e,
        pendingProvider: AuthProviderType.microsoft,
        fallbackEmail: e.email,
        fallbackCredential: e.credential,
      );
    } on AuthFailureException {
      rethrow;
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
      await _tryEnsureDisplayName(user);
      clearPendingAuthLink();
      return true;
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        clearPendingAuthLink();
        return true;
      }
      if (e.code == 'credential-already-in-use') {
        clearPendingAuthLink();
        throw AuthFailureException(
          code: AuthFailureCode.credentialAlreadyInUse,
          debugMessage: _firebaseDebug(e),
        );
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
  Future<List<AuthProviderType>> getLinkedSignInMethods() async {
    final user = _requireSignedInUser();
    final discoveredMethods = <String>{};
    final email = user.email?.trim();

    if (email != null && email.isNotEmpty) {
      try {
        discoveredMethods.addAll(await _fetchSignInMethodsForEmail(email));
      } on fb.FirebaseAuthException {
        // Best effort only; fall back to providerData.
      }
    }

    if (discoveredMethods.isEmpty) {
      for (final providerData in user.providerData) {
        discoveredMethods.add(providerData.providerId);
      }
    }

    return _providersFromSignInMethods(discoveredMethods.toList());
  }

  @override
  Future<String?> getContactEmail() async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.isAnonymous) return null;

    final primary = user.email?.trim();
    if (primary != null && primary.isNotEmpty) {
      return primary;
    }

    for (final providerData in user.providerData) {
      final email = providerData.email?.trim();
      if (email != null && email.isNotEmpty) {
        return email;
      }
    }

    return null;
  }

  @override
  Future<void> setPassword(String newPassword) async {
    final user = _requireSignedInUser();
    final hadPasswordBeforeUpdate = _providerMethodsFromUser(
      user,
    ).contains('password');
    await _updatePassword(newPassword);
    if (hadPasswordBeforeUpdate) return;
    await _enforceVerificationAfterPasswordSet();
  }

  @override
  Future<void> changePassword(String newPassword) async {
    await _updatePassword(newPassword);
  }

  @override
  Future<void> changeEmail(String newEmail) async {
    final user = _requireSignedInUser();
    try {
      await user.updateEmail(newEmail);
      await user.reload();
    } on fb.FirebaseAuthException catch (e) {
      throw await _mapFirebaseException(
        e,
        pendingProvider: AuthProviderType.password,
      );
    }
  }

  @override
  Future<void> reauthenticateWithPassword({
    required String email,
    required String password,
  }) async {
    final user = _requireSignedInUser();
    try {
      final credential = fb.EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on fb.FirebaseAuthException catch (e) {
      throw await _mapFirebaseException(
        e,
        pendingProvider: AuthProviderType.password,
      );
    }
  }

  @override
  Future<void> reauthenticateWithGoogle() async {
    final user = _requireSignedInUser();
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthFailureException(code: AuthFailureCode.cancelled);
      }
      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    } on fb.FirebaseAuthException catch (e) {
      throw await _mapFirebaseException(
        e,
        pendingProvider: AuthProviderType.google,
      );
    } on PlatformException catch (e) {
      throw _mapGooglePlatformException(e);
    }
  }

  @override
  Future<void> reauthenticateWithMicrosoft() async {
    final user = _requireSignedInUser();
    try {
      final provider = fb.OAuthProvider(_microsoftMethod);
      await user.reauthenticateWithProvider(provider);
    } on fb.FirebaseAuthException catch (e) {
      throw await _mapFirebaseException(
        e,
        pendingProvider: AuthProviderType.microsoft,
      );
    }
  }

  @override
  Future<String?> getPendingEmailVerificationEmail() async {
    return _resolvePendingEmailVerificationEmail(reload: false);
  }

  @override
  Future<String?> refreshPendingEmailVerificationEmail() async {
    return _resolvePendingEmailVerificationEmail(reload: true);
  }

  @override
  Future<void> sendEmailVerificationToCurrentUser() async {
    final user = _requireSignedInUser();
    try {
      await user.sendEmailVerification();
    } on fb.FirebaseAuthException catch (e) {
      throw await _mapFirebaseException(
        e,
        pendingProvider: AuthProviderType.password,
      );
    }
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

  Future<void> _updatePassword(String newPassword) async {
    final user = _requireSignedInUser();
    try {
      await user.updatePassword(newPassword);
      await user.reload();
    } on fb.FirebaseAuthException catch (e) {
      throw await _mapFirebaseException(
        e,
        pendingProvider: AuthProviderType.password,
      );
    }
  }

  Future<void> _enforceVerificationAfterPasswordSet() async {
    var user = _firebaseAuth.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      await user.reload();
    } catch (_) {
      // Best effort only.
    }

    user = _firebaseAuth.currentUser ?? user;
    if (user.isAnonymous || user.emailVerified) return;

    final email = user.email?.trim();
    if (email == null || email.isEmpty) return;

    try {
      await user.sendEmailVerification();
    } catch (_) {
      // Best effort only.
    }

    throw AuthFailureException(
      code: AuthFailureCode.emailNotVerified,
      email: email,
    );
  }

  fb.User _requireSignedInUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const AuthFailureException(
        code: AuthFailureCode.invalidCredentials,
      );
    }
    return user;
  }

  Future<void> _completePostAuth(
    fb.User? user, {
    String? providerDisplayName,
  }) async {
    _localGuestActive = false;
    await _setGuestMode(false);
    if (user == null) return;
    await _tryEnsureDisplayName(user, providerDisplayName: providerDisplayName);
  }

  Future<void> _clearAnonymousSessionIfNeeded() async {
    if (_firebaseAuth.currentUser?.isAnonymous != true) return;
    try {
      await _firebaseAuth.signOut();
    } catch (_) {
      // Best effort only. Create/sign-in can proceed without this step.
    }
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

  Future<void> _tryEnsureDisplayName(
    fb.User user, {
    String? providerDisplayName,
  }) async {
    try {
      await _ensureDisplayName(user, providerDisplayName: providerDisplayName);
    } catch (_) {
      // Profile naming should never block authentication completion.
    }
  }

  Future<void> _enforcePasswordOnlyEmailVerification(fb.User user) async {
    final pendingEmail = await _resolvePendingEmailVerificationEmail(
      reload: true,
      fallbackUser: user,
    );
    if (pendingEmail == null) {
      return;
    }
    try {
      await (_firebaseAuth.currentUser ?? user).sendEmailVerification();
    } catch (_) {
      // Best effort only.
    }
    throw AuthFailureException(
      code: AuthFailureCode.emailNotVerified,
      email: pendingEmail,
    );
  }

  Future<String?> _resolvePendingEmailVerificationEmail({
    required bool reload,
    fb.User? fallbackUser,
  }) async {
    var user = _firebaseAuth.currentUser ?? fallbackUser;
    if (user == null || user.isAnonymous) return null;
    if (reload) {
      try {
        await user.reload();
      } catch (_) {
        // Best effort only.
      }
      user = _firebaseAuth.currentUser ?? user;
      if (user.isAnonymous) return null;
    }

    final methods = _providerMethodsFromUser(user);
    final resolvedMethods = methods.isEmpty
        ? await _resolveSignInMethodsForUser(user)
        : methods;
    if (!_isPasswordOnlyMethods(resolvedMethods)) {
      return null;
    }
    if (user.emailVerified) {
      return null;
    }
    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      return null;
    }
    return email;
  }

  List<String> _providerMethodsFromUser(fb.User user) {
    try {
      return user.providerData.map((provider) => provider.providerId).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> _resolveSignInMethodsForUser(fb.User user) async {
    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      final discovered = await _fetchSignInMethodsForEmailBestEffort(email);
      if (discovered.isNotEmpty) {
        return discovered;
      }
    }
    try {
      return user.providerData.map((provider) => provider.providerId).toList();
    } catch (_) {
      return const [];
    }
  }

  bool _isPasswordOnlyMethods(List<String> methods) {
    if (methods.isEmpty) return true;
    for (final method in methods) {
      if (method == 'password' || method == 'emailLink') continue;
      return false;
    }
    return true;
  }

  Future<fb.UserCredential> _createUserWithEmailAndPasswordWithRetry({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on fb.FirebaseAuthException catch (e) {
      if (e.code != 'internal-error') rethrow;
      // iOS can intermittently return internal-error on first attempt.
      await _clearAnonymousSessionIfNeeded();
      return _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
  }

  bool _isEmailSignInProviderMismatchCode(String code) {
    return code == 'invalid-credential' || code == 'user-not-found';
  }

  Future<AuthFailureException?> _emailSignInProviderMismatchFailure(
    String email,
  ) async {
    final normalized = email.trim();
    if (normalized.isEmpty) return null;

    final methods = await _fetchSignInMethodsForEmailBestEffort(normalized);
    if (methods.isEmpty || methods.contains('password')) {
      return null;
    }

    final existingProviders = _providersFromSignInMethods(
      methods,
      excludeProvider: AuthProviderType.password,
    );
    _setPendingLink(
      email: normalized,
      pendingProvider: AuthProviderType.password,
      existingProviders: existingProviders,
      credential: null,
    );
    return AuthFailureException(
      code: AuthFailureCode.accountExistsWithDifferentCredential,
      email: normalized,
      existingProviders: existingProviders,
      pendingProvider: AuthProviderType.password,
    );
  }

  Future<AuthFailureException> _mapFirebaseException(
    fb.FirebaseAuthException e, {
    required AuthProviderType pendingProvider,
    String? fallbackEmail,
    fb.AuthCredential? fallbackCredential,
    bool mapEmailInUseToAccountAlreadyExists = false,
  }) async {
    if (e.code == 'account-exists-with-different-credential') {
      final email = (e.email ?? fallbackEmail ?? '').trim();
      final providers = email.isEmpty
          ? const <AuthProviderType>[]
          : await _fetchProvidersForEmailBestEffort(
              email,
              excludeProvider: pendingProvider,
            );
      final credential = e.credential ?? fallbackCredential;
      _setPendingLink(
        email: email,
        pendingProvider: pendingProvider,
        existingProviders: providers,
        credential: credential,
      );
      return AuthFailureException(
        code: AuthFailureCode.accountExistsWithDifferentCredential,
        email: email,
        existingProviders: providers,
        pendingProvider: pendingProvider,
        debugMessage: _firebaseDebug(e),
      );
    }

    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
      case 'invalid-email':
      case 'user-mismatch':
        return AuthFailureException(
          code: AuthFailureCode.invalidCredentials,
          debugMessage: _firebaseDebug(e),
        );
      case 'email-already-in-use':
      case 'email-already-exists':
        return AuthFailureException(
          code: mapEmailInUseToAccountAlreadyExists
              ? AuthFailureCode.accountAlreadyExists
              : AuthFailureCode.emailAlreadyInUse,
          debugMessage: _firebaseDebug(e),
        );
      case 'requires-recent-login':
        return AuthFailureException(
          code: AuthFailureCode.requiresRecentLogin,
          debugMessage: _firebaseDebug(e),
        );
      case 'credential-already-in-use':
        return AuthFailureException(
          code: AuthFailureCode.credentialAlreadyInUse,
          debugMessage: _firebaseDebug(e),
        );
      case 'network-request-failed':
        return AuthFailureException(
          code: AuthFailureCode.network,
          debugMessage: _firebaseDebug(e),
        );
      case 'web-context-canceled':
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return AuthFailureException(
          code: AuthFailureCode.cancelled,
          debugMessage: _firebaseDebug(e),
        );
      default:
        return AuthFailureException(
          code: AuthFailureCode.unknown,
          debugMessage: _firebaseDebug(e),
        );
    }
  }

  String _firebaseDebug(fb.FirebaseAuthException e) =>
      '${e.code}: ${e.message}';

  Future<List<String>> _fetchSignInMethodsForEmail(String email) async {
    final normalized = email.trim();
    if (normalized.isEmpty) return const [];
    return _firebaseAuth.fetchSignInMethodsForEmail(normalized);
  }

  Future<List<String>> _fetchSignInMethodsForEmailBestEffort(
    String email,
  ) async {
    try {
      return await _fetchSignInMethodsForEmail(email);
    } on fb.FirebaseAuthException {
      // Method discovery must never block sign-in/sign-up flows.
      return const [];
    }
  }

  Future<List<AuthProviderType>> _fetchProvidersForEmailBestEffort(
    String email, {
    AuthProviderType? excludeProvider,
  }) async {
    final methods = await _fetchSignInMethodsForEmailBestEffort(email);
    return _providersFromSignInMethods(
      methods,
      excludeProvider: excludeProvider,
    );
  }

  List<AuthProviderType> _providersFromSignInMethods(
    List<String> methods, {
    AuthProviderType? excludeProvider,
  }) {
    final providers = <AuthProviderType>{};
    for (final method in methods) {
      final provider = AuthProviderType.fromSignInMethod(method);
      if (provider == AuthProviderType.unknown) continue;
      if (excludeProvider != null && provider == excludeProvider) continue;
      providers.add(provider);
    }

    final ordered = <AuthProviderType>[];
    for (final provider in const [
      AuthProviderType.password,
      AuthProviderType.google,
      AuthProviderType.microsoft,
    ]) {
      if (providers.contains(provider)) {
        ordered.add(provider);
      }
    }
    return ordered;
  }

  void _setPendingLink({
    required String email,
    required AuthProviderType pendingProvider,
    required List<AuthProviderType> existingProviders,
    required fb.AuthCredential? credential,
  }) {
    _pendingCredential = credential;
    _pendingAuthLink = PendingAuthLink(
      email: email,
      existingProviders: existingProviders,
      pendingProvider: pendingProvider,
      canLinkImmediately: credential != null,
    );
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
