import 'package:multicamera_tracking/shared/domain/services/guest_data_service.dart';

class ResolveGuestMigrationSourceUseCase {
  final GuestDataService service;

  ResolveGuestMigrationSourceUseCase(this.service);

  Future<String?> call({String? preferredSourceUserId}) {
    return service.resolveMigrationSourceUserId(
      preferredSourceUserId: preferredSourceUserId,
    );
  }
}
