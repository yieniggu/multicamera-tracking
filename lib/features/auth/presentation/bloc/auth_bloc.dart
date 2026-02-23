import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_failure_exception.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_provider_type.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_user.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/shared/domain/services/app_mode.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/get_current_user.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/link_pending_credential.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/register_with_email.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/sign_out.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_anonymously.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_with_email.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_with_google.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_with_microsoft.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/get_guest_migration_preview.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/init_user_data.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/migrate_guest_data.dart';
import 'package:multicamera_tracking/shared/domain/entities/guest_migration.dart';
import 'package:multicamera_tracking/shared/domain/entities/guest_migration_plan_validation_exception.dart';
import 'package:multicamera_tracking/shared/domain/use_cases/adopt_local_guest_data_for_user.dart';
import 'package:multicamera_tracking/shared/domain/use_cases/resolve_guest_migration_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final SignInWithEmailUseCase signInWithEmailUseCase;
  final SignInWithGoogleUseCase signInWithGoogleUseCase;
  final SignInWithMicrosoftUseCase signInWithMicrosoftUseCase;
  final RegisterWithEmailUseCase registerWithEmailUseCase;
  final SignInAnonymouslyUseCase signInAnonymouslyUseCase;
  final LinkPendingCredentialUseCase linkPendingCredentialUseCase;
  final SignOutUseCase signOutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;
  final InitUserDataUseCase initUserDataUseCase;
  final MigrateGuestDataUseCase migrateGuestDataUseCase;
  final GetGuestMigrationPreviewUseCase getGuestMigrationPreviewUseCase;
  final AdoptLocalGuestDataForUserUseCase adoptLocalGuestDataForUserUseCase;
  final ResolveGuestMigrationSourceUseCase resolveGuestMigrationSourceUseCase;
  final AppMode appMode;
  late final StreamSubscription _authSub;
  bool _isAuthActionInFlight = false;
  bool _pendingAuthStateCheck = false;
  bool _pendingMigrationAfterPasswordLink = false;

  AuthBloc({
    required this.authRepository,
    required this.signInWithEmailUseCase,
    required this.signInWithGoogleUseCase,
    required this.signInWithMicrosoftUseCase,
    required this.registerWithEmailUseCase,
    required this.signInAnonymouslyUseCase,
    required this.linkPendingCredentialUseCase,
    required this.signOutUseCase,
    required this.getCurrentUserUseCase,
    required this.initUserDataUseCase,
    required this.migrateGuestDataUseCase,
    required this.getGuestMigrationPreviewUseCase,
    required this.adoptLocalGuestDataForUserUseCase,
    required this.resolveGuestMigrationSourceUseCase,
    required this.appMode,
  }) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthSignedInWithEmail>(_onSignedInWithEmail);
    on<AuthSignedInWithGoogle>(_onSignedInWithGoogle);
    on<AuthSignedInWithMicrosoft>(_onSignedInWithMicrosoft);
    on<AuthRegisteredWithEmail>(_onRegisteredWithEmail);
    on<AuthSignedInAnonymously>(_onSignedInAnonymously);
    on<AuthPendingLinkResolvedWithProvider>(_onPendingLinkResolvedWithProvider);
    on<AuthPendingLinkCleared>(_onPendingLinkCleared);
    on<AuthForcedGuestMigrationRequested>(_onForcedGuestMigrationRequested);
    on<AuthMigrationPromptDismissed>(_onMigrationPromptDismissed);
    on<AuthSignedOut>(_onSignedOut);

    _authSub = authRepository.authStateChanges().listen((_) {
      if (_isAuthActionInFlight) {
        _pendingAuthStateCheck = true;
        return;
      }
      add(AuthCheckRequested());
    });
  }

  @override
  Future<void> close() {
    _authSub.cancel();
    return super.close();
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (_isAuthActionInFlight) {
      debugPrint(
        "[AUTH-BLOC]onCheckRequested: skipped while auth action is in flight",
      );
      return;
    }
    debugPrint("[AUTH-BLOC]onCheckRequested: starting auth check");
    final prefs = await SharedPreferences.getInstance();
    final user = getCurrentUserUseCase();
    if (user != null) {
      debugPrint("[AUTH-BLOC]onCheckRequested: found user: ${user.toString()}");
      final isGuest = user.isAnonymous;
      if (isGuest) {
        appMode.enterGuest();
      } else {
        appMode.enterRemote();
      }
      await prefs.setBool('is_guest', isGuest);
      await initUserDataUseCase();
      emit(AuthAuthenticated(user, isGuest: isGuest));
      debugPrint("[AUTH-BLOC]onCheckRequested: ending auth check");
      return;
    }

    final shouldRestoreGuest = prefs.getBool('is_guest') ?? false;
    if (shouldRestoreGuest) {
      final guestUser = await signInAnonymouslyUseCase();
      if (guestUser != null) {
        appMode.enterGuest();
        await adoptLocalGuestDataForUserUseCase(targetUserId: guestUser.id);
        await initUserDataUseCase();
        emit(AuthAuthenticated(guestUser, isGuest: true));
        debugPrint("[AUTH-BLOC]onCheckRequested: restored local guest session");
        return;
      }
      await prefs.setBool('is_guest', false);
    }

    debugPrint("[AUTH-BLOC]onCheckRequested: no user found");
    appMode.enterGuest();
    emit(AuthUnauthenticated());
    debugPrint("[AUTH-BLOC]onCheckRequested: ending auth check");
  }

  Future<void> _onSignedInWithEmail(
    AuthSignedInWithEmail event,
    Emitter<AuthState> emit,
  ) async {
    await _runAuthAction(emit, () async {
      final previousUser = getCurrentUserUseCase();
      final previousGuestUid = previousUser?.isAnonymous == true
          ? previousUser!.id
          : null;
      final shouldMigrate = _pendingMigrationAfterPasswordLink;
      final user = await signInWithEmailUseCase(event.email, event.password);
      await _tryLinkPendingCredential();
      final migrationOutcome = await _processMigrationDecision(
        migrationRequested: shouldMigrate,
        previousGuestUid: previousGuestUid,
        authenticatedUser: user,
      );
      await _onAuthSuccess(
        user,
        emit,
        requiresMigrationConfirmation:
            migrationOutcome.requiresMigrationConfirmation,
        migrationSourceUserId: migrationOutcome.migrationSourceUserId,
        migrationPreview: migrationOutcome.migrationPreview,
      );
      _pendingMigrationAfterPasswordLink = false;
    });
  }

  Future<void> _onSignedInWithGoogle(
    AuthSignedInWithGoogle event,
    Emitter<AuthState> emit,
  ) async {
    await _runAuthAction(emit, () async {
      final previousUser = getCurrentUserUseCase();
      final previousGuestUid = previousUser?.isAnonymous == true
          ? previousUser!.id
          : null;
      final user = await signInWithGoogleUseCase();
      await _tryLinkPendingCredential();
      final migrationOutcome = await _processMigrationDecision(
        migrationRequested: event.shouldMigrateGuestData,
        previousGuestUid: previousGuestUid,
        authenticatedUser: user,
      );
      await _onAuthSuccess(
        user,
        emit,
        requiresMigrationConfirmation:
            migrationOutcome.requiresMigrationConfirmation,
        migrationSourceUserId: migrationOutcome.migrationSourceUserId,
        migrationPreview: migrationOutcome.migrationPreview,
      );
    });
  }

  Future<void> _onSignedInWithMicrosoft(
    AuthSignedInWithMicrosoft event,
    Emitter<AuthState> emit,
  ) async {
    await _runAuthAction(emit, () async {
      final previousUser = getCurrentUserUseCase();
      final previousGuestUid = previousUser?.isAnonymous == true
          ? previousUser!.id
          : null;
      final user = await signInWithMicrosoftUseCase();
      await _tryLinkPendingCredential();
      final migrationOutcome = await _processMigrationDecision(
        migrationRequested: event.shouldMigrateGuestData,
        previousGuestUid: previousGuestUid,
        authenticatedUser: user,
      );
      await _onAuthSuccess(
        user,
        emit,
        requiresMigrationConfirmation:
            migrationOutcome.requiresMigrationConfirmation,
        migrationSourceUserId: migrationOutcome.migrationSourceUserId,
        migrationPreview: migrationOutcome.migrationPreview,
      );
    });
  }

  Future<void> _onRegisteredWithEmail(
    AuthRegisteredWithEmail event,
    Emitter<AuthState> emit,
  ) async {
    await _runAuthAction(emit, () async {
      final previousUser = getCurrentUserUseCase();
      final previousGuestUid = previousUser?.isAnonymous == true
          ? previousUser!.id
          : null;
      final user = await registerWithEmailUseCase(event.email, event.password);
      final migrationOutcome = await _processMigrationDecision(
        migrationRequested: event.shouldMigrateGuestData,
        previousGuestUid: previousGuestUid,
        authenticatedUser: user,
      );
      if (user != null) {
        await _tryLinkPendingCredential();
      }
      await _onAuthSuccess(
        user,
        emit,
        requiresMigrationConfirmation:
            migrationOutcome.requiresMigrationConfirmation,
        migrationSourceUserId: migrationOutcome.migrationSourceUserId,
        migrationPreview: migrationOutcome.migrationPreview,
      );
    });
  }

  Future<void> _onSignedInAnonymously(
    AuthSignedInAnonymously event,
    Emitter<AuthState> emit,
  ) async {
    await _runAuthAction(emit, () async {
      final user = await signInAnonymouslyUseCase();
      if (user != null) {
        appMode.enterGuest();

        await adoptLocalGuestDataForUserUseCase(targetUserId: user.id);
        await initUserDataUseCase();
        emit(AuthAuthenticated(user, isGuest: true));
      } else {
        emit(
          const AuthFailure(
            message: "auth.error.guestSignInFailed",
            code: AuthFailureCode.unknown,
          ),
        );
      }
    });
  }

  Future<void> _onPendingLinkResolvedWithProvider(
    AuthPendingLinkResolvedWithProvider event,
    Emitter<AuthState> emit,
  ) async {
    if (event.provider == AuthProviderType.password) {
      _pendingMigrationAfterPasswordLink = event.shouldMigrateGuestData;
      emit(
        const AuthFailure(
          message: "auth.error.linkWithPasswordRequired",
          code: AuthFailureCode.accountExistsWithDifferentCredential,
        ),
      );
      return;
    }
    if (event.provider == AuthProviderType.google) {
      add(
        AuthSignedInWithGoogle(
          shouldMigrateGuestData: event.shouldMigrateGuestData,
        ),
      );
      return;
    }
    if (event.provider == AuthProviderType.microsoft) {
      add(
        AuthSignedInWithMicrosoft(
          shouldMigrateGuestData: event.shouldMigrateGuestData,
        ),
      );
      return;
    }
    emit(
      const AuthFailure(
        message: "auth.error.unsupportedProvider",
        code: AuthFailureCode.unknown,
      ),
    );
  }

  Future<void> _onPendingLinkCleared(
    AuthPendingLinkCleared event,
    Emitter<AuthState> emit,
  ) async {
    _pendingMigrationAfterPasswordLink = false;
    authRepository.clearPendingAuthLink();
    emit(AuthUnauthenticated());
  }

  Future<void> _onForcedGuestMigrationRequested(
    AuthForcedGuestMigrationRequested event,
    Emitter<AuthState> emit,
  ) async {
    final beforeAction = state;
    final previousPreview = beforeAction is AuthAuthenticated
        ? beforeAction.migrationPreview
        : null;
    await _runAuthAction(emit, () async {
      final user = getCurrentUserUseCase();
      if (user == null) {
        emit(AuthUnauthenticated());
        return;
      }
      try {
        await migrateGuestDataUseCase(
          sourceUserId: event.sourceUserId,
          targetUserId: user.id,
          plan: event.plan,
        );
        emit(AuthAuthenticated(user, isGuest: false));
      } on GuestMigrationPlanValidationException catch (e) {
        for (final issue in e.issues) {
          debugPrint('[AUTH-BLOC][MIGRATION-BLOCKER] $issue');
        }
        GuestMigrationPreview? refreshedPreview = previousPreview;
        refreshedPreview ??= await getGuestMigrationPreviewUseCase(
          sourceUserId: event.sourceUserId,
          targetUserId: user.id,
        );
        emit(
          AuthAuthenticated(
            user,
            isGuest: false,
            requiresMigrationConfirmation: true,
            migrationSourceUserId: event.sourceUserId,
            migrationPreview: refreshedPreview,
            migrationValidationIssues: e.issues,
          ),
        );
      }
    });
  }

  Future<void> _onMigrationPromptDismissed(
    AuthMigrationPromptDismissed event,
    Emitter<AuthState> emit,
  ) async {
    final user = getCurrentUserUseCase();
    if (user == null) {
      emit(AuthUnauthenticated());
      return;
    }
    emit(AuthAuthenticated(user, isGuest: false));
  }

  Future<void> _onSignedOut(
    AuthSignedOut event,
    Emitter<AuthState> emit,
  ) async {
    await _runAuthAction(emit, () async {
      _pendingMigrationAfterPasswordLink = false;
      await signOutUseCase();

      // ensure we switch back to local mode after logout
      appMode.enterGuest();

      emit(AuthUnauthenticated());
    });
  }

  Future<void> _runAuthAction(
    Emitter<AuthState> emit,
    Future<void> Function() action,
  ) async {
    if (_isAuthActionInFlight) return;
    _isAuthActionInFlight = true;
    _pendingAuthStateCheck = false;
    emit(AuthLoading());
    try {
      await action();
    } on AuthFailureException catch (e) {
      debugPrint(
        "[AUTH-BLOC] Auth failure: code=${e.code}, details=${e.debugMessage}",
      );
      final pending = authRepository.pendingAuthLink;
      if (e.code == AuthFailureCode.accountExistsWithDifferentCredential &&
          pending != null) {
        emit(AuthLinkRequired(pendingLink: pending, code: e.code));
      } else {
        emit(AuthFailure(message: _messageFor(e), code: e.code));
      }
    } catch (e) {
      debugPrint("[AUTH-BLOC] Unexpected auth error: $e");
      debugPrintStack();
      emit(
        const AuthFailure(
          message: "auth.error.generic",
          code: AuthFailureCode.unknown,
        ),
      );
    } finally {
      _isAuthActionInFlight = false;
      if (_pendingAuthStateCheck) {
        final currentUser = getCurrentUserUseCase();
        final shouldReconcile =
            currentUser != null &&
            (state is AuthFailure || state is AuthLinkRequired);
        _pendingAuthStateCheck = false;
        if (shouldReconcile && !isClosed) {
          add(AuthCheckRequested());
        }
      }
    }
  }

  Future<void> _onAuthSuccess(
    AuthUser? user,
    Emitter<AuthState> emit, {
    bool requiresMigrationConfirmation = false,
    String? migrationSourceUserId,
    GuestMigrationPreview? migrationPreview,
  }) async {
    if (user == null) {
      emit(
        const AuthFailure(
          message: "auth.error.signInFailed",
          code: AuthFailureCode.unknown,
        ),
      );
      return;
    }
    appMode.enterRemote();
    await initUserDataUseCase();
    emit(
      AuthAuthenticated(
        user,
        isGuest: false,
        requiresMigrationConfirmation: requiresMigrationConfirmation,
        migrationSourceUserId: migrationSourceUserId,
        migrationPreview: migrationPreview,
      ),
    );
  }

  Future<void> _tryLinkPendingCredential() async {
    if (authRepository.pendingAuthLink == null) return;
    await linkPendingCredentialUseCase();
  }

  Future<_MigrationOutcome> _processMigrationDecision({
    required bool migrationRequested,
    required String? previousGuestUid,
    required AuthUser? authenticatedUser,
  }) async {
    if (!migrationRequested || authenticatedUser == null) {
      return const _MigrationOutcome();
    }

    final sourceUserId = await resolveGuestMigrationSourceUseCase(
      preferredSourceUserId: previousGuestUid,
    );
    if (sourceUserId == null) {
      return const _MigrationOutcome();
    }

    final preview = await getGuestMigrationPreviewUseCase(
      sourceUserId: sourceUserId,
      targetUserId: authenticatedUser.id,
    );

    if (!preview.targetHasData) {
      await migrateGuestDataUseCase(
        sourceUserId: sourceUserId,
        targetUserId: authenticatedUser.id,
      );
      return const _MigrationOutcome();
    }

    return _MigrationOutcome(
      requiresMigrationConfirmation: true,
      migrationSourceUserId: sourceUserId,
      migrationPreview: preview,
    );
  }

  String _messageFor(AuthFailureException e) {
    switch (e.code) {
      case AuthFailureCode.cancelled:
        return "auth.error.cancelled";
      case AuthFailureCode.invalidCredentials:
        return "auth.error.invalidCredentials";
      case AuthFailureCode.emailAlreadyInUse:
        return "auth.error.emailAlreadyInUse";
      case AuthFailureCode.accountExistsWithDifferentCredential:
        return "auth.error.accountExistsDifferentCredential";
      case AuthFailureCode.credentialAlreadyInUse:
        return "auth.error.credentialAlreadyInUse";
      case AuthFailureCode.requiresRecentLogin:
        return "auth.error.requiresRecentLogin";
      case AuthFailureCode.network:
        return "auth.error.network";
      case AuthFailureCode.pendingCredentialNotFound:
        return "auth.error.pendingCredentialNotFound";
      case AuthFailureCode.unknown:
        return "auth.error.generic";
    }
  }
}

class _MigrationOutcome {
  final bool requiresMigrationConfirmation;
  final String? migrationSourceUserId;
  final GuestMigrationPreview? migrationPreview;

  const _MigrationOutcome({
    this.requiresMigrationConfirmation = false,
    this.migrationSourceUserId,
    this.migrationPreview,
  });
}
