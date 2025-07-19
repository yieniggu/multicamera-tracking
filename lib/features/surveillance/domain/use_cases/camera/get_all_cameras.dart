import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/camera_repository.dart';

class GetAllCamerasUseCase {
  final CameraRepository repo;
  GetAllCamerasUseCase(this.repo);

  Future<List<Camera>> call(String userId) => repo.getAll(userId);
}
