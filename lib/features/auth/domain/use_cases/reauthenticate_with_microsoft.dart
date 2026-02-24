import '../repositories/auth_repository.dart';

class ReauthenticateWithMicrosoftUseCase {
  final AuthRepository repository;

  ReauthenticateWithMicrosoftUseCase(this.repository);

  Future<void> call() {
    return repository.reauthenticateWithMicrosoft();
  }
}
