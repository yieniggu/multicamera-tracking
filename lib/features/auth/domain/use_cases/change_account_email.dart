import '../repositories/auth_repository.dart';

class ChangeAccountEmailUseCase {
  final AuthRepository repository;

  ChangeAccountEmailUseCase(this.repository);

  Future<void> call(String newEmail) {
    return repository.changeEmail(newEmail);
  }
}
