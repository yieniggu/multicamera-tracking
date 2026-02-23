import 'package:equatable/equatable.dart';

import 'auth_provider_type.dart';

class PendingAuthLink extends Equatable {
  final String email;
  final List<AuthProviderType> existingProviders;
  final AuthProviderType pendingProvider;
  final bool canLinkImmediately;

  const PendingAuthLink({
    required this.email,
    required this.existingProviders,
    required this.pendingProvider,
    required this.canLinkImmediately,
  });

  @override
  List<Object?> get props => [
    email,
    existingProviders,
    pendingProvider,
    canLinkImmediately,
  ];
}
