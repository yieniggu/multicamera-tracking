import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_failure_exception.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/change_account_email.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/change_account_password.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/get_contact_email.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/get_linked_sign_in_methods.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/reauthenticate_with_google.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/reauthenticate_with_microsoft.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/reauthenticate_with_password.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/set_account_password.dart';

import 'account_settings_event.dart';
import 'account_settings_state.dart';

class AccountSettingsBloc
    extends Bloc<AccountSettingsEvent, AccountSettingsState> {
  final GetLinkedSignInMethodsUseCase getLinkedSignInMethodsUseCase;
  final GetContactEmailUseCase getContactEmailUseCase;
  final SetAccountPasswordUseCase setAccountPasswordUseCase;
  final ChangeAccountPasswordUseCase changeAccountPasswordUseCase;
  final ChangeAccountEmailUseCase changeAccountEmailUseCase;
  final ReauthenticateWithPasswordUseCase reauthenticateWithPasswordUseCase;
  final ReauthenticateWithGoogleUseCase reauthenticateWithGoogleUseCase;
  final ReauthenticateWithMicrosoftUseCase reauthenticateWithMicrosoftUseCase;

  AccountSettingsBloc({
    required this.getLinkedSignInMethodsUseCase,
    required this.getContactEmailUseCase,
    required this.setAccountPasswordUseCase,
    required this.changeAccountPasswordUseCase,
    required this.changeAccountEmailUseCase,
    required this.reauthenticateWithPasswordUseCase,
    required this.reauthenticateWithGoogleUseCase,
    required this.reauthenticateWithMicrosoftUseCase,
  }) : super(const AccountSettingsState.initial()) {
    on<AccountSettingsRequested>(_onRequested);
    on<AccountSettingsSetPasswordSubmitted>(_onSetPasswordSubmitted);
    on<AccountSettingsChangePasswordSubmitted>(_onChangePasswordSubmitted);
    on<AccountSettingsChangeEmailSubmitted>(_onChangeEmailSubmitted);
    on<AccountSettingsReauthenticateWithPasswordSubmitted>(
      _onReauthenticateWithPasswordSubmitted,
    );
    on<AccountSettingsReauthenticateWithGoogleRequested>(
      _onReauthenticateWithGoogleRequested,
    );
    on<AccountSettingsReauthenticateWithMicrosoftRequested>(
      _onReauthenticateWithMicrosoftRequested,
    );
    on<AccountSettingsFeedbackCleared>(_onFeedbackCleared);
  }

  Future<void> _onRequested(
    AccountSettingsRequested event,
    Emitter<AccountSettingsState> emit,
  ) async {
    if (state.isAnyActionInFlight) return;
    emit(
      state.copyWith(
        isLoading: true,
        lastErrorCode: null,
        lastErrorMessageKey: null,
        lastSuccessMessageKey: null,
      ),
    );
    await _refreshSnapshot(emit);
  }

  Future<void> _onSetPasswordSubmitted(
    AccountSettingsSetPasswordSubmitted event,
    Emitter<AccountSettingsState> emit,
  ) async {
    if (state.isAnyActionInFlight) return;
    emit(
      state.copyWith(
        isSetPasswordInFlight: true,
        lastErrorCode: null,
        lastErrorMessageKey: null,
        lastSuccessMessageKey: null,
      ),
    );
    await _runSensitiveOperation(
      emit,
      action: AccountSettingsPendingAction.setPassword,
      value: event.newPassword,
      execute: () => setAccountPasswordUseCase(event.newPassword),
      successMessageKey: 'account.success.passwordSet',
      finishFlag: (next) => next.copyWith(isSetPasswordInFlight: false),
    );
  }

  Future<void> _onChangePasswordSubmitted(
    AccountSettingsChangePasswordSubmitted event,
    Emitter<AccountSettingsState> emit,
  ) async {
    if (state.isAnyActionInFlight) return;
    emit(
      state.copyWith(
        isChangePasswordInFlight: true,
        lastErrorCode: null,
        lastErrorMessageKey: null,
        lastSuccessMessageKey: null,
      ),
    );
    await _runSensitiveOperation(
      emit,
      action: AccountSettingsPendingAction.changePassword,
      value: event.newPassword,
      execute: () => changeAccountPasswordUseCase(event.newPassword),
      successMessageKey: 'account.success.passwordChanged',
      finishFlag: (next) => next.copyWith(isChangePasswordInFlight: false),
    );
  }

  Future<void> _onChangeEmailSubmitted(
    AccountSettingsChangeEmailSubmitted event,
    Emitter<AccountSettingsState> emit,
  ) async {
    if (state.isAnyActionInFlight) return;
    emit(
      state.copyWith(
        isChangeEmailInFlight: true,
        lastErrorCode: null,
        lastErrorMessageKey: null,
        lastSuccessMessageKey: null,
      ),
    );
    await _runSensitiveOperation(
      emit,
      action: AccountSettingsPendingAction.changeEmail,
      value: event.newEmail,
      execute: () => changeAccountEmailUseCase(event.newEmail),
      successMessageKey: 'account.success.emailChanged',
      finishFlag: (next) => next.copyWith(isChangeEmailInFlight: false),
    );
  }

  Future<void> _onReauthenticateWithPasswordSubmitted(
    AccountSettingsReauthenticateWithPasswordSubmitted event,
    Emitter<AccountSettingsState> emit,
  ) async {
    await _runReauthentication(
      emit,
      () => reauthenticateWithPasswordUseCase(
        email: event.email,
        password: event.password,
      ),
    );
  }

  Future<void> _onReauthenticateWithGoogleRequested(
    AccountSettingsReauthenticateWithGoogleRequested event,
    Emitter<AccountSettingsState> emit,
  ) async {
    await _runReauthentication(emit, reauthenticateWithGoogleUseCase.call);
  }

  Future<void> _onReauthenticateWithMicrosoftRequested(
    AccountSettingsReauthenticateWithMicrosoftRequested event,
    Emitter<AccountSettingsState> emit,
  ) async {
    await _runReauthentication(emit, reauthenticateWithMicrosoftUseCase.call);
  }

  void _onFeedbackCleared(
    AccountSettingsFeedbackCleared event,
    Emitter<AccountSettingsState> emit,
  ) {
    emit(
      state.copyWith(
        lastErrorCode: null,
        lastErrorMessageKey: null,
        lastSuccessMessageKey: null,
      ),
    );
  }

  Future<void> _refreshSnapshot(Emitter<AccountSettingsState> emit) async {
    try {
      final methods = await getLinkedSignInMethodsUseCase();
      final email = await getContactEmailUseCase();
      emit(
        state.copyWith(
          isLoading: false,
          linkedMethods: methods,
          contactEmail: email,
          lastErrorCode: null,
          lastErrorMessageKey: null,
        ),
      );
    } on AuthFailureException catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          lastErrorCode: e.code,
          lastErrorMessageKey: _messageFor(e),
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          lastErrorCode: AuthFailureCode.unknown,
          lastErrorMessageKey: 'auth.error.generic',
        ),
      );
    }
  }

  Future<void> _runSensitiveOperation(
    Emitter<AccountSettingsState> emit, {
    required AccountSettingsPendingAction action,
    required String value,
    required Future<void> Function() execute,
    required String successMessageKey,
    required AccountSettingsState Function(AccountSettingsState) finishFlag,
  }) async {
    try {
      await execute();
      final methods = await getLinkedSignInMethodsUseCase();
      final email = await getContactEmailUseCase();
      emit(
        finishFlag(
          state.copyWith(
            linkedMethods: methods,
            contactEmail: email,
            pendingAction: AccountSettingsPendingAction.none,
            pendingValue: null,
            lastErrorCode: null,
            lastErrorMessageKey: null,
            lastSuccessMessageKey: successMessageKey,
          ),
        ),
      );
    } on AuthFailureException catch (e) {
      if (e.code == AuthFailureCode.requiresRecentLogin) {
        emit(
          finishFlag(
            state.copyWith(
              pendingAction: action,
              pendingValue: value,
              lastErrorCode: e.code,
              lastErrorMessageKey: _messageFor(e),
              lastSuccessMessageKey: null,
            ),
          ),
        );
        return;
      }
      emit(
        finishFlag(
          state.copyWith(
            lastErrorCode: e.code,
            lastErrorMessageKey: _messageFor(e),
            lastSuccessMessageKey: null,
          ),
        ),
      );
    } catch (_) {
      emit(
        finishFlag(
          state.copyWith(
            lastErrorCode: AuthFailureCode.unknown,
            lastErrorMessageKey: 'auth.error.generic',
            lastSuccessMessageKey: null,
          ),
        ),
      );
    }
  }

  Future<void> _runReauthentication(
    Emitter<AccountSettingsState> emit,
    Future<void> Function() reauthenticate,
  ) async {
    if (!state.requiresReauth || state.isAnyActionInFlight) return;

    emit(
      state.copyWith(
        isReauthInFlight: true,
        lastErrorCode: null,
        lastErrorMessageKey: null,
        lastSuccessMessageKey: null,
      ),
    );

    try {
      await reauthenticate();
      emit(state.copyWith(isReauthInFlight: false));
      await _retryPendingAction(emit);
    } on AuthFailureException catch (e) {
      emit(
        state.copyWith(
          isReauthInFlight: false,
          lastErrorCode: e.code,
          lastErrorMessageKey: _messageFor(e),
          lastSuccessMessageKey: null,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isReauthInFlight: false,
          lastErrorCode: AuthFailureCode.unknown,
          lastErrorMessageKey: 'auth.error.generic',
          lastSuccessMessageKey: null,
        ),
      );
    }
  }

  Future<void> _retryPendingAction(Emitter<AccountSettingsState> emit) async {
    final action = state.pendingAction;
    final value = state.pendingValue;
    if (action == AccountSettingsPendingAction.none || value == null) {
      return;
    }

    switch (action) {
      case AccountSettingsPendingAction.setPassword:
        add(AccountSettingsSetPasswordSubmitted(value));
        return;
      case AccountSettingsPendingAction.changePassword:
        add(AccountSettingsChangePasswordSubmitted(value));
        return;
      case AccountSettingsPendingAction.changeEmail:
        add(AccountSettingsChangeEmailSubmitted(value));
        return;
      case AccountSettingsPendingAction.none:
        return;
    }
  }

  String _messageFor(AuthFailureException e) {
    switch (e.code) {
      case AuthFailureCode.cancelled:
        return 'auth.error.cancelled';
      case AuthFailureCode.invalidCredentials:
        return 'auth.error.invalidCredentials';
      case AuthFailureCode.emailNotVerified:
        return 'auth.error.emailNotVerified';
      case AuthFailureCode.emailAlreadyInUse:
      case AuthFailureCode.accountAlreadyExists:
        return 'auth.error.accountAlreadyExists';
      case AuthFailureCode.accountExistsWithDifferentCredential:
        return 'auth.error.accountExistsDifferentCredential';
      case AuthFailureCode.credentialAlreadyInUse:
        return 'auth.error.credentialAlreadyInUse';
      case AuthFailureCode.requiresRecentLogin:
        return 'auth.error.requiresRecentLogin';
      case AuthFailureCode.network:
        return 'auth.error.network';
      case AuthFailureCode.pendingCredentialNotFound:
        return 'auth.error.pendingCredentialNotFound';
      case AuthFailureCode.unknown:
        return 'auth.error.generic';
    }
  }
}
