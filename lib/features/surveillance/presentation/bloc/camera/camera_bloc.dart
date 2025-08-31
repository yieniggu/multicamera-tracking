import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/camera/delete_camera_by_group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/camera/get_cameras_by_group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/camera/save_camera.dart';

import 'camera_event.dart';
import 'camera_state.dart';

class CameraBloc extends Bloc<CameraEvent, CameraState> {
  final GetCamerasByGroupUseCase getCamerasByGroup;
  final SaveCameraUseCase saveCamera;
  final DeleteCameraByGroupUseCase deleteCamera;

  CameraBloc({
    required this.getCamerasByGroup,
    required this.saveCamera,
    required this.deleteCamera,
  }) : super(CameraInitial()) {
    on<LoadCamerasByGroup>(_onLoadCameras);
    on<AddOrUpdateCamera>(_onSaveCamera);
    on<DeleteCamera>(_onDeleteCamera);
    on<MarkCameraSaving>(_onMarkSaving);
    on<UnmarkCameraSaving>(_onUnmarkSaving);
  }

  /// Loads cameras for a specific project and group
  Future<void> _onLoadCameras(
    LoadCamerasByGroup event,
    Emitter<CameraState> emit,
  ) async {
    debugPrint(
      '[CameraBloc] Loading cameras for '
      'project: ${event.projectId}, group: ${event.groupId}',
    );

    try {
      final newCameras = await getCamerasByGroup(
        event.projectId,
        event.groupId,
      );

      final currentGrouped = state is CameraLoaded
          ? cloneGroupedCameraMap((state as CameraLoaded).grouped)
          : <String, Map<String, List<Camera>>>{};

      currentGrouped[event.projectId] ??= {};
      currentGrouped[event.projectId]![event.groupId] = newCameras;

      final savingIds = state is CameraLoaded
          ? (state as CameraLoaded).savingCameraIds
          : <String>{};

      emit(CameraLoaded(grouped: currentGrouped, savingCameraIds: savingIds));

      debugPrint('[CameraBloc] Loaded ${newCameras.length} cameras.');
    } catch (e, stack) {
      debugPrint('[CameraBloc] Failed to load cameras: $e\n$stack');
      emit(CameraError(e.toString()));
    }
  }

  /// ons saving (create/update) a camera
  Future<void> _onSaveCamera(
    AddOrUpdateCamera event,
    Emitter<CameraState> emit,
  ) async {
    final cam = event.camera;
    debugPrint('[CameraBloc] Saving camera: ${cam.id}');

    add(MarkCameraSaving(cam.id));

    try {
      await saveCamera(cam);

      debugPrint('[CameraBloc] Camera saved. Reloading group...');
      add(LoadCamerasByGroup(cam.projectId, cam.groupId));
    } catch (e, stack) {
      debugPrint('[CameraBloc] Failed to save camera: $e\n$stack');
      emit(CameraError(e.toString()));
    } finally {
      add(UnmarkCameraSaving(cam.id));
    }
  }

  /// ons deleting a camera
  Future<void> _onDeleteCamera(
    DeleteCamera event,
    Emitter<CameraState> emit,
  ) async {
    final cam = event.camera;
    debugPrint('[CameraBloc] Deleting camera: ${cam.id}');

    add(MarkCameraSaving(cam.id));

    try {
      await deleteCamera(cam.projectId, cam.groupId, cam.id);

      debugPrint('[CameraBloc] Camera deleted. Reloading group...');
      add(LoadCamerasByGroup(cam.projectId, cam.groupId));
    } catch (e, stack) {
      debugPrint('[CameraBloc] Failed to delete camera: $e\n$stack');
      emit(CameraError(e.toString()));
    } finally {
      add(UnmarkCameraSaving(cam.id));
    }
  }

  /// Adds the camera to the saving set (used to show UI loading indicators)
  void _onMarkSaving(MarkCameraSaving event, Emitter<CameraState> emit) {
    final current = state;
    if (current is! CameraLoaded) return;

    final updatedSet = {...current.savingCameraIds, event.cameraId};

    emit(current.copyWith(savingCameraIds: updatedSet));
    debugPrint('[CameraBloc] Marked camera ${event.cameraId} as saving.');
  }

  /// Removes the camera from the saving set
  void _onUnmarkSaving(UnmarkCameraSaving event, Emitter<CameraState> emit) {
    final current = state;
    if (current is! CameraLoaded) return;

    final updatedSet = Set<String>.from(current.savingCameraIds)
      ..remove(event.cameraId);

    emit(current.copyWith(savingCameraIds: updatedSet));
    debugPrint('[CameraBloc] Unmarked camera ${event.cameraId} as saving.');
  }
}

/// Clones the nested grouped camera map with preserved type safety.
/// Clones the nested grouped camera map with preserved type safety.
/// Prevents `Map<dynamic, dynamic>` type issues when copying from state.
Map<String, Map<String, List<Camera>>> cloneGroupedCameraMap(
  Map<String, Map<String, List<Camera>>> original,
) {
  return original.map(
    (projectId, groupMap) =>
        MapEntry(projectId, Map<String, List<Camera>>.from(groupMap)),
  );
}
