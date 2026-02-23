import 'package:multicamera_tracking/shared/domain/services/guest_data_service.dart';

class ResetLocalDebugDataUseCase {
  final GuestDataService service;

  ResetLocalDebugDataUseCase(this.service);

  Future<void> call() => service.clearLocalData();
}
