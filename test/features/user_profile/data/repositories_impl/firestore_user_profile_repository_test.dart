import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multicamera_tracking/features/user_profile/data/repositories_impl/firestore_user_profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class _MockFirebaseAuth extends Mock implements fb.FirebaseAuth {}

class _MockUser extends Mock implements fb.User {}

class _MockUserInfo extends Mock implements fb.UserInfo {}

class _MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late _MockFirebaseFirestore firestore;
  late _MockFirebaseAuth firebaseAuth;
  late _MockCollectionReference collection;
  late _MockDocumentReference docRef;
  late _MockDocumentSnapshot snapshot;
  late _MockUser user;
  late _MockUserInfo userInfo;
  late FirestoreUserProfileRepository repository;

  setUpAll(() {
    registerFallbackValue(SetOptions(merge: true));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firestore = _MockFirebaseFirestore();
    firebaseAuth = _MockFirebaseAuth();
    collection = _MockCollectionReference();
    docRef = _MockDocumentReference();
    snapshot = _MockDocumentSnapshot();
    user = _MockUser();
    userInfo = _MockUserInfo();

    repository = FirestoreUserProfileRepository(
      firestore: firestore,
      firebaseAuth: firebaseAuth,
    );

    when(() => firebaseAuth.currentUser).thenReturn(user);
    when(() => user.isAnonymous).thenReturn(false);
    when(() => user.uid).thenReturn('uid-1');
    when(() => user.email).thenReturn('john@example.com');
    when(() => user.providerData).thenReturn([userInfo]);
    when(() => user.displayName).thenReturn(null);
    when(() => userInfo.email).thenReturn('john@example.com');
    when(() => userInfo.displayName).thenReturn('John Doe');

    when(() => firestore.collection('users')).thenReturn(collection);
    when(() => collection.doc('uid-1')).thenReturn(docRef);
    when(() => docRef.get()).thenAnswer((_) async => snapshot);
    when(() => snapshot.data()).thenReturn(const <String, dynamic>{});
    when(() => docRef.set(any(), any())).thenAnswer((_) async {});
    when(() => docRef.set(any())).thenAnswer((_) async {});
  });

  test('creates a new profile document with deterministic defaults', () async {
    when(() => snapshot.exists).thenReturn(false);

    await repository.ensureCurrentUserProfileInitialized();

    final captured =
        verify(() => docRef.set(captureAny())).captured.single
            as Map<String, dynamic>;

    expect(captured['uid'], 'uid-1');
    expect(captured['email'], 'john@example.com');
    expect(captured['firstName'], 'John');
    expect(captured['lastName'], 'Doe');
    expect(captured['phoneNumber'], isNull);
    expect(captured['language'], 'es');
    expect(captured.containsKey('createdAt'), isTrue);
    expect(captured.containsKey('updatedAt'), isTrue);
  });

  test('does not overwrite existing non-empty user fields', () async {
    when(() => snapshot.exists).thenReturn(true);
    when(() => snapshot.data()).thenReturn({
      'uid': 'uid-1',
      'email': 'existing@example.com',
      'firstName': 'Existing',
      'lastName': 'User',
      'phoneNumber': '+34111111111',
      'language': 'en',
      'createdAt': Timestamp.now(),
    });

    await repository.ensureCurrentUserProfileInitialized();

    verifyNever(() => docRef.set(any(), any()));
    verifyNever(() => docRef.set(any()));
  });

  test('fills only missing fields for partial existing documents', () async {
    SharedPreferences.setMockInitialValues({'app_language': 'en'});
    when(() => snapshot.exists).thenReturn(true);
    when(() => snapshot.data()).thenReturn({
      'uid': 'uid-1',
      'firstName': 'Ana',
      'lastName': 'Ruiz',
      'email': '',
      'language': null,
    });

    await repository.ensureCurrentUserProfileInitialized();

    final captured =
        verify(() => docRef.set(captureAny(), captureAny())).captured.first
            as Map<String, dynamic>;

    expect(captured.containsKey('firstName'), isFalse);
    expect(captured.containsKey('lastName'), isFalse);
    expect(captured['email'], 'john@example.com');
    expect(captured['language'], 'en');
    expect(captured['phoneNumber'], isNull);
    expect(captured.containsKey('createdAt'), isTrue);
  });
}
