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
  Future<Group?> getDefaultGroup() async {
    debugPrint("[HIVE-GROUP-REP] Getting default group");
    try {
      final model = box.values.firstWhere((e) => e.isDefault);
      return model.toEntity();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(Group group) async {
    debugPrint("[HIVE-GROUP-REP] Saving group ${group.id}");
    await box.put(group.id, group.toModel());
  }
}
