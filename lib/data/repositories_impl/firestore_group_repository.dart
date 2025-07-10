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
  Future<List<Group>> getAllByProject(String projectId) async {
    debugPrint("[FIRE-GROUP-REP] Getting all projects from project $projectId");

    final snapshot = await _groupCollection(projectId).get();
    return snapshot.docs.map((doc) => Group.fromJson(doc.data())).toList();
  }

  @override
  Future<Group?> getDefaultGroup(String projectId) async {
    debugPrint(
      "[FIRE-GROUP-REP] Getting default group from project $projectId",
    );

    final doc = await _groupCollection(projectId).doc('default').get();
    if (!doc.exists) return null;

    debugPrint("[FIRE-GROUP-REP] Found group ${doc.data}");

    return Group.fromJson(doc.data()!);
  }

  @override
  Future<void> save(Group group) async {
    debugPrint("[FIRE-GROUP-REP] Saving group ${group.id}");

    await _groupCollection(
      group.projectId,
    ).doc(group.id).set(group.toJson(), SetOptions(merge: true));
  }
}
