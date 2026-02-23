import '../repositories/auth_repository.dart';

class LinkPendingCredentialUseCase {
  final AuthRepository repository;

  LinkPendingCredentialUseCase(this.repository);

  Future<bool> call() {
    return repository.linkPendingCredentialToCurrentUser();
  }
}
