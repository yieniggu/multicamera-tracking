import 'package:flutter/foundation.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/group_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/group_remote_datasource.dart';

import '../../domain/entities/group.dart';
import '../../domain/repositories/group_repository.dart';

class GroupRepositoryImpl implements GroupRepository {
  final GroupLocalDatasource local;
  final GroupRemoteDatasource remote;
  final ValueListenable<bool> useRemote;

  GroupRepositoryImpl({
    required this.local,
    required this.remote,
    required this.useRemote,
  });

  bool get isRemote => useRemote.value;

  @override
  Future<List<Group>> getAllByProject(String projectId) {
    return isRemote
        ? remote.getAllByProject(projectId)
        : local.getAllByProject(projectId);
  }

  @override
  Future<void> save(Group group) {
    return isRemote ? remote.save(group) : local.save(group);
  }

  @override
  Future<void> delete(String projectId, String groupId) {
    return isRemote
        ? remote.delete(projectId, groupId)
        : local.delete(projectId, groupId);
  }
}
