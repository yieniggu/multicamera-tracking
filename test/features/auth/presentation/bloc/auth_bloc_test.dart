import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_failure_exception.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_provider_type.dart';
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
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_event.dart';
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_state.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/init_user_data.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/get_guest_migration_preview.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/migrate_guest_data.dart';
import 'package:multicamera_tracking/shared/domain/services/app_mode.dart';
import 'package:multicamera_tracking/shared/domain/entities/guest_migration.dart';
import 'package:multicamera_tracking/shared/domain/entities/guest_migration_plan_validation_exception.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_data_service.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_data_migration_service.dart';
import 'package:multicamera_tracking/shared/domain/services/init_user_data_service.dart';
import 'package:multicamera_tracking/shared/domain/use_cases/adopt_local_guest_data_for_user.dart';
import 'package:multicamera_tracking/shared/domain/use_cases/resolve_guest_migration_source.dart';
import 'package:multicamera_tracking/shared/services_impl/app_mode_service_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository implements AuthRepository {
  final _authController = StreamController<AuthUser?>.broadcast();

  AuthUser? _currentUser;
  AuthUser? emailResult;
  AuthUser? registerResult;
  AuthUser? googleResult;
  AuthUser? microsoftResult;
  AuthUser? anonymousResult;
  AuthFailureException? emailException;
  AuthFailureException? registerException;
  AuthFailureException? googleException;
  AuthFailureException? microsoftException;
  PendingAuthLink? _pendingLink;
  bool linkPendingCalled = false;
  int anonymousSignInCalls = 0;
  bool emitAuthStateChangeDuringGoogleSignIn = false;

  @override
  Stream<AuthUser?> authStateChanges() => _authController.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  PendingAuthLink? get pendingAuthLink => _pendingLink;

  set pendingLink(PendingAuthLink? value) => _pendingLink = value;
  set currentUserForTest(AuthUser? value) => _currentUser = value;

  @override
  void clearPendingAuthLink() {
    _pendingLink = null;
  }

  @override
  Future<bool> linkPendingCredentialToCurrentUser() async {
    linkPendingCalled = true;
    _pendingLink = null;
    return true;
  }

  @override
  Future<AuthUser?> registerWithEmail(String email, String password) async {
    if (registerException != null) throw registerException!;
    _currentUser = registerResult;
    return registerResult;
  }

  @override
  Future<AuthUser?> signInAnonymously() async {
    anonymousSignInCalls += 1;
    _currentUser = anonymousResult;
    return anonymousResult;
  }

  @override
  Future<AuthUser?> signInWithEmail(String email, String password) async {
    if (emailException != null) throw emailException!;
    _currentUser = emailResult;
    return emailResult;
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    if (googleException != null) throw googleException!;
    _currentUser = googleResult;
    if (emitAuthStateChangeDuringGoogleSignIn) {
      _authController.add(_currentUser);
    }
    return googleResult;
  }

  @override
  Future<AuthUser?> signInWithMicrosoft() async {
    if (microsoftException != null) throw microsoftException!;
    _currentUser = microsoftResult;
    return microsoftResult;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  Future<void> dispose() async {
    await _authController.close();
  }
}

class _NoopInitUserDataService implements InitUserDataService {
  bool called = false;
  int callCount = 0;

  @override
  Future<void> ensureDefaultProjectAndGroup() async {
    called = true;
    callCount += 1;
  }

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
  int calls = 0;
  String? lastSourceUserId;
  String? lastTargetUserId;
  GuestMigrationPlan? lastPlan;
  GuestMigrationPreview preview = const GuestMigrationPreview(
    projectConflicts: [],
  );
  Exception? migrateException;

  @override
  Future<GuestMigrationPreview> buildPreview({
    required String sourceUserId,
    required String targetUserId,
  }) async {
    return preview;
  }

  @override
  Future<void> migrate({
    required String sourceUserId,
    required String targetUserId,
    GuestMigrationPlan? plan,
  }) async {
    if (migrateException != null) throw migrateException!;
    calls += 1;
    lastSourceUserId = sourceUserId;
    lastTargetUserId = targetUserId;
    lastPlan = plan;
  }
}

