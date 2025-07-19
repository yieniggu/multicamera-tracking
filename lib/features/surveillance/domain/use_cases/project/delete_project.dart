import 'package:multicamera_tracking/features/surveillance/domain/repositories/project_repository.dart';

class DeleteProjectUseCase {
  final ProjectRepository repo;
  DeleteProjectUseCase(this.repo);

  Future<void> call(String id) => repo.delete(id);
}
