import 'package:equatable/equatable.dart';
import '../../../domain/entities/camera.dart';

abstract class CameraEvent extends Equatable {
  const CameraEvent();

  @override
  List<Object?> get props => [];
}

final class LoadCamerasByGroup extends CameraEvent {
  final String projectId;
  final String groupId;

  const LoadCamerasByGroup({required this.projectId, required this.groupId});

  @override
  List<Object?> get props => [projectId, groupId];
}

final class AddOrUpdateCamera extends CameraEvent {
  final Camera camera;

  const AddOrUpdateCamera(this.camera);

  @override
  List<Object?> get props => [camera];
}

final class DeleteCamera extends CameraEvent {
  final Camera camera;

  const DeleteCamera(this.camera);

  @override
  List<Object?> get props => [camera];
}

final class ClearCamerasByGroup extends CameraEvent {
  final String projectId;
  final String groupId;

  const ClearCamerasByGroup({required this.projectId, required this.groupId});

  @override
  List<Object?> get props => [projectId, groupId];
}

final class MarkCameraSaving extends CameraEvent {
  final String cameraId;

  const MarkCameraSaving(this.cameraId);

  @override
  List<Object?> get props => [cameraId];
}

final class UnmarkCameraSaving extends CameraEvent {
  final String cameraId;

  const UnmarkCameraSaving(this.cameraId);

  @override
  List<Object?> get props => [cameraId];
}
