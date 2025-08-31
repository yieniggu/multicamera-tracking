import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _firebaseAuth;

  FirebaseAuthRepository(this._firebaseAuth);

  AuthUser? _userFromFirebase(fb.User? user) {
    if (user == null) return null;
    return AuthUser(
      id: user.uid,
      email: user.email,
      isAnonymous: user.isAnonymous,
    );
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_userFromFirebase);
  }

  @override
  Future<AuthUser?> signInWithEmail(String email, String password) async {
    final userCred = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', false);
    return _userFromFirebase(userCred.user);
  }

  @override
  Future<AuthUser?> registerWithEmail(String email, String password) async {
    final userCred = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', false);
    return _userFromFirebase(userCred.user);
  }

  @override
  Future<AuthUser?> signInAnonymously() async {
    try {
      final userCred = await _firebaseAuth.signInAnonymously();
      final user = userCred.user;
      if (user == null) throw Exception("User object is null");

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest', true);

      return AuthUser(id: user.uid, isAnonymous: user.isAnonymous);
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'operation-not-allowed') {
        throw Exception("Guest sign-in is disabled. Please contact support.");
      } else {
        throw Exception("Guest login failed: ${e.message ?? 'Unknown error'}");
      }
    } catch (e) {
      throw Exception("Something went wrong while signing in as guest.");
    }
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', false);
    await _firebaseAuth.signOut();
  }

  @override
  AuthUser? get currentUser {
    final user = _firebaseAuth.currentUser;
    return user != null
        ? AuthUser(id: user.uid, isAnonymous: user.isAnonymous)
        : null;
  }
}
