import 'package:flutter/foundation.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/project_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/project_remote_datasource.dart';
import 'package:multicamera_tracking/shared/domain/services/event_bus.dart';
import 'package:multicamera_tracking/shared/domain/events/surveillance_event.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  final ProjectRemoteDataSource remote;
  final ProjectLocalDatasource local;
  final AuthRepository authRepository;
  final ValueListenable<bool> useRemote;
  final SurveillanceEventBus bus;

  ProjectRepositoryImpl({
    required this.local,
    required this.remote,
    required this.authRepository,
    required this.useRemote,
    required this.bus,
  });

  bool get isRemote => useRemote.value;

  @override
  Future<List<Project>> getAll() {
    final user = authRepository.currentUser;
    if (user == null) throw Exception("[PROJ-REPO] No authenticated user.");
    return isRemote ? remote.getAll(user.id) : local.getAll(user.id);
  }

  @override
  Future<void> save(Project project) async {
    if (!isRemote) {
      final user = authRepository.currentUser;
      if (user == null) throw Exception("[PROJ-REPO] No authenticated user.");
      final existing = await local.getAll(user.id);
      final isEditing = existing.any((p) => p.id == project.id);
      if (!isEditing && existing.isNotEmpty) {
        throw Exception("Trial limit reached: only 1 project in guest mode.");
      }
      await local.save(project);
    } else {
      await remote.save(project);
    }
    debugPrint('[REPO→BUS ${bus.id}] ProjectUpserted(${project.id})');
    bus.emit(ProjectUpserted(project));
  }

  @override
  Future<void> delete(String id) async {
    if (isRemote) {
      await remote.delete(id);
    } else {
      await local.delete(id);
    }
    bus.emit(ProjectDeleted(id));
  }
}
