import 'package:equatable/equatable.dart';
import '../../../domain/entities/camera.dart';

abstract class CameraState extends Equatable {
  const CameraState();

  @override
  List<Object?> get props => [];
}

class CameraInitial extends CameraState {
  const CameraInitial();
}

/// Full-screen loading only if nothing is loaded yet.
class CameraLoading extends CameraState {
  const CameraLoading();
}

class CameraLoaded extends CameraState {
  /// Structure: projectId -> groupId -> list of cameras
  final Map<String, Map<String, List<Camera>>> grouped;

  /// IDs of cameras currently being saved/deleted.
  final Set<String> savingCameraIds;

  /// Keys of groups currently loading: "$projectId|$groupId"
  final Set<String> loadingGroupKeys;

  const CameraLoaded({
    required this.grouped,
    this.savingCameraIds = const {},
    this.loadingGroupKeys = const {},
  });

  CameraLoaded copyWith({
    Map<String, Map<String, List<Camera>>>? grouped,
    Set<String>? savingCameraIds,
    Set<String>? loadingGroupKeys,
  }) {
    return CameraLoaded(
      grouped: grouped ?? this.grouped,
      savingCameraIds: savingCameraIds ?? this.savingCameraIds,
      loadingGroupKeys: loadingGroupKeys ?? this.loadingGroupKeys,
    );
  }

  static String groupKey(String projectId, String groupId) =>
      '$projectId|$groupId';

  List<Camera> getCameras(String projectId, String groupId) {
    return grouped[projectId]?[groupId] ?? const <Camera>[];
  }

  bool isSaving(String cameraId) => savingCameraIds.contains(cameraId);

  bool isLoadingGroup(String projectId, String groupId) {
    return loadingGroupKeys.contains(groupKey(projectId, groupId));
  }

  @override
  List<Object?> get props => [grouped, savingCameraIds, loadingGroupKeys];
}

class CameraError extends CameraState {
  final String message;

  const CameraError(this.message);

  @override
  List<Object?> get props => [message];
}
