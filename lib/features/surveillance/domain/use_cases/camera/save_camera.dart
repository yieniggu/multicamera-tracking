import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/camera_repository.dart';
import 'package:multicamera_tracking/shared/domain/services/quota_guard.dart';

class SaveCameraUseCase {
  final CameraRepository repo;
  final QuotaGuard quota;
  SaveCameraUseCase(this.repo, this.quota);

  Future<void> call(Camera camera) async {
    final existing = await repo.getAllByGroup(camera.projectId, camera.groupId);
    final isCreating = !existing.any((c) => c.id == camera.id);
    if (isCreating) {
      await quota.ensureCanCreateCamera(camera.projectId, camera.groupId);
    }
    await repo.save(camera);
  }
}
