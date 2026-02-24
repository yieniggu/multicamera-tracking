import '../repositories/auth_repository.dart';

class ReauthenticateWithGoogleUseCase {
  final AuthRepository repository;

  ReauthenticateWithGoogleUseCase(this.repository);

  Future<void> call() {
    return repository.reauthenticateWithGoogle();
  }
}
