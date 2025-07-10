import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../domain/entities/camera.dart';
import '../../domain/repositories/camera_repository.dart';
import '../models/camera_model.dart';
import '../models/camera_model_mapper.dart';

class HiveCameraRepository implements CameraRepository {
  final Box<CameraModel> box;

  HiveCameraRepository({required this.box});

  @override
  Future<List<Camera>> getAll() async {
    debugPrint("[HIVE-CAM-REP] Getting all cameras...");
    return box.values.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Camera>> getAllByGroup(String projectId, String groupId) async {
    debugPrint(
      "[HIVE-CAM-REP] Getting cameras from project $projectId and group $groupId",
    );

    return box.values
        .where((m) => m.projectId == projectId && m.groupId == groupId)
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  Future<void> save(Camera camera) async {
    debugPrint("[HIVE-CAM-REP] Saving camera with id ${camera.id}");
    await box.put(camera.id, camera.toModel());
  }

  @override
  Future<void> delete(String id) async {
    debugPrint("[HIVE-CAM-REP] Deleting camera with id $id");
    await box.delete(id);
  }

  @override
  Future<void> clearAll() async {
    debugPrint("[HIVE-CAM-REP] Clearing all cameras");
    await box.clear();
  }

  @override
  Future<void> deleteById(String projectId, String groupId, String id) async {
    final model = box.get(id);
    if (model != null &&
        model.projectId == projectId &&
        model.groupId == groupId) {
      debugPrint(
        "[HIVE-CAM-REP] Deleting camera $id in project $projectId group $groupId",
      );
      await box.delete(id);
    }
  }

  @override
  Future<void> clearAllByGroup(String projectId, String groupId) async {
    final keysToDelete = box.values
        .where((m) => m.projectId == projectId && m.groupId == groupId)
        .map((m) => m.id)
        .toList();

    debugPrint(
      "[HIVE-CAM-REP] Clearing all cameras in project $projectId group $groupId",
    );

    await box.deleteAll(keysToDelete);
  }
}
