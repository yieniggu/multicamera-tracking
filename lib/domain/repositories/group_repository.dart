import 'package:multicamera_tracking/domain/entities/group.dart';

abstract class GroupRepository {
  Future<List<Group>> getAll();
  Future<List<Group>> getAllByProject(String projecId);

  Future<void> save(Group group);
}
