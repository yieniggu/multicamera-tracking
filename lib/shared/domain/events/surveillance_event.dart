import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';

sealed class SurveillanceEvent {}

// Projects
final class ProjectUpserted extends SurveillanceEvent {
  final Project project;
  ProjectUpserted(this.project);
}

final class ProjectDeleted extends SurveillanceEvent {
  final String projectId;
  ProjectDeleted(this.projectId);
}

// Groups
final class GroupUpserted extends SurveillanceEvent {
  final Group group;
  GroupUpserted(this.group);
}

final class GroupDeleted extends SurveillanceEvent {
  final String projectId;
  final String groupId;
  GroupDeleted(this.projectId, this.groupId);
}

// Cameras
final class CameraUpserted extends SurveillanceEvent {
  final Camera camera;
  CameraUpserted(this.camera);
}

final class CameraDeleted extends SurveillanceEvent {
  final String projectId;
  final String groupId;
  final String cameraId;
  CameraDeleted(this.projectId, this.groupId, this.cameraId);
}

final class CamerasClearedForGroup extends SurveillanceEvent {
  final String projectId;
  final String groupId;
  CamerasClearedForGroup(this.projectId, this.groupId);
}
