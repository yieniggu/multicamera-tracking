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
    final allProjects = await projectRepository.getAll();
    if (allProjects.isEmpty) return false;

    final groups = await groupRepository.getAllByProject(allProjects.first.id);
    return groups.isNotEmpty;
  }
}
