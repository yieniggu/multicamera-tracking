import 'package:multicamera_tracking/features/user_profile/domain/entities/user_profile.dart';
import 'package:multicamera_tracking/features/user_profile/domain/repositories/user_profile_repository.dart';

class GetCurrentUserProfileUseCase {
  final UserProfileRepository repository;

  GetCurrentUserProfileUseCase(this.repository);

  Future<UserProfile?> call() => repository.getCurrentUserProfile();
}
