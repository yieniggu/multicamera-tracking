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
import 'package:multicamera_tracking/features/auth/domain/use_cases/change_account_email.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/change_account_password.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/get_contact_email.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/get_current_user.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/get_linked_sign_in_methods.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/get_pending_email_verification.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/link_pending_credential.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/refresh_pending_email_verification.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/reauthenticate_with_google.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/reauthenticate_with_microsoft.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/reauthenticate_with_password.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/register_with_email.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/send_email_verification_to_current_user.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/set_account_password.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/sign_out.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_anonymously.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_with_email.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_with_google.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_with_microsoft.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/account_settings_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_event.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/account_settings_screen.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/get_guest_migration_preview.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/init_user_data.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/migrate_guest_data.dart';
import 'package:multicamera_tracking/l10n/app_localizations.dart';
import 'package:multicamera_tracking/shared/domain/entities/guest_migration.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_data_migration_service.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_data_service.dart';
import 'package:multicamera_tracking/shared/domain/services/init_user_data_service.dart';
import 'package:multicamera_tracking/shared/domain/use_cases/adopt_local_guest_data_for_user.dart';
import 'package:multicamera_tracking/shared/domain/use_cases/resolve_guest_migration_source.dart';
import 'package:multicamera_tracking/shared/services_impl/app_mode_service_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();
  List<AuthProviderType> linkedMethods;
  String? email;

  _FakeAuthRepository({required this.linkedMethods, required this.email});

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  AuthUser? get currentUser => AuthUser(id: 'u1', email: email);

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
  Future<List<AuthProviderType>> getLinkedSignInMethods() async =>
      linkedMethods;

  @override
  Future<String?> getContactEmail() async => email;

  @override
  Future<void> setPassword(String newPassword) async {
    linkedMethods = [
      ...linkedMethods,
      AuthProviderType.password,
    ].toSet().toList();
  }

  @override
  Future<void> changePassword(String newPassword) async {}

  @override
  Future<void> changeEmail(String newEmail) async {
    email = newEmail;
  }

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

class _NoopInitUserDataService implements InitUserDataService {
  @override
  Future<void> ensureDefaultProjectAndGroup() async {}

  @override
  GroupRepository get groupRepository => _NoopGroupRepository();

  @override
  ProjectRepository get projectRepository => _NoopProjectRepository();
}

class _NoopProjectRepository implements ProjectRepository {
  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<Project>> getAll() async => const [];

  @override
  Future<void> save(Project project) async {}
}

class _NoopGroupRepository implements GroupRepository {
  @override
  Future<void> delete(String projectId, String groupId) async {}

  @override
  Future<List<Group>> getAllByProject(String projecId) async => const [];

  @override
  Future<void> save(Group group) async {}
}

class _NoopMigrationService implements GuestDataMigrationService {
  @override
  Future<GuestMigrationPreview> buildPreview({
    required String sourceUserId,
    required String targetUserId,
  }) async {
    return const GuestMigrationPreview(projectConflicts: []);
  }

  @override
  Future<void> migrate({
    required String sourceUserId,
    required String targetUserId,
    GuestMigrationPlan? plan,
  }) async {}
}

class _NoopGuestDataService implements GuestDataService {
  @override
  Future<bool> hasDataToMigrate({String? sourceUserId}) async => false;

  @override
  Future<String?> resolveMigrationSourceUserId({
    String? preferredSourceUserId,
  }) async {
    return preferredSourceUserId;
  }

  @override
  Future<bool> adoptLocalDataForUser({
    required String targetUserId,
    String? preferredSourceUserId,
  }) async {
    return false;
  }

  @override
  Future<void> clearLocalData() async {}
}

void main() {
  late _FakeAuthRepository repository;
  late AuthBloc authBloc;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (getIt.isRegistered<AccountSettingsBloc>()) {
      getIt.unregister<AccountSettingsBloc>();
    }
    await authBloc.close();
    await repository.dispose();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AccountSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void buildDependencies() {
    if (getIt.isRegistered<AccountSettingsBloc>()) {
      getIt.unregister<AccountSettingsBloc>();
    }
    getIt.registerFactory<AccountSettingsBloc>(
      () => AccountSettingsBloc(
        getLinkedSignInMethodsUseCase: GetLinkedSignInMethodsUseCase(
          repository,
        ),
        getContactEmailUseCase: GetContactEmailUseCase(repository),
        setAccountPasswordUseCase: SetAccountPasswordUseCase(repository),
        changeAccountPasswordUseCase: ChangeAccountPasswordUseCase(repository),
        changeAccountEmailUseCase: ChangeAccountEmailUseCase(repository),
        reauthenticateWithPasswordUseCase: ReauthenticateWithPasswordUseCase(
          repository,
        ),
        reauthenticateWithGoogleUseCase: ReauthenticateWithGoogleUseCase(
          repository,
        ),
        reauthenticateWithMicrosoftUseCase: ReauthenticateWithMicrosoftUseCase(
          repository,
        ),
      ),
    );

    final guestData = _NoopGuestDataService();
    authBloc = AuthBloc(
      authRepository: repository,
      signInWithEmailUseCase: SignInWithEmailUseCase(repository),
      signInWithGoogleUseCase: SignInWithGoogleUseCase(repository),
      signInWithMicrosoftUseCase: SignInWithMicrosoftUseCase(repository),
      registerWithEmailUseCase: RegisterWithEmailUseCase(repository),
      signInAnonymouslyUseCase: SignInAnonymouslyUseCase(repository),
      linkPendingCredentialUseCase: LinkPendingCredentialUseCase(repository),
      signOutUseCase: SignOutUseCase(repository),
      getCurrentUserUseCase: GetCurrentUserUseCase(repository),
      getPendingEmailVerificationUseCase: GetPendingEmailVerificationUseCase(
        repository,
      ),
      refreshPendingEmailVerificationUseCase:
          RefreshPendingEmailVerificationUseCase(repository),
      sendEmailVerificationToCurrentUserUseCase:
          SendEmailVerificationToCurrentUserUseCase(repository),
      initUserDataUseCase: InitUserDataUseCase(_NoopInitUserDataService()),
      migrateGuestDataUseCase: MigrateGuestDataUseCase(_NoopMigrationService()),
      getGuestMigrationPreviewUseCase: GetGuestMigrationPreviewUseCase(
        _NoopMigrationService(),
      ),
      adoptLocalGuestDataForUserUseCase: AdoptLocalGuestDataForUserUseCase(
        guestData,
      ),
      resolveGuestMigrationSourceUseCase: ResolveGuestMigrationSourceUseCase(
        guestData,
      ),
      appMode: AppModeServiceImpl(),
    )..add(AuthCheckRequested());
  }

  testWidgets('shows set-password action when password is not linked', (
    tester,
  ) async {
    repository = _FakeAuthRepository(
      linkedMethods: const [AuthProviderType.google],
      email: 'user@example.com',
    );
    buildDependencies();

    await pumpScreen(tester);

    expect(
      find.byKey(const Key('account_set_password_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('account_change_password_button')),
      findsNothing,
    );
  });

  testWidgets('shows change-password action when password is linked', (
    tester,
  ) async {
    repository = _FakeAuthRepository(
      linkedMethods: const [AuthProviderType.password, AuthProviderType.google],
      email: 'user@example.com',
    );
    buildDependencies();

    await pumpScreen(tester);

    expect(find.byKey(const Key('account_set_password_button')), findsNothing);
    expect(
      find.byKey(const Key('account_change_password_button')),
      findsOneWidget,
    );
  });
}
