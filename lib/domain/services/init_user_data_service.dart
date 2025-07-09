import 'package:multicamera_tracking/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/domain/repositories/group_repository.dart';

abstract class InitUserDataService {
  Future<void> ensureDefaultProjectAndGroup(String userId);

  ProjectRepository get projectRepository;
  GroupRepository get groupRepository;
}
