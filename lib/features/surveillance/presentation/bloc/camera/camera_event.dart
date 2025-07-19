import 'package:equatable/equatable.dart';
import '../../../domain/entities/camera.dart';

/// Base class for all camera-related BLoC events.
abstract class CameraEvent extends Equatable {
  const CameraEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load all cameras for a specific [projectId] and [groupId].
final class LoadCamerasByGroup extends CameraEvent {
  final String projectId;
  final String groupId;

  const LoadCamerasByGroup(this.projectId, this.groupId);

  @override
  List<Object?> get props => [projectId, groupId];
}

/// Event to create a new camera or update an existing one.
final class AddOrUpdateCamera extends CameraEvent {
  final Camera camera;

  const AddOrUpdateCamera(this.camera);

  @override
  List<Object?> get props => [camera];
}

/// Event to delete a specific camera.
final class DeleteCamera extends CameraEvent {
  final Camera camera;

  const DeleteCamera(this.camera);

  @override
  List<Object?> get props => [camera];
}

/// Event to mark a camera as saving (e.g. while persisting).
final class MarkCameraSaving extends CameraEvent {
  final String cameraId;

  const MarkCameraSaving(this.cameraId);

  @override
  List<Object?> get props => [cameraId];
}

/// Event to unmark a camera as saving (after completion).
final class UnmarkCameraSaving extends CameraEvent {
  final String cameraId;

  const UnmarkCameraSaving(this.cameraId);

  @override
  List<Object?> get props => [cameraId];
}
