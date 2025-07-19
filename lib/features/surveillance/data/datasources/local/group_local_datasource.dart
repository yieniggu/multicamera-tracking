import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/group_datasource.dart';
import '../../../domain/entities/group.dart';
import '../../models/group_model.dart';
import '../../models/group_model_mapper.dart';

class GroupLocalDatasource implements GroupDataSource {
  final Box<GroupModel> box;

  GroupLocalDatasource({required this.box});

  @override
  Future<List<Group>> getAllByProject(String projectId) async {
    debugPrint("[GROUP-LOCAL-DS] Getting groups from project: $projectId");

    return box.values
        .where((m) => m.projectId == projectId)
        .map((m) => m.toEntity())
        .toList();
  }

  @override
  Future<void> save(Group group) async {
    debugPrint("[GROUP-LOCAL-DS] Saving new group: ${group.toString()}");

    final existing = box.get(group.id);
    final incoming = group.toModel();

    if (existing == null || existing != incoming) {
      await box.put(group.id, incoming);
    }
  }

  @override
  Future<void> delete(String projectId, String groupId) async {
    debugPrint("[GROUP-LOCAL-DS] Deleting group: $groupId");

    final model = box.get(groupId);
    if (model != null && model.projectId == projectId) {
      if (model.isDefault) throw Exception("Cannot delete default group.");
      await box.delete(groupId);
    }
  }
}
