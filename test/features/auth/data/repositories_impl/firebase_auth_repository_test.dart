import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multicamera_tracking/features/auth/data/repositories_impl/firebase_auth_repository.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_failure_exception.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_provider_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFirebaseAuth extends Mock implements fb.FirebaseAuth {}

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

class _MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class _MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

class _MockAuthCredential extends Mock implements fb.AuthCredential {}

class _MockUser extends Mock implements fb.User {}

class _MockUserCredential extends Mock implements fb.UserCredential {}

class _MockUserInfo extends Mock implements fb.UserInfo {}

void main() {
  late _MockFirebaseAuth firebaseAuth;
  late _MockGoogleSignIn googleSignIn;
  late FirebaseAuthRepository repository;

  setUpAll(() {
    registerFallbackValue(_MockAuthCredential());
    registerFallbackValue(fb.OAuthProvider('microsoft.com'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firebaseAuth = _MockFirebaseAuth();
    googleSignIn = _MockGoogleSignIn();
    repository = FirebaseAuthRepository(
      firebaseAuth,
      googleSignIn: googleSignIn,
    );
    when(() => firebaseAuth.currentUser).thenReturn(null);
  });

  test('signInWithGoogle signs in directly with credential', () async {
    final googleAccount = _MockGoogleSignInAccount();
    final googleAuth = _MockGoogleSignInAuthentication();
    final userCredential = _MockUserCredential();
    final user = _MockUser();

    when(() => googleSignIn.signIn()).thenAnswer((_) async => googleAccount);
    when(() => googleAccount.email).thenReturn('owner@example.com');
    when(() => googleAccount.displayName).thenReturn('Owner');
    when(
      () => googleAccount.authentication,
    ).thenAnswer((_) async => googleAuth);
    when(() => googleAuth.accessToken).thenReturn('access-token');
    when(() => googleAuth.idToken).thenReturn('id-token');
    when(
      () => firebaseAuth.signInWithCredential(any()),
    ).thenAnswer((_) async => userCredential);
    when(() => userCredential.user).thenReturn(user);
    when(() => user.isAnonymous).thenReturn(false);
    when(() => user.uid).thenReturn('uid-google');
    when(() => user.email).thenReturn('owner@example.com');
    when(() => user.displayName).thenReturn('Owner');

    final signedIn = await repository.signInWithGoogle();

    expect(signedIn, isNotNull);
    expect(signedIn!.id, 'uid-google');
    verify(() => firebaseAuth.signInWithCredential(any())).called(1);
    expect(repository.pendingAuthLink, isNull);
  });

  test(
    'signInWithEmail returns link-required when email exists with provider-only methods',
    () async {
      when(
        () => firebaseAuth.signInWithEmailAndPassword(
          email: 'owner@example.com',
          password: 'Passw0rd!',
        ),
      ).thenThrow(fb.FirebaseAuthException(code: 'invalid-credential'));
      when(
        () => firebaseAuth.fetchSignInMethodsForEmail('owner@example.com'),
      ).thenAnswer((_) async => const ['google.com']);

      await expectLater(
        repository.signInWithEmail('owner@example.com', 'Passw0rd!'),
        throwsA(
          isA<AuthFailureException>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.accountExistsWithDifferentCredential,
          ),
        ),
      );

      final pending = repository.pendingAuthLink;
      expect(pending, isNotNull);
      expect(pending!.pendingProvider, AuthProviderType.password);
      expect(pending.existingProviders, const [AuthProviderType.google]);
    },
  );

  test(
    'signInWithEmail keeps invalidCredentials for wrong password when password method exists',
    () async {
      when(
        () => firebaseAuth.fetchSignInMethodsForEmail('owner@example.com'),
      ).thenAnswer((_) async => const ['password']);
      when(
        () => firebaseAuth.signInWithEmailAndPassword(
          email: 'owner@example.com',
          password: 'wrong-password',
        ),
      ).thenThrow(fb.FirebaseAuthException(code: 'wrong-password'));

      await expectLater(
        repository.signInWithEmail('owner@example.com', 'wrong-password'),
        throwsA(
          isA<AuthFailureException>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.invalidCredentials,
          ),
        ),
      );
    },
  );

  test(
    'signInWithEmail requires email verification for password-only accounts',
    () async {
      final userCredential = _MockUserCredential();
      final user = _MockUser();

      when(
        () => firebaseAuth.fetchSignInMethodsForEmail('owner@example.com'),
      ).thenAnswer((_) async => const ['password']);
      when(
        () => firebaseAuth.signInWithEmailAndPassword(
          email: 'owner@example.com',
          password: 'Passw0rd!',
        ),
      ).thenAnswer((_) async => userCredential);
      when(() => userCredential.user).thenReturn(user);
      when(() => user.isAnonymous).thenReturn(false);
      when(() => user.email).thenReturn('owner@example.com');
      when(() => user.emailVerified).thenReturn(false);
      when(() => user.reload()).thenAnswer((_) async {});
      when(() => user.sendEmailVerification()).thenAnswer((_) async {});

      await expectLater(
        repository.signInWithEmail('owner@example.com', 'Passw0rd!'),
        throwsA(
          isA<AuthFailureException>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.emailNotVerified,
          ),
        ),
      );

      verify(() => user.sendEmailVerification()).called(1);
      verifyNever(() => firebaseAuth.signOut());
    },
  );

  test(
    'signInWithEmail skips verification enforcement when social provider is linked',
    () async {
      final userCredential = _MockUserCredential();
      final user = _MockUser();

      when(
        () => firebaseAuth.fetchSignInMethodsForEmail('owner@example.com'),
      ).thenAnswer((_) async => const ['password', 'google.com']);
      when(
        () => firebaseAuth.signInWithEmailAndPassword(
          email: 'owner@example.com',
          password: 'Passw0rd!',
        ),
      ).thenAnswer((_) async => userCredential);
      when(() => userCredential.user).thenReturn(user);
      when(() => user.isAnonymous).thenReturn(false);
      when(() => user.uid).thenReturn('uid-123');
      when(() => user.email).thenReturn('owner@example.com');
      when(() => user.displayName).thenReturn('Owner');

      final signedIn = await repository.signInWithEmail(
        'owner@example.com',
        'Passw0rd!',
      );

      expect(signedIn, isNotNull);
      expect(signedIn!.id, 'uid-123');
      verifyNever(() => user.sendEmailVerification());
      verifyNever(() => firebaseAuth.signOut());
    },
  );

  test(
    'signInWithGoogle maps account-exists-with-different-credential to accountAlreadyExists',
    () async {
      final googleAccount = _MockGoogleSignInAccount();
      final googleAuth = _MockGoogleSignInAuthentication();

      when(() => googleSignIn.signIn()).thenAnswer((_) async => googleAccount);
      when(() => googleAccount.email).thenReturn('owner@example.com');
      when(() => googleAccount.displayName).thenReturn('Owner');
      when(
        () => googleAccount.authentication,
      ).thenAnswer((_) async => googleAuth);
      when(() => googleAuth.accessToken).thenReturn('access-token');
      when(() => googleAuth.idToken).thenReturn('id-token');
      when(() => firebaseAuth.signInWithCredential(any())).thenThrow(
        fb.FirebaseAuthException(
          code: 'account-exists-with-different-credential',
          email: 'owner@example.com',
        ),
      );

      await expectLater(
        repository.signInWithGoogle(),
        throwsA(
          isA<AuthFailureException>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.accountAlreadyExists,
          ),
        ),
      );

      expect(repository.pendingAuthLink, isNull);
    },
  );

  test('registerWithEmail blocks when any sign-in method exists', () async {
    when(
      () => firebaseAuth.fetchSignInMethodsForEmail('owner@example.com'),
    ).thenAnswer((_) async => const ['google.com']);

    await expectLater(
      repository.registerWithEmail('owner@example.com', 'Passw0rd!'),
      throwsA(
        isA<AuthFailureException>().having(
          (e) => e.code,
          'code',
          AuthFailureCode.accountAlreadyExists,
        ),
      ),
    );

    verifyNever(
      () => firebaseAuth.createUserWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  test(
    'registerWithEmail maps email-already-in-use race case to accountAlreadyExists',
    () async {
      when(
        () => firebaseAuth.fetchSignInMethodsForEmail('owner@example.com'),
      ).thenAnswer((_) async => const []);
      when(
        () => firebaseAuth.createUserWithEmailAndPassword(
          email: 'owner@example.com',
          password: 'Passw0rd!',
        ),
      ).thenThrow(fb.FirebaseAuthException(code: 'email-already-in-use'));

      await expectLater(
        repository.registerWithEmail('owner@example.com', 'Passw0rd!'),
        throwsA(
          isA<AuthFailureException>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.accountAlreadyExists,
          ),
        ),
      );
    },
  );

  test(
    'registerWithEmail continues to create account when method discovery fails',
    () async {
      when(
        () => firebaseAuth.fetchSignInMethodsForEmail('owner@example.com'),
      ).thenThrow(fb.FirebaseAuthException(code: 'internal-error'));
      when(
        () => firebaseAuth.createUserWithEmailAndPassword(
          email: 'owner@example.com',
          password: 'Passw0rd!',
        ),
      ).thenThrow(fb.FirebaseAuthException(code: 'email-already-in-use'));

      await expectLater(
        repository.registerWithEmail('owner@example.com', 'Passw0rd!'),
        throwsA(
          isA<AuthFailureException>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.accountAlreadyExists,
          ),
        ),
      );

      verify(
        () => firebaseAuth.createUserWithEmailAndPassword(
          email: 'owner@example.com',
          password: 'Passw0rd!',
        ),
      ).called(1);
    },
  );

  test(
    'registerWithEmail retries once on internal-error during create user',
    () async {
      final userCredential = _MockUserCredential();
      final user = _MockUser();
      final passwordInfo = _MockUserInfo();

      when(
        () => firebaseAuth.fetchSignInMethodsForEmail('owner@example.com'),
      ).thenAnswer((_) async => const []);

      var createAttempts = 0;
      when(
        () => firebaseAuth.createUserWithEmailAndPassword(
          email: 'owner@example.com',
          password: 'Passw0rd!',
        ),
      ).thenAnswer((_) async {
        createAttempts += 1;
        if (createAttempts == 1) {
          throw fb.FirebaseAuthException(code: 'internal-error');
        }
        return userCredential;
      });

      when(() => userCredential.user).thenReturn(user);
      when(() => user.isAnonymous).thenReturn(false);
      when(() => user.uid).thenReturn('uid-123');
      when(() => user.email).thenReturn('owner@example.com');
      when(() => user.displayName).thenReturn('Owner');
      when(() => user.emailVerified).thenReturn(true);
      when(() => user.providerData).thenReturn([passwordInfo]);
      when(() => passwordInfo.providerId).thenReturn('password');

      final created = await repository.registerWithEmail(
        'owner@example.com',
        'Passw0rd!',
      );

      expect(created, isNotNull);
      expect(created!.id, 'uid-123');
      expect(createAttempts, 2);
    },
  );

  test('signInWithMicrosoft signs in directly with provider', () async {
    final userCredential = _MockUserCredential();
    final user = _MockUser();

    when(() => firebaseAuth.currentUser).thenReturn(null);
    when(
      () => firebaseAuth.signInWithProvider(any()),
    ).thenAnswer((_) async => userCredential);
    when(() => userCredential.user).thenReturn(user);
    when(() => user.isAnonymous).thenReturn(false);
    when(() => user.uid).thenReturn('uid-microsoft');
    when(() => user.email).thenReturn('owner@example.com');
    when(() => user.displayName).thenReturn('Owner');

    final signedIn = await repository.signInWithMicrosoft();

    expect(signedIn, isNotNull);
    expect(signedIn!.id, 'uid-microsoft');
    verify(() => firebaseAuth.signInWithProvider(any())).called(1);
  });

  test(
    'signInWithMicrosoft signs out anonymous session before sign-in',
    () async {
      final anonymousUser = _MockUser();
      final userCredential = _MockUserCredential();
      final user = _MockUser();

      when(() => firebaseAuth.currentUser).thenReturn(anonymousUser);
      when(() => anonymousUser.isAnonymous).thenReturn(true);
      when(() => firebaseAuth.signOut()).thenAnswer((_) async {});
      when(
        () => firebaseAuth.signInWithProvider(any()),
      ).thenAnswer((_) async => userCredential);
      when(() => userCredential.user).thenReturn(user);
      when(() => user.isAnonymous).thenReturn(false);
      when(() => user.uid).thenReturn('uid-microsoft');
      when(() => user.email).thenReturn('owner@example.com');
      when(() => user.displayName).thenReturn('Owner');

      final signedIn = await repository.signInWithMicrosoft();

      expect(signedIn, isNotNull);
      verify(() => firebaseAuth.signOut()).called(1);
      verify(() => firebaseAuth.signInWithProvider(any())).called(1);
    },
  );

  test(
    'signInWithMicrosoft maps account-exists-with-different-credential to accountAlreadyExists',
    () async {
      when(() => firebaseAuth.currentUser).thenReturn(null);
      when(() => firebaseAuth.signInWithProvider(any())).thenThrow(
        fb.FirebaseAuthException(
          code: 'account-exists-with-different-credential',
          email: 'owner@example.com',
        ),
      );

      await expectLater(
        repository.signInWithMicrosoft(),
        throwsA(
          isA<AuthFailureException>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.accountAlreadyExists,
          ),
        ),
      );

      expect(repository.pendingAuthLink, isNull);
    },
  );

  test(
    'linkPendingCredentialToCurrentUser returns false when no pending link',
    () async {
      final linked = await repository.linkPendingCredentialToCurrentUser();
      expect(linked, isFalse);
    },
  );

  test('getLinkedSignInMethods returns ordered known methods', () async {
    final user = _MockUser();
    final passwordInfo = _MockUserInfo();
    final googleInfo = _MockUserInfo();

    when(() => user.isAnonymous).thenReturn(false);
    when(() => user.providerData).thenReturn([passwordInfo, googleInfo]);
    when(() => passwordInfo.providerId).thenReturn('password');
    when(() => googleInfo.providerId).thenReturn('google.com');
    when(() => firebaseAuth.currentUser).thenReturn(user);

    final methods = await repository.getLinkedSignInMethods();

    expect(methods, [AuthProviderType.password, AuthProviderType.google]);
  });

  test(
    'getLinkedSignInMethods prefers fetched methods when available',
    () async {
      final user = _MockUser();
      final googleInfo = _MockUserInfo();

      when(() => user.isAnonymous).thenReturn(false);
      when(() => user.email).thenReturn('owner@example.com');
      when(() => user.providerData).thenReturn([googleInfo]);
      when(() => googleInfo.providerId).thenReturn('google.com');
      when(() => firebaseAuth.currentUser).thenReturn(user);
      when(
        () => firebaseAuth.fetchSignInMethodsForEmail('owner@example.com'),
      ).thenAnswer((_) async => const ['google.com', 'password']);

      final methods = await repository.getLinkedSignInMethods();

      expect(methods, [AuthProviderType.password, AuthProviderType.google]);
    },
  );

  test(
    'getContactEmail falls back to provider email when primary is missing',
    () async {
      final user = _MockUser();
      final providerInfo = _MockUserInfo();

      when(() => user.isAnonymous).thenReturn(false);
      when(() => user.email).thenReturn(null);
      when(() => user.providerData).thenReturn([providerInfo]);
      when(() => providerInfo.email).thenReturn('fallback@example.com');
      when(() => firebaseAuth.currentUser).thenReturn(user);

      final email = await repository.getContactEmail();

      expect(email, 'fallback@example.com');
    },
  );

  test('sendPasswordResetEmail calls firebase with normalized email', () async {
    when(
      () => firebaseAuth.sendPasswordResetEmail(email: 'owner@example.com'),
    ).thenAnswer((_) async {});

    await repository.sendPasswordResetEmail(' owner@example.com ');

    verify(
      () => firebaseAuth.sendPasswordResetEmail(email: 'owner@example.com'),
    ).called(1);
  });

  test(
    'sendPasswordResetEmail ignores user-not-found to avoid enumeration',
    () async {
      when(
        () => firebaseAuth.sendPasswordResetEmail(email: 'owner@example.com'),
      ).thenThrow(fb.FirebaseAuthException(code: 'user-not-found'));

      await repository.sendPasswordResetEmail('owner@example.com');

      verify(
        () => firebaseAuth.sendPasswordResetEmail(email: 'owner@example.com'),
      ).called(1);
    },
  );

  test(
    'setPassword sends verification and fails with emailNotVerified when email remains unverified',
    () async {
      final user = _MockUser();
      final googleInfo = _MockUserInfo();

      when(() => firebaseAuth.currentUser).thenReturn(user);
      when(() => user.isAnonymous).thenReturn(false);
      when(() => user.providerData).thenReturn([googleInfo]);
      when(() => googleInfo.providerId).thenReturn('google.com');
      when(() => user.updatePassword('Passw0rd!')).thenAnswer((_) async {});
      when(() => user.reload()).thenAnswer((_) async {});
      when(() => user.emailVerified).thenReturn(false);
      when(() => user.email).thenReturn('owner@example.com');
      when(() => user.sendEmailVerification()).thenAnswer((_) async {});

      await expectLater(
        repository.setPassword('Passw0rd!'),
        throwsA(
          isA<AuthFailureException>().having(
            (e) => e.code,
            'code',
            AuthFailureCode.emailNotVerified,
          ),
        ),
      );

      verify(() => user.updatePassword('Passw0rd!')).called(1);
      verify(() => user.sendEmailVerification()).called(1);
    },
  );

  test('setPassword succeeds when email is already verified', () async {
    final user = _MockUser();
    final googleInfo = _MockUserInfo();

    when(() => firebaseAuth.currentUser).thenReturn(user);
    when(() => user.isAnonymous).thenReturn(false);
    when(() => user.providerData).thenReturn([googleInfo]);
    when(() => googleInfo.providerId).thenReturn('google.com');
    when(() => user.updatePassword('Passw0rd!')).thenAnswer((_) async {});
    when(() => user.reload()).thenAnswer((_) async {});
    when(() => user.emailVerified).thenReturn(true);
    when(() => user.email).thenReturn('owner@example.com');

    await repository.setPassword('Passw0rd!');

    verify(() => user.updatePassword('Passw0rd!')).called(1);
    verifyNever(() => user.sendEmailVerification());
  });
}
