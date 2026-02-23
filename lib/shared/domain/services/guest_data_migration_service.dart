import 'package:multicamera_tracking/shared/domain/entities/guest_migration.dart';

abstract class GuestDataMigrationService {
  Future<GuestMigrationPreview> buildPreview({
    required String sourceUserId,
    required String targetUserId,
  });

  Future<void> migrate({
    required String sourceUserId,
    required String targetUserId,
    GuestMigrationPlan? plan,
  });
}
