import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/project_repository.dart';

class GetAllProjectsUseCase {
  final ProjectRepository repo;
  GetAllProjectsUseCase(this.repo);

  Future<List<Project>> call() => repo.getAll();
}
