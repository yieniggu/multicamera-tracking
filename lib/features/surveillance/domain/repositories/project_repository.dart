import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> getAll();
  Future<void> save(Project project);
  Future<void> delete(String id); 
}
