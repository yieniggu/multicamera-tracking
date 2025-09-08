import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';

abstract class SurveillanceCountCache {
  // seeders used by load use-cases
  void seedProjects(List<Project> projects);
  void seedGroups(String projectId, List<Group> groups);
  void seedCameras(String projectId, String groupId, List<Camera> cameras);

  // counters (nullable if unknown)
  int? projectCount();
  int? groupCount(String projectId);
  int? cameraCount(String projectId, String groupId);
}
