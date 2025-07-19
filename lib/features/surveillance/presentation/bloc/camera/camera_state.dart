import 'package:equatable/equatable.dart';
import '../../../domain/entities/camera.dart';

/// Abstract base class for all camera states in the BLoC.
abstract class CameraState extends Equatable {
  const CameraState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any cameras are loaded.
class CameraInitial extends CameraState {
  const CameraInitial();
}

/// State representing an ongoing camera loading process.
class CameraLoading extends CameraState {
  const CameraLoading();
}

/// Loaded state containing all cameras and saving indicators.
class CameraLoaded extends CameraState {
  /// Nested structure: projectId → groupId → list of cameras.
  final Map<String, Map<String, List<Camera>>> grouped;

  /// IDs of cameras currently being added or updated.
  final Set<String> savingCameraIds;

  const CameraLoaded({required this.grouped, this.savingCameraIds = const {}});

  /// Creates a new state with optional overrides.
  CameraLoaded copyWith({
    Map<String, Map<String, List<Camera>>>? grouped,
    Set<String>? savingCameraIds,
  }) {
    return CameraLoaded(
      grouped: grouped ?? this.grouped,
      savingCameraIds: savingCameraIds ?? this.savingCameraIds,
    );
  }

  /// Returns the list of cameras for a given project and group.
  List<Camera> getCameras(String projectId, String groupId) {
    return grouped[projectId]?[groupId] ?? [];
  }

  /// Returns whether a specific camera is in the saving state.
  bool isSaving(String cameraId) {
    return savingCameraIds.contains(cameraId);
  }

  @override
  List<Object?> get props => [grouped, savingCameraIds];
}

/// State representing an error while loading or modifying cameras.
class CameraError extends CameraState {
  final String message;

  const CameraError(this.message);

  @override
  List<Object?> get props => [message];
}
