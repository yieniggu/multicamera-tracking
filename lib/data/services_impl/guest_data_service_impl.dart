import 'package:multicamera_tracking/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/domain/repositories/group_repository.dart';

class GuestDataService {
  final ProjectRepository projectRepository;
  final GroupRepository groupRepository;

  GuestDataService({
    required this.projectRepository,
    required this.groupRepository,
  });

  Future<bool> hasDataToMigrate() async {
    final defaultProject = await projectRepository.getDefaultProject();
    if (defaultProject == null) return false;

    final defaultGroup = await groupRepository.getDefaultGroup(
      defaultProject.id,
    );
    return defaultGroup != null;
  }
}
