import 'package:equatable/equatable.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_user.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final AuthUser user;
  final bool isGuest;

  const AuthAuthenticated(this.user, {this.isGuest = false});

  @override
  List<Object?> get props => [user, isGuest];
}

class AuthUnauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object> get props => [message];
}
