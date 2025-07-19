import 'package:flutter/material.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/access_role.dart';
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/camera_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/group_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/project_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/camera_remote_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/group_remote_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/project_remote_datasource.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_data_migration_service.dart';

class GuestDataMigrationServiceImpl implements GuestDataMigrationService {
  final ProjectLocalDatasource localProject;
  final GroupLocalDatasource localGroup;
  final CameraLocalDatasource localCamera;

  final ProjectRemoteDataSource remoteProject;
  final GroupRemoteDatasource remoteGroup;
  final CameraRemoteDatasource remoteCamera;

  final AuthRepository authRepository;

  GuestDataMigrationServiceImpl({
    required this.localProject,
    required this.localGroup,
    required this.localCamera,
    required this.remoteProject,
    required this.remoteGroup,
    required this.remoteCamera,
    required this.authRepository,
  });

  @override
  Future<void> migrate() async {
    debugPrint("[MIGRATION] Reading guest data from Local source...");

    final userId = authRepository.currentUser!.id;
    final localProjects = await localProject.getAll(userId);

    for (final project in localProjects) {
      final updatedProject = project.copyWith(
        userRoles: {userId: AccessRole.admin},
      );
      await remoteProject.save(updatedProject);
      debugPrint("[MIGRATION] Saved project ${project.name}");

      final localGroups = await localGroup.getAllByProject(project.id);

      for (final group in localGroups) {
        final updatedGroup = group.copyWith(
          userRoles: {userId: AccessRole.admin},
        );
        await remoteGroup.save(updatedGroup);
        debugPrint("[MIGRATION] └ Saved group ${group.name}");

        final localCameras = await localCamera.getAllByGroup(
          project.id,
          group.id,
        );

        for (final camera in localCameras) {
          await remoteCamera.save(camera);
          debugPrint("[MIGRATION]     └ Saved camera ${camera.name}");
        }
      }
    }

    debugPrint("✅ Guest data migrated to Remote Source for user $userId");
  }
}
