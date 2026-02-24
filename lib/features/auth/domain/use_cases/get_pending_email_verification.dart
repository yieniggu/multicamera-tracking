import '../repositories/auth_repository.dart';

class GetPendingEmailVerificationUseCase {
  final AuthRepository repository;

  GetPendingEmailVerificationUseCase(this.repository);

  Future<String?> call() {
    return repository.getPendingEmailVerificationEmail();
  }
}
