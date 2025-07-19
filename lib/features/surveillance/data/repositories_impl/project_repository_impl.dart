import 'package:flutter/foundation.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/project_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/project_remote_datasource.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  final ProjectRemoteDataSource remote;
  final ProjectLocalDatasource local;
  final AuthRepository authRepository;
  final ValueListenable<bool> useRemote;

  ProjectRepositoryImpl({
    required this.local,
    required this.remote,
    required this.authRepository,
    required this.useRemote,
  });

  bool get isRemote => useRemote.value;

  @override
  Future<List<Project>> getAll() {
    final user = authRepository.currentUser;
    if (user == null) throw Exception("[PROJ-REPO] No authenticated user.");
    debugPrint("[PROJ-REPO-IMPL] getting all projects. (remote=$isRemote)");

    final projects = isRemote ? remote.getAll(user.id) : local.getAll(user.id);

    debugPrint(
      "[PROJ-REPO-IMPL] Found the following projects: ${projects}",
    );

    return projects;
  }

  @override
  Future<void> save(Project project) {
    debugPrint(
      "[PROJ-REPO-IMPL] saving new project ${project.toString()}. (remote=$isRemote)",
    );
    return isRemote ? remote.save(project) : local.save(project);
  }

  @override
  Future<void> delete(String id) {
    debugPrint("[PROJ-REPO-IMPL] deleting project: $id. (remote=$isRemote)");
    return isRemote ? remote.delete(id) : local.delete(id);
  }
}
