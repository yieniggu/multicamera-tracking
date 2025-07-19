import '../repositories/auth_repository.dart';
import '../entities/auth_user.dart';

class GetCurrentUserUseCase {
  final AuthRepository repository;

  GetCurrentUserUseCase(this.repository);

  AuthUser? call() {
    return repository.currentUser;
  }
}
