import 'dart:async';

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
  }) : super(CameraInitial()) {
    on<LoadCamerasByGroup>(_onLoadCameras);
    on<AddOrUpdateCamera>(_onSaveCamera);
    on<DeleteCamera>(_onDeleteCamera);
    on<MarkCameraSaving>(_onMarkSaving);
    on<UnmarkCameraSaving>(_onUnmarkSaving);

    _busSub = bus.stream.listen(_onBusEvent);
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
    } catch (e, stack) {
      // keep errors visible but don’t crash the stream
      // ignore: avoid_print
      print('[CameraBloc] load error: $e\n$stack');
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
      // no reload; repo emits CameraUpserted
    } catch (e, stack) {
      // Do NOT emit CameraError here; keep current list visible.
      // The sheet/UI will show a snackbar from its own catch.
      // ignore: avoid_print
      print('[CameraBloc] save error: $e\n$stack');
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
      // no reload; repo emits CameraDeleted
    } catch (e, stack) {
      // Do NOT emit CameraError; keep list visible.
      // ignore: avoid_print
      print('[CameraBloc] delete error: $e\n$stack');
    } finally {
      add(UnmarkCameraSaving(cam.id));
    }
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

      emit(CameraLoaded(grouped: grouped, savingCameraIds: saving));
    } else if (e is CameraDeleted) {
      final p = e.projectId, g = e.groupId;
      final list = List<Camera>.from(grouped[p]?[g] ?? const []);
      grouped[p] ??= {};
      grouped[p]![g] = list.where((c) => c.id != e.cameraId).toList();

      emit(CameraLoaded(grouped: grouped, savingCameraIds: saving));
    } else if (e is CamerasClearedForGroup) {
      final p = e.projectId, g = e.groupId;
      grouped[p] ??= {};
      grouped[p]![g] = <Camera>[];

      emit(CameraLoaded(grouped: grouped, savingCameraIds: saving));
    }
  }
}

/// safe clone (preserves types)
Map<String, Map<String, List<Camera>>> cloneGroupedCameraMap(
  Map<String, Map<String, List<Camera>>> original,
) {
  return original.map(
    (pid, groupMap) => MapEntry(pid, Map<String, List<Camera>>.from(groupMap)),
  );
}
