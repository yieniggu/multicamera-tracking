import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multicamera_tracking/config/di.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_failure_exception.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_user.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/pending_auth_link.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/get_current_user.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/link_pending_credential.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/register_with_email.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/sign_out.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_anonymously.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_with_email.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_with_google.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_with_microsoft.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_state.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/login_screen.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/init_user_data.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/get_guest_migration_preview.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/migrate_guest_data.dart';
import 'package:multicamera_tracking/shared/domain/services/app_mode.dart';
import 'package:multicamera_tracking/shared/domain/entities/guest_migration.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_data_service.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_data_migration_service.dart';
import 'package:multicamera_tracking/shared/domain/services/init_user_data_service.dart';
import 'package:multicamera_tracking/shared/domain/use_cases/adopt_local_guest_data_for_user.dart';
import 'package:multicamera_tracking/shared/domain/use_cases/has_guest_data_to_migrate.dart';
import 'package:multicamera_tracking/shared/domain/use_cases/reset_local_debug_data.dart';
import 'package:multicamera_tracking/shared/domain/use_cases/resolve_guest_migration_source.dart';
import 'package:multicamera_tracking/shared/services_impl/app_mode_service_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository implements AuthRepository {
  final _authController = StreamController<AuthUser?>.broadcast();
  Completer<AuthUser?>? googleCompleter;
  AuthFailureException? googleException;
  int googleSignInCalls = 0;

  @override
  Stream<AuthUser?> authStateChanges() => _authController.stream;

  @override
  AuthUser? get currentUser => null;

  @override
  PendingAuthLink? get pendingAuthLink => null;

  @override
  void clearPendingAuthLink() {}

  @override
  Future<bool> linkPendingCredentialToCurrentUser() async => false;

  @override
  Future<AuthUser?> registerWithEmail(String email, String password) async =>
      null;

  @override
  Future<AuthUser?> signInAnonymously() async => const AuthUser(id: 'guest');

  @override
  Future<AuthUser?> signInWithEmail(String email, String password) async =>
      const AuthUser(id: 'email-user', email: 'email@example.com');

  @override
  Future<AuthUser?> signInWithGoogle() async {
    googleSignInCalls += 1;
    if (googleException != null) throw googleException!;
    if (googleCompleter != null) return googleCompleter!.future;
    return const AuthUser(id: 'google-user', email: 'google@example.com');
  }

  @override
  Future<AuthUser?> signInWithMicrosoft() async =>
      const AuthUser(id: 'microsoft-user', email: 'microsoft@example.com');

  @override
  Future<void> signOut() async {}

  Future<void> dispose() async {
    await _authController.close();
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

class _FakeGuestDataService implements GuestDataService {
  bool hasDataToMigrateValue = false;
  int clearCalls = 0;

  @override
  Future<bool> hasDataToMigrate({String? sourceUserId}) async =>
      hasDataToMigrateValue;

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
  Future<void> clearLocalData() async {
    clearCalls += 1;
  }
}

void main() {
  late _FakeAuthRepository repository;
  late AuthBloc authBloc;
  late AppMode appMode;
  late _FakeGuestDataService guestDataService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _FakeAuthRepository();
    appMode = AppModeServiceImpl();
    guestDataService = _FakeGuestDataService();
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
      initUserDataUseCase: InitUserDataUseCase(_NoopInitUserDataService()),
      migrateGuestDataUseCase: MigrateGuestDataUseCase(_NoopMigrationService()),
      getGuestMigrationPreviewUseCase: GetGuestMigrationPreviewUseCase(
        _NoopMigrationService(),
      ),
      adoptLocalGuestDataForUserUseCase: AdoptLocalGuestDataForUserUseCase(
        guestDataService,
      ),
      resolveGuestMigrationSourceUseCase: ResolveGuestMigrationSourceUseCase(
        guestDataService,
      ),
      appMode: appMode,
    );
    if (getIt.isRegistered<HasGuestDataToMigrateUseCase>()) {
      getIt.unregister<HasGuestDataToMigrateUseCase>();
    }
    getIt.registerSingleton<HasGuestDataToMigrateUseCase>(
      HasGuestDataToMigrateUseCase(guestDataService),
    );
    if (getIt.isRegistered<ResetLocalDebugDataUseCase>()) {
      getIt.unregister<ResetLocalDebugDataUseCase>();
    }
    getIt.registerSingleton<ResetLocalDebugDataUseCase>(
      ResetLocalDebugDataUseCase(guestDataService),
    );
  });

  tearDown(() async {
    if (getIt.isRegistered<HasGuestDataToMigrateUseCase>()) {
      getIt.unregister<HasGuestDataToMigrateUseCase>();
    }
    if (getIt.isRegistered<ResetLocalDebugDataUseCase>()) {
      getIt.unregister<ResetLocalDebugDataUseCase>();
    }
    await authBloc.close();
    await repository.dispose();
  });

  Future<void> pumpLoginScreen(
    WidgetTester tester, {
    bool enableGuestMigration = false,
  }) async {
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
          home: LoginScreen(enableGuestMigration: enableGuestMigration),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders email/password plus Google and Microsoft buttons', (
    tester,
  ) async {
    await pumpLoginScreen(tester);

    expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    expect(find.byKey(const Key('google_sign_in_button')), findsOneWidget);
    expect(find.byKey(const Key('microsoft_sign_in_button')), findsOneWidget);
    expect(find.text('Enter as Guest'), findsOneWidget);
  });

  testWidgets('disables auth actions while sign-in is loading', (tester) async {
    repository.googleCompleter = Completer<AuthUser?>();
    await pumpLoginScreen(tester);

    await tester.tap(find.byKey(const Key('google_sign_in_button')));
    await tester.pump();
    expect(authBloc.state, isA<AuthLoading>());
    expect(repository.googleSignInCalls, 1);

    await tester.tap(find.byKey(const Key('google_sign_in_button')));
    await tester.pump();

    expect(repository.googleSignInCalls, 1);
  });

  testWidgets('general register flow hides guest migration option', (
    tester,
  ) async {
    guestDataService.hasDataToMigrateValue = true;
    await pumpLoginScreen(tester, enableGuestMigration: false);

    await tester.tap(find.text("Don't have an account? Register"));
    await tester.pumpAndSettle();

    expect(find.text('Migrate data from guest session'), findsNothing);
  });

  testWidgets(
    'guest link-account register flow has migration enabled internally',
    (tester) async {
      guestDataService.hasDataToMigrateValue = true;
      await pumpLoginScreen(tester, enableGuestMigration: true);

      await tester.tap(find.text("Don't have an account? Register"));
      await tester.pumpAndSettle();

      expect(find.text('Migrate data from guest session'), findsNothing);
    },
  );

  testWidgets('debug reset local data action clears local data', (
    tester,
  ) async {
    await pumpLoginScreen(tester);

    await tester.tap(find.byKey(const Key('debug_reset_local_data_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(guestDataService.clearCalls, 1);
    expect(find.text('Local data cleared.'), findsOneWidget);
  });
}
