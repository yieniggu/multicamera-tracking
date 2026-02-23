import 'package:multicamera_tracking/shared/domain/entities/guest_migration.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_data_migration_service.dart';

class GetGuestMigrationPreviewUseCase {
  final GuestDataMigrationService migrationService;

  GetGuestMigrationPreviewUseCase(this.migrationService);

  Future<GuestMigrationPreview> call({
    required String sourceUserId,
    required String targetUserId,
  }) {
    return migrationService.buildPreview(
      sourceUserId: sourceUserId,
      targetUserId: targetUserId,
    );
  }
}
