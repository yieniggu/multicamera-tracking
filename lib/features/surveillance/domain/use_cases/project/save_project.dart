import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/project_repository.dart';

class SaveProjectUseCase {
  final ProjectRepository repo;
  SaveProjectUseCase(this.repo);

  Future<void> call(Project project) => repo.save(project);
}
