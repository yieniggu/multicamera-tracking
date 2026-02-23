import 'package:equatable/equatable.dart';

enum MergeStrategy { merge, overwrite, skip }

class RemoteCameraOption extends Equatable {
  final String id;
  final String name;
  final String description;

  const RemoteCameraOption({
    required this.id,
    required this.name,
    required this.description,
  });

  @override
  List<Object?> get props => [id, name, description];
}

class CameraConflictPreview extends Equatable {
  final String localCameraId;
  final String localName;
  final String localDescription;
  final List<RemoteCameraOption> remoteOptions;

  const CameraConflictPreview({
    required this.localCameraId,
    required this.localName,
    required this.localDescription,
    this.remoteOptions = const [],
  });

  @override
  List<Object?> get props => [
    localCameraId,
    localName,
    localDescription,
    remoteOptions,
  ];
}

class RemoteGroupOption extends Equatable {
  final String id;
  final String name;
  final String description;
  final List<RemoteCameraOption> cameras;

  const RemoteGroupOption({
    required this.id,
    required this.name,
    required this.description,
    this.cameras = const [],
  });

  @override
  List<Object?> get props => [id, name, description, cameras];
}

class GroupConflictPreview extends Equatable {
  final String localGroupId;
  final String localName;
  final String localDescription;
  final List<CameraConflictPreview> cameraConflicts;

  const GroupConflictPreview({
    required this.localGroupId,
    required this.localName,
    required this.localDescription,
    this.cameraConflicts = const [],
  });

  @override
  List<Object?> get props => [
    localGroupId,
    localName,
    localDescription,
    cameraConflicts,
  ];
}

class RemoteProjectOption extends Equatable {
  final String id;
  final String name;
  final String description;
  final List<RemoteGroupOption> groups;

  const RemoteProjectOption({
    required this.id,
    required this.name,
    required this.description,
    this.groups = const [],
  });

  @override
  List<Object?> get props => [id, name, description, groups];
}

class ProjectConflictPreview extends Equatable {
  final String localProjectId;
  final String localName;
  final String localDescription;
  final List<RemoteProjectOption> remoteOptions;
  final List<GroupConflictPreview> groupConflicts;

  const ProjectConflictPreview({
    required this.localProjectId,
    required this.localName,
    required this.localDescription,
    this.remoteOptions = const [],
    this.groupConflicts = const [],
  });

  @override
  List<Object?> get props => [
    localProjectId,
    localName,
    localDescription,
    remoteOptions,
    groupConflicts,
  ];
}

class GuestMigrationPreview extends Equatable {
  final List<ProjectConflictPreview> projectConflicts;
  final int sourceProjectCount;
  final int targetProjectCount;

  const GuestMigrationPreview({
    required this.projectConflicts,
    this.sourceProjectCount = 0,
    this.targetProjectCount = 0,
  });

  bool get targetHasData => targetProjectCount > 0;
  bool get hasSourceData => sourceProjectCount > 0;

  @override
  List<Object?> get props => [
    projectConflicts,
    sourceProjectCount,
    targetProjectCount,
  ];
}

class CameraMergeResolution extends Equatable {
  final String localCameraId;
  final MergeStrategy strategy;
  final String? targetRemoteCameraId;

  const CameraMergeResolution({
    required this.localCameraId,
    this.strategy = MergeStrategy.merge,
    this.targetRemoteCameraId,
  });

  @override
  List<Object?> get props => [localCameraId, strategy, targetRemoteCameraId];
}

class GroupMergeResolution extends Equatable {
  final String localGroupId;
  final MergeStrategy strategy;
  final String? targetRemoteGroupId;
  final Map<String, CameraMergeResolution> cameraResolutions;

  const GroupMergeResolution({
    required this.localGroupId,
    this.strategy = MergeStrategy.merge,
    this.targetRemoteGroupId,
    this.cameraResolutions = const {},
  });

  CameraMergeResolution resolutionForCamera(String localCameraId) {
    return cameraResolutions[localCameraId] ??
        CameraMergeResolution(localCameraId: localCameraId);
  }

  @override
  List<Object?> get props => [
    localGroupId,
    strategy,
    targetRemoteGroupId,
    cameraResolutions,
  ];
}

class ProjectMergeResolution extends Equatable {
  final String localProjectId;
  final MergeStrategy strategy;
  final String? targetRemoteProjectId;
  final Map<String, GroupMergeResolution> groupResolutions;

  const ProjectMergeResolution({
    required this.localProjectId,
    this.strategy = MergeStrategy.merge,
    this.targetRemoteProjectId,
    this.groupResolutions = const {},
  });

  GroupMergeResolution resolutionForGroup(String localGroupId) {
    return groupResolutions[localGroupId] ??
        GroupMergeResolution(localGroupId: localGroupId);
  }

  @override
  List<Object?> get props => [
    localProjectId,
    strategy,
    targetRemoteProjectId,
    groupResolutions,
  ];
}

class GuestMigrationPlan extends Equatable {
  final Map<String, ProjectMergeResolution> projectResolutions;

  const GuestMigrationPlan({this.projectResolutions = const {}});

  ProjectMergeResolution resolutionForProject(String localProjectId) {
    return projectResolutions[localProjectId] ??
        ProjectMergeResolution(localProjectId: localProjectId);
  }

  @override
  List<Object?> get props => [projectResolutions];
}
