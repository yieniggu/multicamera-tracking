import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_provider_type.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_user.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/pending_auth_link.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/get_contact_email.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/account_profile_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/account_profile_screen.dart';
import 'package:multicamera_tracking/features/user_profile/domain/entities/user_profile.dart';
import 'package:multicamera_tracking/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:multicamera_tracking/features/user_profile/domain/use_cases/get_current_user_profile.dart';
import 'package:multicamera_tracking/features/user_profile/domain/use_cases/update_current_user_profile.dart';
import 'package:multicamera_tracking/l10n/app_localizations.dart';
import 'package:multicamera_tracking/shared/presentation/bloc/app_locale_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeUserProfileRepository {
  UserProfile profile;
  int saveCount = 0;

  _FakeUserProfileRepository(this.profile);

  Future<UserProfile?> getCurrentUserProfile() async => profile;

  Future<void> updateCurrentUserProfile({
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) async {
    saveCount += 1;
    profile = UserProfile(
      uid: profile.uid,
      email: profile.email,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      language: profile.language,
      createdAt: profile.createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class _FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  AuthUser? get currentUser =>
      const AuthUser(id: 'u1', email: 'ana@example.com');

  @override
  PendingAuthLink? get pendingAuthLink => null;

  @override
  void clearPendingAuthLink() {}

  @override
  Future<bool> linkPendingCredentialToCurrentUser() async => false;

  @override
  Future<AuthUser?> registerWithEmail(String email, String password) async =>
      currentUser;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AuthUser?> signInAnonymously() async => const AuthUser(id: 'guest');

  @override
  Future<AuthUser?> signInWithEmail(String email, String password) async =>
      currentUser;

  @override
  Future<AuthUser?> signInWithGoogle() async => currentUser;

  @override
  Future<AuthUser?> signInWithMicrosoft({String? emailHint}) async =>
      currentUser;

  @override
  Future<void> signOut() async {
    _controller.add(null);
  }

  @override
  Future<List<AuthProviderType>> getLinkedSignInMethods() async => const [];

  @override
  Future<String?> getContactEmail() async => 'ana@example.com';

  @override
  Future<void> setPassword(String newPassword) async {}

  @override
  Future<void> changePassword(String newPassword) async {}

  @override
  Future<void> changeEmail(String newEmail) async {}

  @override
  Future<void> reauthenticateWithPassword({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> reauthenticateWithGoogle() async {}

  @override
  Future<void> reauthenticateWithMicrosoft() async {}

  @override
  Future<String?> getPendingEmailVerificationEmail() async {
    return null;
  }

  @override
  Future<String?> refreshPendingEmailVerificationEmail() async {
    return null;
  }

  @override
  Future<void> sendEmailVerificationToCurrentUser() async {}

  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  late _FakeUserProfileRepository userProfileRepository;
  late _FakeAuthRepository authRepository;
  late AppLocaleCubit appLocaleCubit;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    userProfileRepository = _FakeUserProfileRepository(
      UserProfile(
        uid: 'u1',
        email: 'ana@example.com',
        firstName: 'Ana',
        lastName: 'Lopez',
        phoneNumber: '+34123456789',
        language: 'es',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    authRepository = _FakeAuthRepository();
    appLocaleCubit = AppLocaleCubit(
      userProfileRepository: _UserProfileRepositoryAdapter(
        userProfileRepository,
      ),
      authRepository: authRepository,
      deviceLocaleProvider: () => const Locale('en'),
    );

    if (getIt.isRegistered<AccountProfileBloc>()) {
      getIt.unregister<AccountProfileBloc>();
    }

    getIt.registerFactory<AccountProfileBloc>(
      () => AccountProfileBloc(
        getCurrentUserProfileUseCase: GetCurrentUserProfileUseCase(
          _UserProfileRepositoryAdapter(userProfileRepository),
        ),
        updateCurrentUserProfileUseCase: UpdateCurrentUserProfileUseCase(
          _UserProfileRepositoryAdapter(userProfileRepository),
        ),
        getContactEmailUseCase: GetContactEmailUseCase(authRepository),
      ),
    );
  });

  tearDown(() async {
    if (getIt.isRegistered<AccountProfileBloc>()) {
      getIt.unregister<AccountProfileBloc>();
    }
    await appLocaleCubit.close();
    await authRepository.dispose();
  });

  Future<void> _pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider<AppLocaleCubit>.value(
        value: appLocaleCubit,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AccountProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('prefills profile data and saves after valid changes', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Lopez'), findsOneWidget);
    final phoneField = tester.widget<TextField>(
      find.byKey(const Key('account_profile_phone_field')),
    );
    expect(phoneField.controller?.text, '+34123456789');
    expect(
      find.byKey(const Key('account_profile_language_dropdown')),
      findsOneWidget,
    );

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('account_profile_save_button')),
    );
    expect(saveButton.onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('account_profile_first_name_field')),
      'Ana Maria',
    );
    await tester.pumpAndSettle();

    final enabledSaveButton = tester.widget<FilledButton>(
      find.byKey(const Key('account_profile_save_button')),
    );
    expect(enabledSaveButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('account_profile_save_button')));
    await tester.pumpAndSettle();

    expect(userProfileRepository.saveCount, 1);
    expect(userProfileRepository.profile.firstName, 'Ana Maria');
  });

  testWidgets('prevents save when first name is empty', (tester) async {
    await _pumpScreen(tester);

    await tester.enterText(
      find.byKey(const Key('account_profile_first_name_field')),
      '',
    );
    await tester.pumpAndSettle();

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('account_profile_save_button')),
    );

    expect(saveButton.onPressed, isNull);
    expect(find.text('First name is required.'), findsOneWidget);
  });
}

class _UserProfileRepositoryAdapter implements UserProfileRepository {
  final _FakeUserProfileRepository _delegate;

  _UserProfileRepositoryAdapter(this._delegate);

  @override
  Future<void> ensureCurrentUserProfileInitialized() async {}

  @override
  Future<UserProfile?> getCurrentUserProfile() =>
      _delegate.getCurrentUserProfile();

  @override
  Future<void> updateCurrentUserProfile({
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) {
    return _delegate.updateCurrentUserProfile(
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
    );
  }

  @override
  Future<String?> getCurrentUserLanguage() async => null;

  @override
  Future<void> updateCurrentUserLanguage(String languageCode) async {}
}
