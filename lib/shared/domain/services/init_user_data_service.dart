import 'package:multicamera_tracking/features/surveillance/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/group_repository.dart';

abstract class InitUserDataService {
  Future<void> ensureDefaultProjectAndGroup();

  ProjectRepository get projectRepository;
  GroupRepository get groupRepository;
}
