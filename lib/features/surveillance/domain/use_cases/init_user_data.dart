import '../../../../shared/domain/services/init_user_data_service.dart';

class InitUserDataUseCase {
  final InitUserDataService _service;

  InitUserDataUseCase(this._service);

  Future<void> call() => _service.ensureDefaultProjectAndGroup();
}
