import '../repositories/auth_repository.dart';
import '../entities/auth_user.dart';

class GetAuthStateChangesUseCase {
  final AuthRepository repository;

  GetAuthStateChangesUseCase(this.repository);

  Stream<AuthUser?> call() {
    return repository.authStateChanges();
  }
}
