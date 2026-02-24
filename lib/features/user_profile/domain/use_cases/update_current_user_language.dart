import 'package:multicamera_tracking/features/user_profile/domain/repositories/user_profile_repository.dart';

class UpdateCurrentUserLanguageUseCase {
  final UserProfileRepository repository;

  UpdateCurrentUserLanguageUseCase(this.repository);

  Future<void> call(String languageCode) {
    return repository.updateCurrentUserLanguage(languageCode);
  }
}
