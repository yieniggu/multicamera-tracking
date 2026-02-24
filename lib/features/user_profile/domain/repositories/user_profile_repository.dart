import 'package:multicamera_tracking/features/user_profile/domain/entities/user_profile.dart';

abstract class UserProfileRepository {
  Future<void> ensureCurrentUserProfileInitialized();
  Future<UserProfile?> getCurrentUserProfile();
  Future<void> updateCurrentUserProfile({
    required String firstName,
    required String lastName,
    String? phoneNumber,
  });
  Future<String?> getCurrentUserLanguage();
  Future<void> updateCurrentUserLanguage(String languageCode);
}
