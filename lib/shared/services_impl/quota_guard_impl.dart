import 'package:multicamera_tracking/features/surveillance/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/camera_repository.dart';
import 'package:multicamera_tracking/shared/domain/services/quota_guard.dart';
import 'package:multicamera_tracking/shared/domain/services/app_mode.dart';

class QuotaGuardImpl implements QuotaGuard {
  QuotaGuardImpl({
    required ProjectRepository projects,
    required GroupRepository groups,
    required CameraRepository cameras,
    required AppMode appMode,
  });

  @override
  Future<void> ensureCanCreateProject() async {}

  @override
  Future<void> ensureCanCreateGroup(String projectId) async {}

  @override
  Future<void> ensureCanCreateCamera(String projectId, String groupId) async {}
}
