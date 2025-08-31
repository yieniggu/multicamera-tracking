import 'package:multicamera_tracking/features/surveillance/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/camera_repository.dart';
import 'package:multicamera_tracking/shared/domain/services/quota_guard.dart';
import 'package:multicamera_tracking/shared/utils/app_mode.dart';
import 'package:multicamera_tracking/shared/errors/quota_exceeded_exception.dart';
import 'package:multicamera_tracking/shared/constants/quota.dart';

class QuotaGuardImpl implements QuotaGuard {
  final ProjectRepository projects;
  final GroupRepository groups;
  final CameraRepository cameras;

  QuotaGuardImpl({
    required this.projects,
    required this.groups,
    required this.cameras,
  });

  bool get _trial => isTrialLocalMode();

  @override
  Future<void> ensureCanCreateProject() async {
    if (!_trial) return;
    final list = await projects.getAll();
    if (list.length >= Quota.projects) {
      throw QuotaExceededException(
        "Trial limit: max ${Quota.projects} project.",
      );
    }
  }

  @override
  Future<void> ensureCanCreateGroup(String projectId) async {
    if (!_trial) return;
    final list = await groups.getAllByProject(projectId);
    if (list.length >= Quota.groupsPerProject) {
      throw QuotaExceededException(
        "Trial limit: max ${Quota.groupsPerProject} group per project.",
      );
    }
  }

  @override
  Future<void> ensureCanCreateCamera(String projectId, String groupId) async {
    if (!_trial) return;
    final list = await cameras.getAllByGroup(projectId, groupId);
    if (list.length >= Quota.camerasPerGroup) {
      throw QuotaExceededException(
        "Trial limit: max ${Quota.camerasPerGroup} cameras per group.",
      );
    }
  }
}
