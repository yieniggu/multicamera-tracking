import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/group_repository.dart';

class GetAllGroupsByProjectUseCase {
  final GroupRepository repo;
  GetAllGroupsByProjectUseCase(this.repo);

  Future<List<Group>> call(String projectId) => repo.getAllByProject(projectId);
}
