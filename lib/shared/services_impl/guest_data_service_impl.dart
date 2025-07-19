import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/group_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/project_local_datasource.dart';

class GuestDataService {
  final ProjectLocalDatasource projectLocalDatasource;
  final GroupLocalDatasource groupLocalDatasource;
  final AuthRepository authRepository;

  GuestDataService({
    required this.projectLocalDatasource,
    required this.groupLocalDatasource,
    required this.authRepository,
  });

  Future<bool> hasDataToMigrate() async {
    final userId = authRepository.currentUser!.id;
    final allProjects = await projectLocalDatasource.getAll(userId);
    if (allProjects.isEmpty) return false;

    final groups = await groupLocalDatasource.getAllByProject(
      allProjects.first.id,
    );
    return groups.isNotEmpty;
  }
}
