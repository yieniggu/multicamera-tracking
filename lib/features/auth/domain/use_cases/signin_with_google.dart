import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class SignInWithGoogleUseCase {
  final AuthRepository repository;

  SignInWithGoogleUseCase(this.repository);

  Future<AuthUser?> call() {
    return repository.signInWithGoogle();
  }
}
