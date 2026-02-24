import '../repositories/auth_repository.dart';

class GetContactEmailUseCase {
  final AuthRepository repository;

  GetContactEmailUseCase(this.repository);

  Future<String?> call() {
    return repository.getContactEmail();
  }
}
