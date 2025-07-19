import 'package:multicamera_tracking/features/surveillance/domain/repositories/camera_repository.dart';

class ClearCamerasByGroupUseCase {
  final CameraRepository repo;
  ClearCamerasByGroupUseCase(this.repo);

  Future<void> call(String projectId, String groupId) =>
      repo.clearAllByGroup(projectId, groupId);
}
