import 'package:multicamera_tracking/features/surveillance/domain/repositories/camera_repository.dart';

class DeleteCameraByGroupUseCase {
  final CameraRepository repo;
  DeleteCameraByGroupUseCase(this.repo);

  Future<void> call(String projectId, String groupId, String id) =>
      repo.deleteById(projectId, groupId, id);
}
