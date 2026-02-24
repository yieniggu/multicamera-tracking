import 'package:multicamera_tracking/features/user_profile/domain/repositories/user_profile_repository.dart';

class EnsureCurrentUserProfileInitializedUseCase {
  final UserProfileRepository repository;

  EnsureCurrentUserProfileInitializedUseCase(this.repository);

  Future<void> call() => repository.ensureCurrentUserProfileInitialized();
}
