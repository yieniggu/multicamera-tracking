import 'package:flutter/foundation.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/group_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/group_remote_datasource.dart';
import 'package:multicamera_tracking/shared/domain/services/event_bus.dart';
import 'package:multicamera_tracking/shared/domain/events/surveillance_event.dart';

import '../../domain/entities/group.dart';
import '../../domain/repositories/group_repository.dart';

class GroupRepositoryImpl implements GroupRepository {
  final GroupLocalDatasource local;
  final GroupRemoteDatasource remote;
  final ValueListenable<bool> useRemote;
  final SurveillanceEventBus bus;

  GroupRepositoryImpl({
    required this.local,
    required this.remote,
    required this.useRemote,
    required this.bus,
  });

  bool get isRemote => useRemote.value;

  @override
  Future<List<Group>> getAllByProject(String projectId) {
    return isRemote
        ? remote.getAllByProject(projectId)
        : local.getAllByProject(projectId);
  }

  @override
  Future<void> save(Group group) async {
    if (!isRemote) {
      final existing = await local.getAllByProject(group.projectId);
      final isEditing = existing.any((g) => g.id == group.id);
      if (!isEditing && existing.isNotEmpty) {
        throw Exception(
          "Trial limit reached: only 1 group per project in guest mode.",
        );
      }
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
