import 'package:multicamera_tracking/features/user_profile/domain/repositories/user_profile_repository.dart';

class GetCurrentUserLanguageUseCase {
  final UserProfileRepository repository;

  GetCurrentUserLanguageUseCase(this.repository);

  Future<String?> call() => repository.getCurrentUserLanguage();
}
