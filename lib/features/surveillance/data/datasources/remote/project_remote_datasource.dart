import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import '../project_datasource.dart';

class ProjectRemoteDataSource implements ProjectDataSource {
  final FirebaseFirestore firestore;

  ProjectRemoteDataSource({required this.firestore});


  CollectionReference<Map<String, dynamic>> get _projects =>
      firestore.collection('projects');

  @override
  Future<List<Project>> getAll(String userId) async {
    debugPrint("[FIRE-PROJ-DS] Getting all projects for user $userId");

    final snapshot = await _projects
        .where('userRoles.$userId', isGreaterThanOrEqualTo: '')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return Project.fromJson(data);
    }).toList();
  }

  @override
  Future<void> save(Project project) async {
    debugPrint("[FIRE-PROJ-DS] Saving project ${project.id}");

    final id = project.id.isNotEmpty ? project.id : _projects.doc().id;
    await _projects.doc(id).set(project.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> delete(String id) async {
    debugPrint("[FIRE-PROJ-DS] Deleting project $id");

    final docRef = _projects.doc(id);
    final doc = await docRef.get();

    if (!doc.exists) return;

    final data = doc.data();
    if (data != null && (data['isDefault'] ?? false) == true) {
      throw Exception("Cannot delete default project.");
    }

    await docRef.delete();
  }
}
