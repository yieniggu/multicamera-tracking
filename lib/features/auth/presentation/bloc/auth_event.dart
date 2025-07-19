import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthSignedInWithEmail extends AuthEvent {
  final String email;
  final String password;

  const AuthSignedInWithEmail(this.email, this.password);

  @override
  List<Object> get props => [email, password];
}

class AuthRegisteredWithEmail extends AuthEvent {
  final String email;
  final String password;
  final bool shouldMigrateGuestData;

  const AuthRegisteredWithEmail({
    required this.email,
    required this.password,
    this.shouldMigrateGuestData = false,
  });
}

class AuthSignedInAnonymously extends AuthEvent {}

class AuthSignedOut extends AuthEvent {}
