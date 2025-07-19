import '../repositories/auth_repository.dart';
import '../entities/auth_user.dart';

class SignInWithEmailUseCase {
  final AuthRepository repository;

  SignInWithEmailUseCase(this.repository);

  Future<AuthUser?> call(String email, String password) {
    return repository.signInWithEmail(email, password);
  }
}
