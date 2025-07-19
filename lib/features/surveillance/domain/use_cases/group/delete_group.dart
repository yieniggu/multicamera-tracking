import 'package:multicamera_tracking/features/surveillance/domain/repositories/group_repository.dart';

class DeleteGroupUseCase {
  final GroupRepository repo;
  DeleteGroupUseCase(this.repo);

  Future<void> call(String projectId, String groupId) =>
      repo.delete(projectId, groupId);
}
