import 'package:hive/hive.dart';
import 'package:multicamera_tracking/domain/entities/project.dart';
import 'package:multicamera_tracking/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/data/models/project_model.dart';
import 'package:multicamera_tracking/data/models/project_model_mapper.dart';

class HiveProjectRepository implements ProjectRepository {
  final Box<ProjectModel> box;

  HiveProjectRepository({required this.box});

  @override
  Future<List<Project>> getAll() async {
    return box.values.map((e) => e.toEntity()).toList();
  }

  @override
  Future<Project?> getDefaultProject() async {
    return box.values.isNotEmpty ? box.values.first.toEntity() : null;
  }

  @override
  Future<void> save(Project project) async {
    await box.put(project.id, project.toModel());
  }
}
