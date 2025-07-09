import 'package:multicamera_tracking/domain/entities/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> getAll();
  Future<Project?> getDefaultProject();
  Future<void> save(Project project);
}
