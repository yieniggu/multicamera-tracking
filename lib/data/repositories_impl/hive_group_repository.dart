import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:multicamera_tracking/domain/entities/group.dart';
import 'package:multicamera_tracking/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/data/models/group_model.dart';
import 'package:multicamera_tracking/data/models/group_model_mapper.dart';

class HiveGroupRepository implements GroupRepository {
  final Box<GroupModel> box;

  HiveGroupRepository({required this.box});

  @override
  Future<List<Group>> getAll() async {
    debugPrint("[HIVE-GROUP-REP] Getting all groups...");
    return box.values.map((e) => e.toEntity()).toList();
  }

  @override
  Future<List<Group>> getAllByProject(String projectId) async {
    debugPrint("[HIVE-GROUP-REP] Getting groups for project $projectId...");
    return box.values
        .where((e) => e.projectId == projectId)
        .map((e) => e.toEntity())
        .toList();
  }

  @override
  Future<void> delete(String projectId, String groupId) async {
    debugPrint(
      "[HIVE-GROUP-REP] Deleting group $groupId from project $projectId",
    );

    final model = box.get(groupId);
    if (model?.isDefault == true) {
      throw Exception("Cannot delete default group.");
    }

    await box.delete(groupId);
  }

  @override
  Future<void> save(Group group) async {
    debugPrint("[HIVE-GROUP-REP] Saving group ${group.id}");
    await box.put(group.id, group.toModel());
  }
}
