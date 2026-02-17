import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/group_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/project_local_datasource.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_data_service.dart';

class GuestDataServiceImpl implements GuestDataService {
  final ProjectLocalDatasource projectLocalDatasource;
  final GroupLocalDatasource groupLocalDatasource;
  final AuthRepository authRepository;

  GuestDataServiceImpl({
    required this.projectLocalDatasource,
    required this.groupLocalDatasource,
    required this.authRepository,
  });

  @override
  Future<bool> hasDataToMigrate() async {
    final userId = authRepository.currentUser?.id ?? 'guest';
    final allProjects = await projectLocalDatasource.getAll(userId);
    if (allProjects.isEmpty) return false;

    final groups = await groupLocalDatasource.getAllByProject(
      allProjects.first.id,
    );
    return groups.isNotEmpty;
  }
}