class _FakeGuestDataService implements GuestDataService {
  String? sourceUserId = 'guest-uid';
  int adoptCalls = 0;

  @override
  Future<bool> hasDataToMigrate({String? sourceUserId}) async => true;

  @override
  Future<String?> resolveMigrationSourceUserId({
    String? preferredSourceUserId,
  }) async {
    return preferredSourceUserId ?? sourceUserId;
  }

  @override
  Future<bool> adoptLocalDataForUser({
    required String targetUserId,
    String? preferredSourceUserId,
  }) async {
    adoptCalls += 1;
    return true;
  }

  @override
  Future<void> clearLocalData() async {}
}

void main() {
  late _FakeAuthRepository repository;
  late _NoopInitUserDataService initService;
  late _NoopMigrationService migrationService;
  late _FakeGuestDataService guestDataService;
  late AuthBloc bloc;
  late AppMode appMode;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _FakeAuthRepository();
    initService = _NoopInitUserDataService();
    migrationService = _NoopMigrationService();
    guestDataService = _FakeGuestDataService();
    appMode = AppModeServiceImpl();

    bloc = AuthBloc(
      authRepository: repository,
      signInWithEmailUseCase: SignInWithEmailUseCase(repository),
      signInWithGoogleUseCase: SignInWithGoogleUseCase(repository),
      signInWithMicrosoftUseCase: SignInWithMicrosoftUseCase(repository),
      registerWithEmailUseCase: RegisterWithEmailUseCase(repository),
      signInAnonymouslyUseCase: SignInAnonymouslyUseCase(repository),
      linkPendingCredentialUseCase: LinkPendingCredentialUseCase(repository),
      signOutUseCase: SignOutUseCase(repository),
      getCurrentUserUseCase: GetCurrentUserUseCase(repository),
      initUserDataUseCase: InitUserDataUseCase(initService),
      migrateGuestDataUseCase: MigrateGuestDataUseCase(migrationService),
      getGuestMigrationPreviewUseCase: GetGuestMigrationPreviewUseCase(
        migrationService,
      ),
      adoptLocalGuestDataForUserUseCase: AdoptLocalGuestDataForUserUseCase(
        guestDataService,
      ),
      resolveGuestMigrationSourceUseCase: ResolveGuestMigrationSourceUseCase(
        guestDataService,
      ),
      appMode: appMode,
    );
  });

  tearDown(() async {
    await bloc.close();
    await repository.dispose();
  });

  test('emits authenticated state on successful Google sign-in', () async {
    repository.googleResult = const AuthUser(
      id: 'google-user',
      email: 'camera@example.com',
      isAnonymous: false,
    );

    final expectation = expectLater(
      bloc.stream,
      emitsInOrder([
        isA<AuthLoading>(),
        isA<AuthAuthenticated>()
            .having((state) => state.user.id, 'id', 'google-user')
            .having((state) => state.isGuest, 'isGuest', isFalse),
      ]),
    );

    bloc.add(AuthSignedInWithGoogle());
    await expectation;
    expect(initService.called, isTrue);
    expect(migrationService.calls, 0);
  });

  test(
    'does not run auth-check initialization during in-flight Google sign-in',
    () async {
      repository.emitAuthStateChangeDuringGoogleSignIn = true;
      repository.googleResult = const AuthUser(
        id: 'google-user',
        email: 'camera@example.com',
        isAnonymous: false,
      );

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthAuthenticated>()
              .having((state) => state.user.id, 'id', 'google-user')
              .having((state) => state.isGuest, 'isGuest', isFalse),
        ]),
      );

      bloc.add(const AuthSignedInWithGoogle(shouldMigrateGuestData: true));
      await expectation;

      // Only the explicit success path should initialize user data here.
      expect(initService.callCount, 1);
    },
  );

  test('adopts existing local guest data on anonymous sign-in', () async {
    repository.anonymousResult = const AuthUser(
      id: 'fresh-guest',
      isAnonymous: true,
    );

    final expectation = expectLater(
      bloc.stream,
      emitsInOrder([
        isA<AuthLoading>(),
        isA<AuthAuthenticated>()
            .having((state) => state.user.id, 'id', 'fresh-guest')
            .having((state) => state.isGuest, 'isGuest', isTrue),
      ]),
    );

    bloc.add(AuthSignedInAnonymously());
    await expectation;

    expect(guestDataService.adoptCalls, 1);
  });

  test(
    'emits link-required state for account-exists-with-different-credential',
    () async {
      repository.pendingLink = const PendingAuthLink(
        email: 'already@exists.com',
        existingProviders: [AuthProviderType.password],
        pendingProvider: AuthProviderType.google,
        canLinkImmediately: true,
      );
      repository.googleException = const AuthFailureException(
        code: AuthFailureCode.accountExistsWithDifferentCredential,
        email: 'already@exists.com',
        existingProviders: [AuthProviderType.password],
        pendingProvider: AuthProviderType.google,
      );

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthLinkRequired>().having(
            (state) => state.pendingLink.email,
            'email',
            'already@exists.com',
          ),
        ]),
      );

      bloc.add(AuthSignedInWithGoogle());
      await expectation;
    },
  );

  test(
    'emits specific error when registering an email that already exists',
    () async {
      repository.registerException = const AuthFailureException(
        code: AuthFailureCode.emailAlreadyInUse,
      );

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthFailure>()
              .having(
                (state) => state.code,
                'code',
                AuthFailureCode.emailAlreadyInUse,
              )
              .having(
                (state) => state.message,
                'message',
                'auth.error.emailAlreadyInUse',
              ),
        ]),
      );

      bloc.add(
        const AuthRegisteredWithEmail(
          email: 'already@exists.com',
          password: 'secret123',
        ),
      );
      await expectation;
    },
  );

  test('attempts pending-credential linking after email sign-in', () async {
    repository.pendingLink = const PendingAuthLink(
      email: 'owner@example.com',
      existingProviders: [AuthProviderType.password],
      pendingProvider: AuthProviderType.microsoft,
      canLinkImmediately: true,
    );
    repository.emailResult = const AuthUser(
      id: 'owner-user',
      email: 'owner@example.com',
      isAnonymous: false,
    );

    final expectation = expectLater(
      bloc.stream,
      emitsInOrder([
        isA<AuthLoading>(),
        isA<AuthAuthenticated>().having(
          (state) => state.user.id,
          'id',
          'owner-user',
        ),
      ]),
    );

    bloc.add(const AuthSignedInWithEmail('owner@example.com', 'secret123'));
    await expectation;
    expect(repository.linkPendingCalled, isTrue);
  });

  test(
    'migrates guest data after password-required link resolution then email sign-in',
    () async {
      repository.currentUserForTest = const AuthUser(
        id: 'local_guest',
        isAnonymous: true,
      );
      repository.pendingLink = const PendingAuthLink(
        email: 'owner@example.com',
        existingProviders: [AuthProviderType.password],
        pendingProvider: AuthProviderType.google,
        canLinkImmediately: true,
      );
      repository.emailResult = const AuthUser(
        id: 'owner-user',
        email: 'owner@example.com',
        isAnonymous: false,
      );

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthFailure>().having(
            (state) => state.message,
            'message',
            'auth.error.linkWithPasswordRequired',
          ),
          isA<AuthLoading>(),
          isA<AuthAuthenticated>().having(
            (state) => state.user.id,
            'id',
            'owner-user',
          ),
        ]),
      );

      bloc.add(
        const AuthPendingLinkResolvedWithProvider(
          AuthProviderType.password,
          shouldMigrateGuestData: true,
        ),
      );
      bloc.add(const AuthSignedInWithEmail('owner@example.com', 'secret123'));
      await expectation;

      expect(repository.linkPendingCalled, isTrue);
      expect(migrationService.calls, 1);
      expect(migrationService.lastSourceUserId, 'local_guest');
      expect(migrationService.lastTargetUserId, 'owner-user');
    },
  );

  test(
    'AuthCheckRequested prefers remote user over stale guest restore flag',
    () async {
      SharedPreferences.setMockInitialValues({'is_guest': true});
      repository.currentUserForTest = const AuthUser(
        id: 'remote-user',
        email: 'remote@example.com',
        isAnonymous: false,
      );

      final expectation = expectLater(
        bloc.stream,
        emits(
          isA<AuthAuthenticated>()
              .having((state) => state.user.id, 'id', 'remote-user')
              .having((state) => state.isGuest, 'isGuest', isFalse),
        ),
      );

      bloc.add(AuthCheckRequested());
      await expectation;

      expect(repository.anonymousSignInCalls, 0);
    },
  );

  test('migrates guest data on Google register flow when requested', () async {
    repository.currentUserForTest = const AuthUser(
      id: 'guest-uid',
      isAnonymous: true,
    );
    repository.googleResult = const AuthUser(
      id: 'guest-uid',
      email: 'camera@example.com',
      isAnonymous: false,
    );

    final expectation = expectLater(
      bloc.stream,
      emitsInOrder([
        isA<AuthLoading>(),
        isA<AuthAuthenticated>().having(
          (state) => state.user.id,
          'id',
          'guest-uid',
        ),
      ]),
    );

    bloc.add(const AuthSignedInWithGoogle(shouldMigrateGuestData: true));
    await expectation;

    expect(migrationService.calls, 1);
    expect(migrationService.lastSourceUserId, 'guest-uid');
    expect(migrationService.lastTargetUserId, 'guest-uid');
  });

  test(
    'migrates guest data on Microsoft register flow when requested',
    () async {
      repository.currentUserForTest = const AuthUser(
        id: 'guest-uid',
        isAnonymous: true,
      );
      repository.microsoftResult = const AuthUser(
        id: 'guest-uid',
        email: 'camera@example.com',
        isAnonymous: false,
      );

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthAuthenticated>().having(
            (state) => state.user.id,
            'id',
            'guest-uid',
          ),
        ]),
      );

      bloc.add(const AuthSignedInWithMicrosoft(shouldMigrateGuestData: true));
      await expectation;

      expect(migrationService.calls, 1);
      expect(migrationService.lastSourceUserId, 'guest-uid');
      expect(migrationService.lastTargetUserId, 'guest-uid');
    },
  );

  test('migrates guest data on email register flow when requested', () async {
    repository.currentUserForTest = const AuthUser(
      id: 'local_guest',
      isAnonymous: true,
    );
    repository.registerResult = const AuthUser(
      id: 'new-email-user',
      email: 'new-email@example.com',
      isAnonymous: false,
    );

    final expectation = expectLater(
      bloc.stream,
      emitsInOrder([
        isA<AuthLoading>(),
        isA<AuthAuthenticated>().having(
          (state) => state.user.id,
          'id',
          'new-email-user',
        ),
      ]),
    );

    bloc.add(
      const AuthRegisteredWithEmail(
        email: 'new-email@example.com',
        password: 'secret123',
        shouldMigrateGuestData: true,
      ),
    );
    await expectation;

    expect(migrationService.calls, 1);
    expect(migrationService.lastSourceUserId, 'local_guest');
    expect(migrationService.lastTargetUserId, 'new-email-user');
  });

  test(
    'does not migrate guest data when social sign-in resolves to existing account',
    () async {
      migrationService.preview = const GuestMigrationPreview(
        targetProjectCount: 1,
        projectConflicts: [
          ProjectConflictPreview(
            localProjectId: 'p-1',
            localName: 'Guest Project',
            localDescription: 'local',
            remoteOptions: [
              RemoteProjectOption(
                id: 'remote-p-1',
                name: 'Remote Project',
                description: 'remote',
              ),
            ],
            groupConflicts: [],
          ),
        ],
      );
      repository.currentUserForTest = const AuthUser(
        id: 'guest-uid',
        isAnonymous: true,
      );
      repository.googleResult = const AuthUser(
        id: 'existing-uid',
        email: 'existing@example.com',
        isAnonymous: false,
      );

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthAuthenticated>()
              .having((state) => state.user.id, 'id', 'existing-uid')
              .having(
                (state) => state.requiresMigrationConfirmation,
                'requiresMigrationConfirmation',
                isTrue,
              )
              .having(
                (state) => state.migrationSourceUserId,
                'migrationSourceUserId',
                'guest-uid',
              )
              .having(
                (state) => state.migrationPreview,
                'migrationPreview',
                migrationService.preview,
              ),
        ]),
      );

      bloc.add(const AuthSignedInWithGoogle(shouldMigrateGuestData: true));
      await expectation;

      expect(migrationService.calls, 0);
    },
  );

  test('forces migration after confirmation event', () async {
    repository.currentUserForTest = const AuthUser(
      id: 'existing-uid',
      email: 'existing@example.com',
      isAnonymous: false,
    );

    final expectation = expectLater(
      bloc.stream,
      emitsInOrder([
        isA<AuthLoading>(),
        isA<AuthAuthenticated>()
            .having((state) => state.user.id, 'id', 'existing-uid')
            .having(
              (state) => state.requiresMigrationConfirmation,
              'requiresMigrationConfirmation',
              isFalse,
            ),
      ]),
    );

    bloc.add(
      const AuthForcedGuestMigrationRequested(sourceUserId: 'guest-uid'),
    );
    await expectation;

    expect(migrationService.calls, 1);
    expect(migrationService.lastPlan, isA<GuestMigrationPlan>());
    expect(migrationService.lastSourceUserId, 'guest-uid');
    expect(migrationService.lastTargetUserId, 'existing-uid');
  });

  test(
    'keeps migration prompt open with validation issues when forced migration plan is invalid',
    () async {
      repository.currentUserForTest = const AuthUser(
        id: 'existing-uid',
        email: 'existing@example.com',
        isAnonymous: false,
      );
      migrationService.preview = const GuestMigrationPreview(
        targetProjectCount: 1,
        projectConflicts: [
          ProjectConflictPreview(
            localProjectId: 'p-1',
            localName: 'Guest Project',
            localDescription: 'local',
            remoteOptions: [
              RemoteProjectOption(
                id: 'remote-p-1',
                name: 'Remote Project',
                description: 'remote',
              ),
            ],
            groupConflicts: [],
          ),
        ],
      );
      migrationService
          .migrateException = const GuestMigrationPlanValidationException([
        'Group "Default Group" in project "Remote Project" has multiple overwrite sources.',
      ]);

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthAuthenticated>()
              .having(
                (state) => state.requiresMigrationConfirmation,
                'requiresMigrationConfirmation',
                isTrue,
              )
              .having(
                (state) => state.migrationSourceUserId,
                'migrationSourceUserId',
                'guest-uid',
              )
              .having(
                (state) => state.migrationValidationIssues,
                'migrationValidationIssues',
                isNotEmpty,
              ),
        ]),
      );

      bloc.add(
        const AuthForcedGuestMigrationRequested(sourceUserId: 'guest-uid'),
      );
      await expectation;
      expect(migrationService.calls, 0);
    },
  );

  test(
    'clears migration-confirmation state when prompt is dismissed',
    () async {
      repository.currentUserForTest = const AuthUser(
        id: 'existing-uid',
        email: 'existing@example.com',
        isAnonymous: false,
      );

      final expectation = expectLater(
        bloc.stream,
        emits(
          isA<AuthAuthenticated>()
              .having((state) => state.user.id, 'id', 'existing-uid')
              .having(
                (state) => state.requiresMigrationConfirmation,
                'requiresMigrationConfirmation',
                isFalse,
              ),
        ),
      );

      bloc.add(AuthMigrationPromptDismissed());
      await expectation;
    },
  );

  test(
    'migrates using fallback source when no active anonymous session exists',
    () async {
      guestDataService.sourceUserId = 'stored-guest-uid';
      repository.currentUserForTest = null;
      repository.googleResult = const AuthUser(
        id: 'new-google-user',
        email: 'new-google@example.com',
        isAnonymous: false,
      );

      final expectation = expectLater(
        bloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          isA<AuthAuthenticated>().having(
            (state) => state.user.id,
            'id',
            'new-google-user',
          ),
        ]),
      );

      bloc.add(const AuthSignedInWithGoogle(shouldMigrateGuestData: true));
      await expectation;

      expect(migrationService.calls, 1);
      expect(migrationService.lastSourceUserId, 'stored-guest-uid');
      expect(migrationService.lastTargetUserId, 'new-google-user');
    },
  );
}
