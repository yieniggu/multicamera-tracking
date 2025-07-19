import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';

abstract class ProjectDataSource {
  Future<List<Project>> getAll(String userId);
  Future<void> save(Project project);
  Future<void> delete(String id);
}
