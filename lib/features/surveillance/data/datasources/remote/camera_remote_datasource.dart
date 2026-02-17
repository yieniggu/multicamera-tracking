import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/camera_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';

class CameraRemoteDatasource implements CameraDataSource {
  final FirebaseFirestore firestore;

  CameraRemoteDatasource({required this.firestore});

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

  @override
  Future<List<Camera>> getAll(String userId) async {
    try {
      final snapshot = await firestore
          .collectionGroup('cameras')
          .where('userRoles.$userId', isGreaterThanOrEqualTo: '')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['groupId'] ??= doc.reference.parent.parent?.id;
        data['projectId'] ??=
            doc.reference.parent.parent?.parent?.parent?.id;
        return Camera.fromJson(data);
      }).toList();
    } catch (e) {
      // Fallback to hierarchical traversal if collectionGroup query fails.
      return _getAllByTraversal(userId);
    }
  }

  Future<List<Camera>> _getAllByTraversal(String userId) async {
    final projects = await firestore
        .collection('projects')
        .where('userRoles.$userId', isGreaterThanOrEqualTo: '')
        .get();

    final List<Camera> allCameras = [];

    for (final project in projects.docs) {
      final projectId = project.id;
      final groupsSnapshot = await firestore
          .collection('projects')
          .doc(projectId)
          .collection('groups')
          .get();

      for (final group in groupsSnapshot.docs) {
        final groupId = group.id;
        final camerasSnapshot = await _cameraCollection(
          projectId,
          groupId,
        ).get();
        allCameras.addAll(
          camerasSnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            data['projectId'] = projectId;
            data['groupId'] = groupId;
            return Camera.fromJson(data);
          }),
        );
      }
    }
    return allCameras;
  }

  @override
  Future<List<Camera>> getAllByGroup(String projectId, String groupId) async {
    final snapshot = await _cameraCollection(projectId, groupId).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      data['projectId'] = projectId;
      data['groupId'] = groupId;
      return Camera.fromJson(data);
    }).toList();
  }

  @override
  Future<void> save(Camera camera) async {
    final col = _cameraCollection(camera.projectId, camera.groupId);
    await col.doc(camera.id).set(camera.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteById(String projectId, String groupId, String id) async {
    await _cameraCollection(projectId, groupId).doc(id).delete();
  }

  @override
  Future<void> clearAllByGroup(String projectId, String groupId) async {
    final col = _cameraCollection(projectId, groupId);
    final snapshot = await col.get();
    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
