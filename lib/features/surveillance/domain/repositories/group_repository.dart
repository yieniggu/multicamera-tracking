import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';

abstract class GroupRepository {
  Future<List<Group>> getAllByProject(String projecId);
  Future<void> delete(String projectId, String groupId);
  Future<void> save(Group group);
}
