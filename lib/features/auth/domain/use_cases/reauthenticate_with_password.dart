import '../repositories/auth_repository.dart';

class ReauthenticateWithPasswordUseCase {
  final AuthRepository repository;

  ReauthenticateWithPasswordUseCase(this.repository);

  Future<void> call({required String email, required String password}) {
    return repository.reauthenticateWithPassword(
      email: email,
      password: password,
    );
  }
}
