import '../repositories/auth_repository.dart';

class SendEmailVerificationToCurrentUserUseCase {
  final AuthRepository repository;

  SendEmailVerificationToCurrentUserUseCase(this.repository);

  Future<void> call() {
    return repository.sendEmailVerificationToCurrentUser();
  }
}
