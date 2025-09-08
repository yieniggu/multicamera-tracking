import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/group_datasource.dart';
import '../../../domain/entities/group.dart';

class GroupRemoteDatasource implements GroupDataSource {
  final FirebaseFirestore firestore;

  GroupRemoteDatasource({required this.firestore});

  CollectionReference<Map<String, dynamic>> _groupCollection(String projectId) {
    return firestore.collection('projects').doc(projectId).collection('groups');
  }

  @override
  Future<List<Group>> getAllByProject(String projectId) async {
    final snapshot = await _groupCollection(projectId).get();
    final groups = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      debugPrint('[REMOTE-DS-GROUP-LOAD] ${data['id']} = ${data['name']}');
      return Group.fromJson(data);
    }).toList();
    return groups;
  }

  @override
  Future<void> save(Group group) async {
    debugPrint('[REMOTE-DS-GROUP-SAVE] group.toJson(): ${group.toJson()}');
    await _groupCollection(
      group.projectId,
    ).doc(group.id).set(group.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> delete(String projectId, String groupId) async {
    final docRef = _groupCollection(projectId).doc(groupId);
    final doc = await docRef.get();

    if (!doc.exists) return;

    final data = doc.data();
    if (data != null && (data['isDefault'] ?? false) == true) {
      throw Exception("Cannot delete default group.");
    }

    await docRef.delete();
  }
}
