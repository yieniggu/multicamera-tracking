import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/camera_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/models/camera_model_mapper.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';
import '../../models/camera_model.dart';

class CameraLocalDatasource implements CameraDataSource {
  final Box<CameraModel> box;

  CameraLocalDatasource({required this.box});

  @override
  Future<List<Camera>> getAll(String userId) async {
    debugPrint("[CAMERA-LOCAL-DS] Getting all cameras (single local store)");
    return box.values.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Camera>> getAllByGroup(String projectId, String groupId) async {
    debugPrint(
      "[CAMERA-LOCAL-DS] Getting all cameras from project: $projectId - group: $groupId",
    );
    return box.values
        .where((m) => m.projectId == projectId && m.groupId == groupId)
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  Future<void> save(Camera camera) async {
    debugPrint("[CAMERA-LOCAL-DS] Saving new camera: ${camera.toString()}");

    final existing = box.get(camera.id);
    final incoming = camera.toModel();

    if (existing == null || existing != incoming) {
      await box.put(camera.id, incoming);
    }
  }

  @override
  Future<void> deleteById(String projectId, String groupId, String id) async {
    debugPrint("[CAMERA-LOCAL-DS] Deleting camera: $id");

    final model = box.get(id);
    if (model != null &&
        model.projectId == projectId &&
        model.groupId == groupId) {
      await box.delete(id);
    }
  }

  @override
  Future<void> clearAllByGroup(String projectId, String groupId) async {
    final keysToDelete = box.values
        .where((m) => m.projectId == projectId && m.groupId == groupId)
        .map((m) => m.id)
        .toList();
    await box.deleteAll(keysToDelete);
  }
}
