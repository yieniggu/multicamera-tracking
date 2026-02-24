import '../entities/auth_provider_type.dart';
import '../repositories/auth_repository.dart';

class GetLinkedSignInMethodsUseCase {
  final AuthRepository repository;

  GetLinkedSignInMethodsUseCase(this.repository);

  Future<List<AuthProviderType>> call() {
    return repository.getLinkedSignInMethods();
  }
}
