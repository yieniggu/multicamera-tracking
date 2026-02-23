import 'package:flutter/material.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/group_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/group_remote_datasource.dart';
import 'package:multicamera_tracking/shared/domain/services/event_bus.dart';
import 'package:multicamera_tracking/shared/domain/services/app_mode.dart';
import 'package:multicamera_tracking/shared/domain/events/surveillance_event.dart';
import 'package:multicamera_tracking/shared/utils/normalized_text.dart';

import '../../domain/entities/group.dart';
import '../../domain/repositories/group_repository.dart';

class GroupRepositoryImpl implements GroupRepository {
  final GroupLocalDatasource local;
  final GroupRemoteDatasource remote;
  final AppMode appMode;
  final SurveillanceEventBus bus;

  GroupRepositoryImpl({
    required this.local,
    required this.remote,
    required this.appMode,
    required this.bus,
  });

  bool get isRemote => appMode.isRemote;

  @override
  Future<List<Group>> getAllByProject(String projectId) {
    return isRemote
        ? remote.getAllByProject(projectId)
        : local.getAllByProject(projectId);
  }

  @override
  Future<void> save(Group group) async {
    final normalizedIncomingName = normalizeComparableText(group.name);
    final groups = await getAllByProject(group.projectId);
    final hasDuplicateName = groups.any(
      (existingGroup) =>
          existingGroup.id != group.id &&
          normalizeComparableText(existingGroup.name) == normalizedIncomingName,
    );
    if (hasDuplicateName) {
      throw Exception("Group name already exists for this project.");
    }

    if (!isRemote) {
      await local.save(group);
    } else {
      await remote.save(group);
    }
    debugPrint('[REPO→BUS ${bus.id}] GroupUpserted(${group.id})');
    bus.emit(GroupUpserted(group));
  }

  @override
  Future<void> delete(String projectId, String groupId) async {
    if (isRemote) {
      await remote.delete(projectId, groupId);
    } else {
      await local.delete(projectId, groupId);
    }
    bus.emit(GroupDeleted(projectId, groupId));
  }
}
