// data/repositories_impl/camera_repository_impl.dart

import 'package:flutter/foundation.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/camera_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/camera_remote_datasource.dart';
import '../../domain/entities/camera.dart';
import '../../domain/repositories/camera_repository.dart';

class CameraRepositoryImpl implements CameraRepository {
  final CameraLocalDatasource local;
  final CameraRemoteDatasource remote;
  final ValueListenable<bool> useRemote;

  CameraRepositoryImpl({
    required this.local,
    required this.remote,
    required this.useRemote,
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
  Future<void> save(Camera camera) {
    return isRemote ? remote.save(camera) : local.save(camera);
  }

  @override
  Future<void> deleteById(String projectId, String groupId, String id) {
    return isRemote
        ? remote.deleteById(projectId, groupId, id)
        : local.deleteById(projectId, groupId, id);
  }

  @override
  Future<void> clearAllByGroup(String projectId, String groupId) {
    return isRemote
        ? remote.clearAllByGroup(projectId, groupId)
        : local.clearAllByGroup(projectId, groupId);
  }
}
