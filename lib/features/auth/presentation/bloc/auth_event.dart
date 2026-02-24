import 'package:equatable/equatable.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_provider_type.dart';
import 'package:multicamera_tracking/shared/domain/entities/guest_migration.dart';

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

  @override
  List<Object?> get props => [email, password, shouldMigrateGuestData];
}

class AuthSignedInAnonymously extends AuthEvent {}

class AuthSignedInWithGoogle extends AuthEvent {
  final bool shouldMigrateGuestData;

  const AuthSignedInWithGoogle({this.shouldMigrateGuestData = false});

  @override
  List<Object?> get props => [shouldMigrateGuestData];
}

class AuthSignedInWithMicrosoft extends AuthEvent {
  final bool shouldMigrateGuestData;
  final String? emailHint;

  const AuthSignedInWithMicrosoft({
    this.shouldMigrateGuestData = false,
    this.emailHint,
  });

  @override
  List<Object?> get props => [shouldMigrateGuestData, emailHint];
}

class AuthPendingLinkResolvedWithProvider extends AuthEvent {
  final AuthProviderType provider;
  final bool shouldMigrateGuestData;

  const AuthPendingLinkResolvedWithProvider(
    this.provider, {
    this.shouldMigrateGuestData = false,
  });

  @override
  List<Object?> get props => [provider, shouldMigrateGuestData];
}

class AuthPendingLinkCleared extends AuthEvent {}

class AuthForcedGuestMigrationRequested extends AuthEvent {
  final String sourceUserId;
  final GuestMigrationPlan plan;

  const AuthForcedGuestMigrationRequested({
    required this.sourceUserId,
    this.plan = const GuestMigrationPlan(),
  });

  @override
  List<Object?> get props => [sourceUserId, plan];
}

class AuthMigrationPromptDismissed extends AuthEvent {}

class AuthSignedOut extends AuthEvent {}

class AuthEmailVerificationCheckRequested extends AuthEvent {
  final bool silent;

  const AuthEmailVerificationCheckRequested({this.silent = false});

  @override
  List<Object?> get props => [silent];
}

class AuthEmailVerificationResendRequested extends AuthEvent {}

class AuthEmailVerificationFeedbackCleared extends AuthEvent {}
