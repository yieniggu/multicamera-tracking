import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_user.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:multicamera_tracking/shared/presentation/bloc/app_locale_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockUserProfileRepository extends Mock
    implements UserProfileRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockUserProfileRepository userProfileRepository;
  late _MockAuthRepository authRepository;
  late AppLocaleCubit cubit;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    userProfileRepository = _MockUserProfileRepository();
    authRepository = _MockAuthRepository();
    when(() => authRepository.currentUser).thenReturn(null);

    cubit = AppLocaleCubit(
      userProfileRepository: userProfileRepository,
      authRepository: authRepository,
      deviceLocaleProvider: () => const Locale('en'),
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  test(
    'hydrate uses local language when user is guest/unauthenticated',
    () async {
      SharedPreferences.setMockInitialValues({'app_language': 'en'});

      await cubit.hydrate();

      expect(cubit.state.locale.languageCode, 'en');
      verifyNever(() => userProfileRepository.getCurrentUserLanguage());
    },
  );

  test('hydrate prefers Firestore language for authenticated users', () async {
    SharedPreferences.setMockInitialValues({'app_language': 'en'});
    when(
      () => authRepository.currentUser,
    ).thenReturn(const AuthUser(id: 'u1', email: 'u1@example.com'));
    when(
      () => userProfileRepository.getCurrentUserLanguage(),
    ).thenAnswer((_) async => 'es');

    await cubit.hydrate();

    expect(cubit.state.locale.languageCode, 'es');
    verify(() => userProfileRepository.getCurrentUserLanguage()).called(1);
  });

  test('setLanguage persists locally for guest users only', () async {
    await cubit.setLanguage('en');

    expect(cubit.state.locale.languageCode, 'en');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_language'), 'en');
    verifyNever(() => userProfileRepository.updateCurrentUserLanguage('en'));
  });

  test('setLanguage updates Firestore for authenticated users', () async {
    when(
      () => authRepository.currentUser,
    ).thenReturn(const AuthUser(id: 'u1', email: 'u1@example.com'));
    when(
      () => userProfileRepository.updateCurrentUserLanguage('en'),
    ).thenAnswer((_) async {});

    await cubit.setLanguage('en');

    expect(cubit.state.locale.languageCode, 'en');
    verify(
      () => userProfileRepository.updateCurrentUserLanguage('en'),
    ).called(1);
  });
}
