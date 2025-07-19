import 'package:multicamera_tracking/shared/domain/services/guest_data_migration_service.dart';

class MigrateGuestDataUseCase {
  final GuestDataMigrationService migrationService;

  MigrateGuestDataUseCase(this.migrationService);

  Future<void> call() async {
    await migrationService.migrate();
  }
}
