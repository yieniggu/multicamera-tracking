import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/camera_repository.dart';

class GetCamerasByGroupUseCase {
  final CameraRepository repo;
  GetCamerasByGroupUseCase(this.repo);

  Future<List<Camera>> call(String projectId, String groupId) =>
      repo.getAllByGroup(projectId, groupId);
}
