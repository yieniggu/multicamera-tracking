import 'package:multicamera_tracking/shared/domain/services/guest_data_service.dart';

class AdoptLocalGuestDataForUserUseCase {
  final GuestDataService service;

  AdoptLocalGuestDataForUserUseCase(this.service);

  Future<bool> call({
    required String targetUserId,
    String? preferredSourceUserId,
  }) {
    return service.adoptLocalDataForUser(
      targetUserId: targetUserId,
      preferredSourceUserId: preferredSourceUserId,
    );
  }
}
