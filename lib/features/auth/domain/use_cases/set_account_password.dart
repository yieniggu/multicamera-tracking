import '../repositories/auth_repository.dart';

class SetAccountPasswordUseCase {
  final AuthRepository repository;

  SetAccountPasswordUseCase(this.repository);

  Future<void> call(String newPassword) {
    return repository.setPassword(newPassword);
  }
}
