import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:multicamera_tracking/domain/entities/camera.dart';
import 'package:multicamera_tracking/domain/repositories/camera_repository.dart';

class FirestoreCameraRepository implements CameraRepository {
  final FirebaseFirestore firestore;

  // Instead of relying on user ID, this repo is group-scoped
  FirestoreCameraRepository({required this.firestore});

  CollectionReference<Map<String, dynamic>> _cameraCollection(
    String projectId,
    String groupId,
  ) {
    return firestore
        .collection('projects')
        .doc(projectId)
        .collection('groups')
        .doc(groupId)
        .collection('cameras');
  }

  // You may replace this with a globally scoped variant if needed
  @override
  Future<List<Camera>> getAll() {
    debugPrint("[FIRE-CAM-REP] Getting all cameras...");

    throw UnimplementedError("Use getAllByGroup(projectId, groupId) instead.");
  }

  @override
  Future<List<Camera>> getAllByGroup(String projectId, String groupId) async {
    debugPrint(
      "[FIRE-CAM-REP] Getting cameras from project $projectId and group $groupId",
    );
    final snapshot = await _cameraCollection(projectId, groupId).get();
    return snapshot.docs.map((doc) => Camera.fromJson(doc.data())).toList();
  }

  @override
  Future<void> save(Camera camera) async {
    debugPrint("[FIRE-CAM-REP] Saving camera with id ${camera.id}");

    final col = _cameraCollection(camera.projectId, camera.groupId);
    await col.doc(camera.id).set(camera.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> delete(String id) async {
    throw UnimplementedError("Use deleteById(projectId, groupId, id)");
  }

  Future<void> deleteById(String projectId, String groupId, String id) async {
    final col = _cameraCollection(projectId, groupId);
    await col.doc(id).delete();
  }

  @override
  Future<void> clearAll() {
    throw UnimplementedError("Use clearAllByGroup(projectId, groupId)");
  }

  Future<void> clearAllByGroup(String projectId, String groupId) async {
    final snapshot = await _cameraCollection(projectId, groupId).get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
