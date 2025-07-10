import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:multicamera_tracking/domain/entities/group.dart';
import 'package:multicamera_tracking/domain/repositories/group_repository.dart';

class FirestoreGroupRepository implements GroupRepository {
  final FirebaseFirestore firestore;

  FirestoreGroupRepository({required this.firestore});

  CollectionReference<Map<String, dynamic>> _groupCollection(String projectId) {
    return firestore.collection('projects').doc(projectId).collection('groups');
  }

  @override
  Future<List<Group>> getAll() async {
    debugPrint("[FIRE-GROUP-REP] Getting all groups..");

    throw UnimplementedError("Use getAllByProject(projectId) instead");
  }

  // Optional helper if you want to load all groups for a given project
  @override
  Future<List<Group>> getAllByProject(String projectId) async {
    debugPrint("[FIRE-GROUP-REP] Getting all projects from project $projectId");

    final snapshot = await _groupCollection(projectId).get();
    return snapshot.docs.map((doc) => Group.fromJson(doc.data())).toList();
  }

  @override
  Future<void> delete(String projectId, String groupId) async {
    debugPrint(
      "[FIRE-GROUP-REP] Deleting group $groupId from project $projectId",
    );

    final docRef = _groupCollection(projectId).doc(groupId);
    final doc = await docRef.get();

    if (!doc.exists) return;

    final data = doc.data();
    if (data != null && (data['isDefault'] ?? false) == true) {
      throw Exception("Cannot delete default group.");
    }

    await docRef.delete();
  }

  @override
  Future<void> save(Group group) async {
    debugPrint("[FIRE-GROUP-REP] Saving group ${group.id}");

    await _groupCollection(
      group.projectId,
    ).doc(group.id).set(group.toJson(), SetOptions(merge: true));
  }
}
