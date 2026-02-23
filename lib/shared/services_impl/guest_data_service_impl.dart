import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/camera_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/group_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/project_local_datasource.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuestDataServiceImpl implements GuestDataService {
  final ProjectLocalDatasource projectLocalDatasource;
  final GroupLocalDatasource groupLocalDatasource;
  final CameraLocalDatasource cameraLocalDatasource;
  final AuthRepository authRepository;

  GuestDataServiceImpl({
    required this.projectLocalDatasource,
    required this.groupLocalDatasource,
    required this.cameraLocalDatasource,
    required this.authRepository,
  });

  @override
  Future<bool> hasDataToMigrate({String? sourceUserId}) async {
    if (sourceUserId != null) {
      return _hasDataForSource(sourceUserId);
    }

    final candidate = await resolveMigrationSourceUserId(
      preferredSourceUserId: authRepository.currentUser?.id,
    );
    return candidate != null;
  }

  @override
  Future<String?> resolveMigrationSourceUserId({
    String? preferredSourceUserId,
  }) async {
    if (preferredSourceUserId != null &&
        await _hasDataForSource(preferredSourceUserId)) {
      return preferredSourceUserId;
    }

    final allProjects = await projectLocalDatasource.getAllForMigration();
    if (allProjects.isEmpty) return null;

    final statsByUserId = <String, _SourceStats>{};
    for (final project in allProjects) {
      for (final userId in project.userRoles.keys) {
        final current = statsByUserId[userId];
        if (current == null) {
          statsByUserId[userId] = _SourceStats(
            userId: userId,
            projectCount: 1,
            latestUpdatedAt: project.updatedAt,
          );
        } else {
          statsByUserId[userId] = _SourceStats(
            userId: userId,
            projectCount: current.projectCount + 1,
            latestUpdatedAt: project.updatedAt.isAfter(current.latestUpdatedAt)
                ? project.updatedAt
                : current.latestUpdatedAt,
          );
        }
      }
    }

    final candidates = <_SourceStats>[];
    for (final stat in statsByUserId.values) {
      if (await _hasDataForSource(stat.userId)) {
        candidates.add(stat);
      }
    }
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final byUpdated = b.latestUpdatedAt.compareTo(a.latestUpdatedAt);
      if (byUpdated != 0) return byUpdated;
      return b.projectCount.compareTo(a.projectCount);
    });
    return candidates.first.userId;
  }

  @override
  Future<bool> adoptLocalDataForUser({
    required String targetUserId,
    String? preferredSourceUserId,
  }) async {
    final sourceUserId = await resolveMigrationSourceUserId(
      preferredSourceUserId: preferredSourceUserId,
    );
    if (sourceUserId == null || sourceUserId == targetUserId) return false;

    final sourceProjects = await projectLocalDatasource.getAll(sourceUserId);
    if (sourceProjects.isEmpty) return false;

    var changed = false;

    for (final project in sourceProjects) {
      if (!project.userRoles.containsKey(targetUserId)) {
        final role =
            project.userRoles[sourceUserId] ?? project.userRoles.values.first;
        await projectLocalDatasource.save(
          project.copyWith(
            userRoles: {...project.userRoles, targetUserId: role},
          ),
        );
        changed = true;
      }

      final groups = await groupLocalDatasource.getAllByProject(project.id);
      for (final group in groups) {
        if (!group.userRoles.containsKey(targetUserId)) {
          final role =
              group.userRoles[sourceUserId] ?? group.userRoles.values.first;
          await groupLocalDatasource.save(
            group.copyWith(userRoles: {...group.userRoles, targetUserId: role}),
          );
          changed = true;
        }

        final cameras = await cameraLocalDatasource.getAllByGroup(
          project.id,
          group.id,
        );
        for (final camera in cameras) {
          if (!camera.userRoles.containsKey(targetUserId)) {
            final role =
                camera.userRoles[sourceUserId] ?? camera.userRoles.values.first;
            await cameraLocalDatasource.save(
              camera.copyWith(
                userRoles: {...camera.userRoles, targetUserId: role},
              ),
            );
            changed = true;
          }
        }
      }
    }

    return changed;
  }

  @override
  Future<void> clearLocalData() async {
    await cameraLocalDatasource.box.clear();
    await groupLocalDatasource.box.clear();
    await projectLocalDatasource.box.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', false);
  }

  Future<bool> _hasDataForSource(String sourceUserId) async {
    final projects = await projectLocalDatasource.getAll(sourceUserId);
    // A renamed/newly created project without groups is still meaningful data
    // and must be considered migratable.
    return projects.isNotEmpty;
  }
}

class _SourceStats {
  final String userId;
  final int projectCount;
  final DateTime latestUpdatedAt;

  const _SourceStats({
    required this.userId,
    required this.projectCount,
    required this.latestUpdatedAt,
  });
}
