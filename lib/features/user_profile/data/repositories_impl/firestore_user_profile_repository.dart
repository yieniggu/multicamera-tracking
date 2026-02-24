import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:multicamera_tracking/features/user_profile/domain/entities/user_profile.dart';
import 'package:multicamera_tracking/features/user_profile/domain/repositories/user_profile_repository.dart';

class FirestoreUserProfileRepository implements UserProfileRepository {
  static const _usersCollection = 'users';
  static const _languageKey = 'app_language';
  static const _allowedLanguages = {'es', 'en'};

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _firebaseAuth;

  FirestoreUserProfileRepository({
    required FirebaseFirestore firestore,
    required fb.FirebaseAuth firebaseAuth,
  }) : _firestore = firestore,
       _firebaseAuth = firebaseAuth;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(_usersCollection);

  @override
  Future<void> ensureCurrentUserProfileInitialized() async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.isAnonymous) return;

    final docRef = _users.doc(user.uid);
    final snapshot = await docRef.get();
    final defaults = await _defaultProfileValues(user);

    if (!snapshot.exists) {
      await docRef.set({
        'uid': user.uid,
        'email': defaults.email,
        'firstName': defaults.firstName,
        'lastName': defaults.lastName,
        'phoneNumber': defaults.phoneNumber,
        'language': defaults.language,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final data = snapshot.data() ?? const <String, dynamic>{};
    final updates = <String, dynamic>{};

    if (_isBlank(data['uid'])) {
      updates['uid'] = user.uid;
    }
    if (_isBlank(data['email'])) {
      updates['email'] = defaults.email;
    }
    if (_isBlank(data['firstName'])) {
      updates['firstName'] = defaults.firstName;
    }
    if (_isBlank(data['lastName'])) {
      updates['lastName'] = defaults.lastName;
    }
    if (!data.containsKey('phoneNumber') || _isBlank(data['phoneNumber'])) {
      updates['phoneNumber'] = defaults.phoneNumber;
    }
    if (_isBlank(data['language'])) {
      updates['language'] = defaults.language;
    }
    if (!data.containsKey('createdAt')) {
      updates['createdAt'] = FieldValue.serverTimestamp();
    }

    if (updates.isNotEmpty) {
      await docRef.set(updates, SetOptions(merge: true));
    }
  }

  @override
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.isAnonymous) return null;

    final snapshot = await _users.doc(user.uid).get();
    if (!snapshot.exists) return null;

    final data = snapshot.data() ?? const <String, dynamic>{};
    final defaults = await _defaultProfileValues(user);

    final firstName = _stringOrNull(data['firstName']) ?? defaults.firstName;
    final lastName = _stringOrNull(data['lastName']) ?? defaults.lastName;
    final phoneNumber = _normalizePhone(_stringOrNull(data['phoneNumber']));

    return UserProfile(
      uid: _stringOrNull(data['uid']) ?? user.uid,
      email: _stringOrNull(data['email']) ?? defaults.email,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      language:
          _normalizeLanguage(_stringOrNull(data['language'])) ??
          defaults.language,
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  @override
  Future<void> updateCurrentUserProfile({
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) async {
    final user = _requireSignedInUser();

    final normalizedFirstName = firstName.trim();
    if (normalizedFirstName.isEmpty) {
      throw ArgumentError.value(firstName, 'firstName', 'Cannot be empty');
    }

    final normalizedLastName = lastName.trim();
    final normalizedPhone = _normalizePhone(phoneNumber);
    if (phoneNumber != null &&
        phoneNumber.trim().isNotEmpty &&
        normalizedPhone == null) {
      throw ArgumentError.value(phoneNumber, 'phoneNumber', 'Invalid format');
    }

    await ensureCurrentUserProfileInitialized();

    await _users.doc(user.uid).set({
      'uid': user.uid,
      'email': _stringOrNull(user.email),
      'firstName': normalizedFirstName,
      'lastName': normalizedLastName,
      'phoneNumber': normalizedPhone,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<String?> getCurrentUserLanguage() async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.isAnonymous) return null;

    final snapshot = await _users.doc(user.uid).get();
    if (!snapshot.exists) return null;

    final data = snapshot.data() ?? const <String, dynamic>{};
    return _normalizeLanguage(_stringOrNull(data['language']));
  }

  @override
  Future<void> updateCurrentUserLanguage(String languageCode) async {
    final user = _requireSignedInUser();
    final normalizedLanguage = _normalizeLanguage(languageCode);
    if (normalizedLanguage == null) {
      throw ArgumentError.value(
        languageCode,
        'languageCode',
        'Unsupported language',
      );
    }

    await ensureCurrentUserProfileInitialized();

    await _users.doc(user.uid).set({
      'language': normalizedLanguage,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  fb.User _requireSignedInUser() {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('No authenticated non-guest user found');
    }
    return user;
  }

  Future<_DefaultProfileValues> _defaultProfileValues(fb.User user) async {
    final email = _bestEmailForUser(user);
    final name = _deriveName(user, email);

    return _DefaultProfileValues(
      email: email,
      firstName: name.firstName,
      lastName: name.lastName,
      phoneNumber: null,
      language: await _defaultLanguage(),
    );
  }

  String? _bestEmailForUser(fb.User user) {
    final primary = _stringOrNull(user.email);
    if (primary != null) return primary;

    for (final providerData in user.providerData) {
      final candidate = _stringOrNull(providerData.email);
      if (candidate != null) return candidate;
    }

    return null;
  }

  _NameParts _deriveName(fb.User user, String? email) {
    String? signal;

    for (final providerData in user.providerData) {
      final displayName = _collapseWhitespace(providerData.displayName);
      if (displayName != null) {
        signal = displayName;
        break;
      }
    }

    signal ??= _collapseWhitespace(user.displayName);

    if (signal != null && signal.isNotEmpty) {
      final tokens = signal.split(' ');
      if (tokens.length == 1) {
        return _NameParts(firstName: tokens.first, lastName: '');
      }
      return _NameParts(
        firstName: tokens.first,
        lastName: tokens.skip(1).join(' '),
      );
    }

    final emailLocalPart = _emailLocalPart(email);
    return _NameParts(
      firstName: emailLocalPart.isEmpty ? 'user' : emailLocalPart,
      lastName: '',
    );
  }

  Future<String> _defaultLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final local = _normalizeLanguage(prefs.getString(_languageKey));
    return local ?? 'es';
  }

  String _emailLocalPart(String? email) {
    final normalized = _stringOrNull(email) ?? '';
    final at = normalized.indexOf('@');
    if (at <= 0) return normalized;
    return normalized.substring(0, at);
  }

  String? _collapseWhitespace(String? value) {
    final normalized = _stringOrNull(value);
    if (normalized == null) return null;
    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _normalizeLanguage(String? languageCode) {
    final normalized = _stringOrNull(languageCode)?.toLowerCase();
    if (normalized == null) return null;
    return _allowedLanguages.contains(normalized) ? normalized : null;
  }

  String? _normalizePhone(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return null;

    final cleaned = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final hasPlus = cleaned.startsWith('+');
    final digits = cleaned.replaceAll('+', '');

    if (digits.isEmpty || !RegExp(r'^\d{7,15}$').hasMatch(digits)) {
      return null;
    }

    return hasPlus ? '+$digits' : digits;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final normalized = value.toString().trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  bool _isBlank(dynamic value) => _stringOrNull(value) == null;
}

class _DefaultProfileValues {
  final String? email;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final String language;

  const _DefaultProfileValues({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.language,
  });
}

class _NameParts {
  final String firstName;
  final String lastName;

  const _NameParts({required this.firstName, required this.lastName});
}
