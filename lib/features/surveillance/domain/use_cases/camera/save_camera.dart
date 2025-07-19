import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/camera_repository.dart';

class SaveCameraUseCase {
  final CameraRepository repo;
  SaveCameraUseCase(this.repo);

  Future<void> call(Camera camera) => repo.save(camera);
}
