import 'package:multicamera_tracking/domain/entities/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> getAll();
  Future<void> save(Project project);
}
