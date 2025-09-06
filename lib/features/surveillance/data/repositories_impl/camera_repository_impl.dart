import 'package:flutter/foundation.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/camera_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/camera_remote_datasource.dart';
import 'package:multicamera_tracking/shared/domain/services/event_bus.dart';
import 'package:multicamera_tracking/shared/domain/events/surveillance_event.dart';
import '../../domain/entities/camera.dart';
import '../../domain/repositories/camera_repository.dart';

class CameraRepositoryImpl implements CameraRepository {
  final CameraLocalDatasource local;
  final CameraRemoteDatasource remote;
  final ValueListenable<bool> useRemote;
  final SurveillanceEventBus bus;

  CameraRepositoryImpl({
    required this.local,
    required this.remote,
    required this.useRemote,
    required this.bus,
  });

  bool get isRemote => useRemote.value;

  @override
  Future<List<Camera>> getAll(String userId) {
    return isRemote ? remote.getAll(userId) : local.getAll(userId);
  }

  @override
  Future<List<Camera>> getAllByGroup(String projectId, String groupId) {
    return isRemote
        ? remote.getAllByGroup(projectId, groupId)
        : local.getAllByGroup(projectId, groupId);
  }

  @override
  Future<void> save(Camera camera) async {
    if (!isRemote) {
      // trial: max 4 cameras per group (local only)
      final current = await local.getAllByGroup(
        camera.projectId,
        camera.groupId,
      );
      final isEditing = current.any((c) => c.id == camera.id);
      if (!isEditing && current.length >= 4) {
        throw Exception(
          "Trial limit reached: max 4 cameras per group in guest mode.",
        );
      }
      await local.save(camera);
    } else {
      await remote.save(camera);
    }
    // notify after successful write
    bus.emit(CameraUpserted(camera));
  }

  @override
  Future<void> deleteById(String projectId, String groupId, String id) async {
    if (isRemote) {
      await remote.deleteById(projectId, groupId, id);
    } else {
      await local.deleteById(projectId, groupId, id);
    }
    bus.emit(CameraDeleted(projectId, groupId, id));
  }

  @override
  Future<void> clearAllByGroup(String projectId, String groupId) async {
    if (isRemote) {
      await remote.clearAllByGroup(projectId, groupId);
    } else {
      await local.clearAllByGroup(projectId, groupId);
    }
    bus.emit(CamerasClearedForGroup(projectId, groupId));
  }
}
