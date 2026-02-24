import 'package:equatable/equatable.dart';

abstract class AccountSettingsEvent extends Equatable {
  const AccountSettingsEvent();

  @override
  List<Object?> get props => [];
}

class AccountSettingsRequested extends AccountSettingsEvent {
  const AccountSettingsRequested();
}

class AccountSettingsSetPasswordSubmitted extends AccountSettingsEvent {
  final String newPassword;

  const AccountSettingsSetPasswordSubmitted(this.newPassword);

  @override
  List<Object?> get props => [newPassword];
}

class AccountSettingsChangePasswordSubmitted extends AccountSettingsEvent {
  final String newPassword;

  const AccountSettingsChangePasswordSubmitted(this.newPassword);

  @override
  List<Object?> get props => [newPassword];
}

class AccountSettingsChangeEmailSubmitted extends AccountSettingsEvent {
  final String newEmail;

  const AccountSettingsChangeEmailSubmitted(this.newEmail);

  @override
  List<Object?> get props => [newEmail];
}

class AccountSettingsReauthenticateWithPasswordSubmitted
    extends AccountSettingsEvent {
  final String email;
  final String password;

  const AccountSettingsReauthenticateWithPasswordSubmitted({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class AccountSettingsReauthenticateWithGoogleRequested
    extends AccountSettingsEvent {
  const AccountSettingsReauthenticateWithGoogleRequested();
}

class AccountSettingsReauthenticateWithMicrosoftRequested
    extends AccountSettingsEvent {
  const AccountSettingsReauthenticateWithMicrosoftRequested();
}

class AccountSettingsFeedbackCleared extends AccountSettingsEvent {
  const AccountSettingsFeedbackCleared();
}
