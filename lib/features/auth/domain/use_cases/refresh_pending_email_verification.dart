import '../repositories/auth_repository.dart';

class RefreshPendingEmailVerificationUseCase {
  final AuthRepository repository;

  RefreshPendingEmailVerificationUseCase(this.repository);

  Future<String?> call() {
    return repository.refreshPendingEmailVerificationEmail();
  }
}
