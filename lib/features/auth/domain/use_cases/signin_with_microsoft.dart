import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class SignInWithMicrosoftUseCase {
  final AuthRepository repository;

  SignInWithMicrosoftUseCase(this.repository);

  Future<AuthUser?> call() {
    return repository.signInWithMicrosoft();
  }
}
