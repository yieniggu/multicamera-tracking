import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/camera_repository.dart';

import 'package:multicamera_tracking/shared/domain/services/quota_guard.dart';

class SaveCameraUseCase {
  final CameraRepository repo;
  final QuotaGuard quota;
  SaveCameraUseCase(this.repo, this.quota);
  Future<void> call(Camera camera) async {
    await quota.ensureCanCreateCamera(camera.projectId, camera.groupId);
    await repo.save(camera);
  }
}
