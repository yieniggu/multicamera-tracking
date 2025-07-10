import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:multicamera_tracking/domain/entities/project.dart';
import 'package:multicamera_tracking/domain/repositories/project_repository.dart';

class FirestoreProjectRepository implements ProjectRepository {
  final FirebaseFirestore firestore;
  final String userId;

  FirestoreProjectRepository({required this.firestore, required this.userId});

  CollectionReference<Map<String, dynamic>> get _projects =>
      firestore.collection('projects');

  @override
  Future<List<Project>> getAll() async {
    debugPrint("[FIRE-PROJ-REP] Getting all projects...");
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
  Future<Project?> getDefaultProject() async {
    debugPrint("[FIRE-PROJ-REP] Getting default project...");
    final snapshot = await _projects
        .where('userRoles.$userId', isGreaterThanOrEqualTo: '')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final data = doc.data();
    data['id'] = doc.id;

    debugPrint("[FIRE-PROJ-REP] Found project $data");
    return Project.fromJson(data);
  }

  @override
  Future<void> save(Project project) async {
    debugPrint("[FIRE-PROJ-REP] Saving project ${project.id}");

    final id = project.id.isNotEmpty ? project.id : _projects.doc().id;
    final docRef = _projects.doc(id);
    final data = project.toJson();

    // Optional: merge instead of overwrite
    await docRef.set(data, SetOptions(merge: true));
  }
}
