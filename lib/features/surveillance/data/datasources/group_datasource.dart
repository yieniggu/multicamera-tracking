import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';

abstract class GroupDataSource {
  Future<List<Group>> getAllByProject(String projectId);
  Future<void> save(Group group);
  Future<void> delete(String projectId, String groupId);
}
