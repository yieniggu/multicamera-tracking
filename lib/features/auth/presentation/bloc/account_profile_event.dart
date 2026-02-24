import 'package:equatable/equatable.dart';

abstract class AccountProfileEvent extends Equatable {
  const AccountProfileEvent();

  @override
  List<Object?> get props => [];
}

class AccountProfileRequested extends AccountProfileEvent {
  const AccountProfileRequested();
}

class AccountProfileFirstNameChanged extends AccountProfileEvent {
  final String value;

  const AccountProfileFirstNameChanged(this.value);

  @override
  List<Object?> get props => [value];
}

class AccountProfileLastNameChanged extends AccountProfileEvent {
  final String value;

  const AccountProfileLastNameChanged(this.value);

  @override
  List<Object?> get props => [value];
}

class AccountProfilePhoneChanged extends AccountProfileEvent {
  final String value;

  const AccountProfilePhoneChanged(this.value);

  @override
  List<Object?> get props => [value];
}

class AccountProfileSaveSubmitted extends AccountProfileEvent {
  const AccountProfileSaveSubmitted();
}

class AccountProfileFeedbackCleared extends AccountProfileEvent {
  const AccountProfileFeedbackCleared();
}
