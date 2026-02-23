import 'package:multicamera_tracking/shared/domain/entities/guest_migration.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_data_migration_service.dart';

class MigrateGuestDataUseCase {
  final GuestDataMigrationService migrationService;

  MigrateGuestDataUseCase(this.migrationService);

  Future<void> call({
    required String sourceUserId,
    required String targetUserId,
    GuestMigrationPlan? plan,
  }) async {
    await migrationService.migrate(
      sourceUserId: sourceUserId,
      targetUserId: targetUserId,
      plan: plan,
    );
  }
}
