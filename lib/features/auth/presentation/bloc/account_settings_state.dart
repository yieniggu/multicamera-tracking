import 'package:equatable/equatable.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_failure_exception.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_provider_type.dart';

enum AccountSettingsPendingAction {
  none,
  setPassword,
  changePassword,
  changeEmail,
}

class AccountSettingsState extends Equatable {
  static const _unset = Object();

  final bool isLoading;
  final bool isSetPasswordInFlight;
  final bool isChangePasswordInFlight;
  final bool isChangeEmailInFlight;
  final bool isReauthInFlight;
  final List<AuthProviderType> linkedMethods;
  final String? contactEmail;
  final AuthFailureCode? lastErrorCode;
  final String? lastErrorMessageKey;
  final String? lastSuccessMessageKey;
  final AccountSettingsPendingAction pendingAction;
  final String? pendingValue;

  const AccountSettingsState({
    required this.isLoading,
    required this.isSetPasswordInFlight,
    required this.isChangePasswordInFlight,
    required this.isChangeEmailInFlight,
    required this.isReauthInFlight,
    required this.linkedMethods,
    this.contactEmail,
    this.lastErrorCode,
    this.lastErrorMessageKey,
    this.lastSuccessMessageKey,
    this.pendingAction = AccountSettingsPendingAction.none,
    this.pendingValue,
  });

  const AccountSettingsState.initial()
    : isLoading = false,
      isSetPasswordInFlight = false,
      isChangePasswordInFlight = false,
      isChangeEmailInFlight = false,
      isReauthInFlight = false,
      linkedMethods = const [],
      contactEmail = null,
      lastErrorCode = null,
      lastErrorMessageKey = null,
      lastSuccessMessageKey = null,
      pendingAction = AccountSettingsPendingAction.none,
      pendingValue = null;

  bool get hasPasswordMethod =>
      linkedMethods.contains(AuthProviderType.password);
  bool get requiresReauth => pendingAction != AccountSettingsPendingAction.none;
  bool get isAnyActionInFlight =>
      isLoading ||
      isSetPasswordInFlight ||
      isChangePasswordInFlight ||
      isChangeEmailInFlight ||
      isReauthInFlight;

  AccountSettingsState copyWith({
    bool? isLoading,
    bool? isSetPasswordInFlight,
    bool? isChangePasswordInFlight,
    bool? isChangeEmailInFlight,
    bool? isReauthInFlight,
    List<AuthProviderType>? linkedMethods,
    Object? contactEmail = _unset,
    Object? lastErrorCode = _unset,
    Object? lastErrorMessageKey = _unset,
    Object? lastSuccessMessageKey = _unset,
    AccountSettingsPendingAction? pendingAction,
    Object? pendingValue = _unset,
  }) {
    return AccountSettingsState(
      isLoading: isLoading ?? this.isLoading,
      isSetPasswordInFlight:
          isSetPasswordInFlight ?? this.isSetPasswordInFlight,
      isChangePasswordInFlight:
          isChangePasswordInFlight ?? this.isChangePasswordInFlight,
      isChangeEmailInFlight:
          isChangeEmailInFlight ?? this.isChangeEmailInFlight,
      isReauthInFlight: isReauthInFlight ?? this.isReauthInFlight,
      linkedMethods: linkedMethods ?? this.linkedMethods,
      contactEmail: identical(contactEmail, _unset)
          ? this.contactEmail
          : contactEmail as String?,
      lastErrorCode: identical(lastErrorCode, _unset)
          ? this.lastErrorCode
          : lastErrorCode as AuthFailureCode?,
      lastErrorMessageKey: identical(lastErrorMessageKey, _unset)
          ? this.lastErrorMessageKey
          : lastErrorMessageKey as String?,
      lastSuccessMessageKey: identical(lastSuccessMessageKey, _unset)
          ? this.lastSuccessMessageKey
          : lastSuccessMessageKey as String?,
      pendingAction: pendingAction ?? this.pendingAction,
      pendingValue: identical(pendingValue, _unset)
          ? this.pendingValue
          : pendingValue as String?,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isSetPasswordInFlight,
    isChangePasswordInFlight,
    isChangeEmailInFlight,
    isReauthInFlight,
    linkedMethods,
    contactEmail,
    lastErrorCode,
    lastErrorMessageKey,
    lastSuccessMessageKey,
    pendingAction,
    pendingValue,
  ];
}
