import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/camera/delete_camera_by_group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/camera/get_cameras_by_group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/camera/save_camera.dart';
import 'package:multicamera_tracking/shared/domain/events/surveillance_event.dart';
import 'package:multicamera_tracking/shared/domain/services/event_bus.dart';

import 'camera_event.dart';
import 'camera_state.dart';

class CameraBloc extends Bloc<CameraEvent, CameraState> {
  final GetCamerasByGroupUseCase getCamerasByGroup;
  final SaveCameraUseCase saveCamera;
  final DeleteCameraByGroupUseCase deleteCamera;
  final SurveillanceEventBus bus;

  late final StreamSubscription _busSub;

  CameraBloc({
    required this.getCamerasByGroup,
    required this.saveCamera,
    required this.deleteCamera,
    required this.bus,
  }) : super(const CameraInitial()) {
    on<LoadCamerasByGroup>(_onLoadCameras);
    on<AddOrUpdateCamera>(_onSaveCamera);
    on<DeleteCamera>(_onDeleteCamera);
    on<ClearCamerasByGroup>(_onClearGroup);
    on<MarkCameraSaving>(_onMarkSaving);
    on<UnmarkCameraSaving>(_onUnmarkSaving);

    _busSub = bus.stream.listen((e) {
      debugPrint('[BUS→CameraBloc] bus=${bus.id} event=${e.runtimeType}');
      _onBusEvent(e);
    });
  }

  @override
  Future<void> close() async {
    await _busSub.cancel();
    return super.close();
  }

  Future<void> _onLoadCameras(
    LoadCamerasByGroup event,
    Emitter<CameraState> emit,
  ) async {
    final key = CameraLoaded.groupKey(event.projectId, event.groupId);

    // Keep existing data visible; only mark this group as loading.
    final current = state;
    if (current is CameraLoaded) {
      emit(
        current.copyWith(loadingGroupKeys: {...current.loadingGroupKeys, key}),
      );
    } else {
      // If nothing loaded yet, we can show full-screen loading.
      emit(const CameraLoading());
    }

    try {
      final newCameras = await getCamerasByGroup(
        event.projectId,
        event.groupId,
      );

      // Preserve existing loaded data if any.
      final base = state is CameraLoaded
          ? cloneGroupedCameraMap((state as CameraLoaded).grouped)
          : <String, Map<String, List<Camera>>>{};

      base[event.projectId] ??= {};
      base[event.projectId]![event.groupId] = List<Camera>.from(newCameras);

      final savingIds = state is CameraLoaded
          ? (state as CameraLoaded).savingCameraIds
          : <String>{};

      final loadingKeys = state is CameraLoaded
          ? (Set<String>.from((state as CameraLoaded).loadingGroupKeys)
              ..remove(key))
          : <String>{};

      emit(
        CameraLoaded(
          grouped: base,
          savingCameraIds: savingIds,
          loadingGroupKeys: loadingKeys,
        ),
      );
    } catch (e, stack) {
      debugPrint('[CameraBloc] load error: $e\n$stack');
      emit(CameraError(e.toString()));
    }
  }

  Future<void> _onSaveCamera(
    AddOrUpdateCamera event,
    Emitter<CameraState> emit,
  ) async {
    final cam = event.camera;
    add(MarkCameraSaving(cam.id));
    try {
      await saveCamera(cam);
      // Event bus will publish CameraUpserted; state updates there.
    } catch (e, stack) {
      debugPrint('[CameraBloc] save error: $e\n$stack');
      // Keep UI stable; don’t nuke CameraLoaded.
    } finally {
      add(UnmarkCameraSaving(cam.id));
    }
  }

  Future<void> _onDeleteCamera(
    DeleteCamera event,
    Emitter<CameraState> emit,
  ) async {
    final cam = event.camera;
    add(MarkCameraSaving(cam.id));
    try {
      await deleteCamera(cam.projectId, cam.groupId, cam.id);
      // Event bus will publish CameraDeleted; state updates there.
    } catch (e, stack) {
      debugPrint('[CameraBloc] delete error: $e\n$stack');
    } finally {
      add(UnmarkCameraSaving(cam.id));
    }
  }

  Future<void> _onClearGroup(
    ClearCamerasByGroup event,
    Emitter<CameraState> emit,
  ) async {
    final current = state;
    if (current is! CameraLoaded) return;

    final grouped = cloneGroupedCameraMap(current.grouped);
    grouped[event.projectId] ??= {};
    grouped[event.projectId]![event.groupId] = <Camera>[];

    emit(current.copyWith(grouped: grouped));
  }

  void _onMarkSaving(MarkCameraSaving event, Emitter<CameraState> emit) {
    final current = state;
    if (current is! CameraLoaded) return;

    emit(
      current.copyWith(
        savingCameraIds: {...current.savingCameraIds, event.cameraId},
      ),
    );
  }

  void _onUnmarkSaving(UnmarkCameraSaving event, Emitter<CameraState> emit) {
    final current = state;
    if (current is! CameraLoaded) return;

    final updated = Set<String>.from(current.savingCameraIds)
      ..remove(event.cameraId);

    emit(current.copyWith(savingCameraIds: updated));
  }

  void _onBusEvent(SurveillanceEvent e) {
    final current = state;

    final grouped = current is CameraLoaded
        ? cloneGroupedCameraMap(current.grouped)
        : <String, Map<String, List<Camera>>>{};

    final saving = current is CameraLoaded
        ? current.savingCameraIds
        : <String>{};
    final loading = current is CameraLoaded
        ? current.loadingGroupKeys
        : <String>{};

    if (e is CameraUpserted) {
      final p = e.camera.projectId;
      final g = e.camera.groupId;

      final list = List<Camera>.from(grouped[p]?[g] ?? const []);
      final idx = list.indexWhere((c) => c.id == e.camera.id);
      if (idx >= 0) {
        list[idx] = e.camera;
      } else {
        list.add(e.camera);
      }

      grouped[p] ??= {};
      grouped[p]![g] = list;

      emit(
        CameraLoaded(
          grouped: grouped,
          savingCameraIds: saving,
          loadingGroupKeys: loading,
        ),
      );
    } else if (e is CameraDeleted) {
      final p = e.projectId;
      final g = e.groupId;

      final list = List<Camera>.from(grouped[p]?[g] ?? const []);
      grouped[p] ??= {};
      grouped[p]![g] = list.where((c) => c.id != e.cameraId).toList();

      emit(
        CameraLoaded(
          grouped: grouped,
          savingCameraIds: saving,
          loadingGroupKeys: loading,
        ),
      );
    } else if (e is CamerasClearedForGroup) {
      grouped[e.projectId] ??= {};
      grouped[e.projectId]![e.groupId] = <Camera>[];

      emit(
        CameraLoaded(
          grouped: grouped,
          savingCameraIds: saving,
          loadingGroupKeys: loading,
        ),
      );
    }
  }
}

/// Deep clone (project -> group -> list) to avoid accidental shared list mutations.
Map<String, Map<String, List<Camera>>> cloneGroupedCameraMap(
  Map<String, Map<String, List<Camera>>> original,
) {
  return original.map(
    (pid, groupMap) => MapEntry(
      pid,
      groupMap.map((gid, list) => MapEntry(gid, List<Camera>.from(list))),
    ),
  );
}
