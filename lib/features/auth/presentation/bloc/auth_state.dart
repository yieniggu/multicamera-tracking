import 'package:equatable/equatable.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_failure_exception.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/pending_auth_link.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/auth_user.dart';
import 'package:multicamera_tracking/shared/domain/entities/guest_migration.dart';

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
  final bool requiresMigrationConfirmation;
  final String? migrationSourceUserId;
  final GuestMigrationPreview? migrationPreview;
  final List<String> migrationValidationIssues;

  const AuthAuthenticated(
    this.user, {
    this.isGuest = false,
    this.requiresMigrationConfirmation = false,
    this.migrationSourceUserId,
    this.migrationPreview,
    this.migrationValidationIssues = const [],
  });

  @override
  List<Object?> get props => [
    user,
    isGuest,
    requiresMigrationConfirmation,
    migrationSourceUserId,
    migrationPreview,
    migrationValidationIssues,
  ];
}

class AuthUnauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;
  final AuthFailureCode code;

  const AuthFailure({
    required this.message,
    this.code = AuthFailureCode.unknown,
  });

  @override
  List<Object> get props => [message, code];
}

class AuthLinkRequired extends AuthState {
  final PendingAuthLink pendingLink;
  final AuthFailureCode code;

  const AuthLinkRequired({
    required this.pendingLink,
    this.code = AuthFailureCode.accountExistsWithDifferentCredential,
  });

  @override
  List<Object?> get props => [pendingLink, code];
}

class AuthEmailVerificationRequired extends AuthState {
  final String email;
  final bool isChecking;
  final bool isResending;
  final String? feedbackMessageKey;

  const AuthEmailVerificationRequired({
    required this.email,
    this.isChecking = false,
    this.isResending = false,
    this.feedbackMessageKey,
  });

  AuthEmailVerificationRequired copyWith({
    String? email,
    bool? isChecking,
    bool? isResending,
    String? feedbackMessageKey,
    bool clearFeedback = false,
  }) {
    return AuthEmailVerificationRequired(
      email: email ?? this.email,
      isChecking: isChecking ?? this.isChecking,
      isResending: isResending ?? this.isResending,
      feedbackMessageKey: clearFeedback
          ? null
          : (feedbackMessageKey ?? this.feedbackMessageKey),
    );
  }

  @override
  List<Object?> get props => [
    email,
    isChecking,
    isResending,
    feedbackMessageKey,
  ];
}
