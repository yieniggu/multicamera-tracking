import 'package:multicamera_tracking/features/user_profile/domain/repositories/user_profile_repository.dart';

class UpdateCurrentUserProfileUseCase {
  final UserProfileRepository repository;

  UpdateCurrentUserProfileUseCase(this.repository);

  Future<void> call({
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) {
    return repository.updateCurrentUserProfile(
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
    );
  }
}
