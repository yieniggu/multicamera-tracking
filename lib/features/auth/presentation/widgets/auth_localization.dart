import 'package:flutter/widgets.dart';
import 'package:multicamera_tracking/l10n/app_localizations.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_provider_type.dart';

String authErrorMessage(BuildContext context, String key) {
  final l10n = AppLocalizations.of(context)!;
  switch (key) {
    case "auth.error.signInFailed":
      return l10n.authErrorSignInFailed;
    case "auth.error.guestSignInFailed":
      return l10n.authErrorGuestSignInFailed;
    case "auth.error.cancelled":
      return l10n.authErrorCancelled;
    case "auth.error.invalidCredentials":
      return l10n.authErrorInvalidCredentials;
    case "auth.error.emailNotVerified":
      return l10n.authErrorEmailNotVerified;
    case "auth.error.emailAlreadyInUse":
      return l10n.authErrorEmailAlreadyInUse;
    case "auth.error.accountAlreadyExists":
      return l10n.authErrorAccountAlreadyExists;
    case "auth.error.accountExistsDifferentCredential":
      return l10n.authErrorAccountExistsDifferentCredential;
    case "auth.error.credentialAlreadyInUse":
      return l10n.authErrorCredentialAlreadyInUse;
    case "auth.error.requiresRecentLogin":
      return l10n.authErrorRequiresRecentLogin;
    case "auth.error.network":
      return l10n.authErrorNetwork;
    case "auth.error.pendingCredentialNotFound":
      return l10n.authErrorPendingCredentialNotFound;
    case "auth.error.linkWithPasswordRequired":
      return l10n.authErrorLinkWithPasswordRequired;
    case "auth.error.unsupportedProvider":
      return l10n.authErrorUnsupportedProvider;
    case "auth.error.generic":
    default:
      return l10n.authErrorGeneric;
  }
}

String authProviderLabel(BuildContext context, AuthProviderType provider) {
  final l10n = AppLocalizations.of(context)!;
  switch (provider) {
    case AuthProviderType.google:
      return "Google";
    case AuthProviderType.microsoft:
      return "Microsoft";
    case AuthProviderType.password:
      return l10n.authUsePasswordToContinue;
    case AuthProviderType.unknown:
      return "Provider";
  }
}
