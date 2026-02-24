import '../repositories/auth_repository.dart';

class ChangeAccountPasswordUseCase {
  final AuthRepository repository;

  ChangeAccountPasswordUseCase(this.repository);

  Future<void> call(String newPassword) {
    return repository.changePassword(newPassword);
  }
}
