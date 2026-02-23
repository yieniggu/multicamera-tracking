import 'package:multicamera_tracking/shared/domain/services/guest_data_service.dart';

class HasGuestDataToMigrateUseCase {
  final GuestDataService service;

  HasGuestDataToMigrateUseCase(this.service);

  Future<bool> call({String? sourceUserId}) =>
      service.hasDataToMigrate(sourceUserId: sourceUserId);
}
