import '../repositories/auth_repository.dart';
import '../entities/auth_user.dart';

class SignInAnonymouslyUseCase {
  final AuthRepository repository;

  SignInAnonymouslyUseCase(this.repository);

  Future<AuthUser?> call() {
    return repository.signInAnonymously();
  }
}
