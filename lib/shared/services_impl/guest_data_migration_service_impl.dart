import 'package:flutter/material.dart';
import 'package:multicamera_tracking/features/auth/domain/entities/access_role.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/camera_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/group_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/project_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/camera_remote_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/group_remote_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/project_remote_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/shared/domain/entities/guest_migration.dart';
import 'package:multicamera_tracking/shared/domain/entities/guest_migration_plan_validation_exception.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_data_migration_service.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_migration_plan_validator.dart';
import 'package:multicamera_tracking/shared/utils/normalized_text.dart';
import 'package:uuid/uuid.dart';

class GuestDataMigrationServiceImpl implements GuestDataMigrationService {
  final ProjectLocalDatasource localProject;
  final GroupLocalDatasource localGroup;
  final CameraLocalDatasource localCamera;

  final ProjectRemoteDataSource remoteProject;
  final GroupRemoteDatasource remoteGroup;
  final CameraRemoteDatasource remoteCamera;

  GuestDataMigrationServiceImpl({
    required this.localProject,
    required this.localGroup,
    required this.localCamera,
    required this.remoteProject,
    required this.remoteGroup,
    required this.remoteCamera,
  });

  @override
  Future<GuestMigrationPreview> buildPreview({
    required String sourceUserId,
    required String targetUserId,
  }) async {
    final localTrees = await _loadLocalTrees(sourceUserId);
    final remoteTrees = await _loadRemoteTrees(targetUserId);
    return _buildPreviewFromTrees(localTrees, remoteTrees);
  }

  @override
  Future<void> migrate({
    required String sourceUserId,
    required String targetUserId,
    GuestMigrationPlan? plan,
  }) async {
    debugPrint(
      "[MIGRATION] Starting guest migration source=$sourceUserId target=$targetUserId",
    );

    final localTrees = await _loadLocalTrees(sourceUserId);
    if (localTrees.isEmpty) {
      debugPrint("[MIGRATION] No local guest data to migrate.");
      return;
    }

    final remoteTrees = await _loadRemoteTrees(targetUserId);
    if (remoteTrees.isEmpty && plan == null) {
      for (final localTree in localTrees.values) {
        await _ensureUniqueRemoteProjectName(
          targetUserId,
          localTree.project.name,
        );
        await _createProjectFromLocal(
          localTree: localTree,
          targetUserId: targetUserId,
        );
      }
      return;
    }

    final effectiveProjectResolutions = <String, ProjectMergeResolution>{};
    for (final localTree in localTrees.values) {
      final hasExplicitResolution =
          plan?.projectResolutions.containsKey(localTree.project.id) ?? false;
      final resolution = hasExplicitResolution
          ? plan!.projectResolutions[localTree.project.id]!
          : _buildDefaultProjectResolution(localTree, remoteTrees);
      effectiveProjectResolutions[localTree.project.id] = resolution;
    }

    final effectivePlan = GuestMigrationPlan(
      projectResolutions: effectiveProjectResolutions,
    );
    final validationIssues = validateGuestMigrationPlan(
      preview: _buildPreviewFromTrees(localTrees, remoteTrees),
      plan: effectivePlan,
    );
    if (validationIssues.isNotEmpty) {
      for (final issue in validationIssues) {
        debugPrint('[MIGRATION][BLOCKER] $issue');
      }
      throw GuestMigrationPlanValidationException(validationIssues);
    }

    for (final localTree in localTrees.values) {
      final hasExplicitResolution =
          plan?.projectResolutions.containsKey(localTree.project.id) ?? false;
      final resolution = effectiveProjectResolutions[localTree.project.id]!;
      final resolvedRemoteTree = resolution.targetRemoteProjectId != null
          ? remoteTrees[resolution.targetRemoteProjectId]
          : _findRemoteProjectByName(
              remoteTrees.values,
              localTree.project.name,
            );
      debugPrint(
        '[MIGRATION][PROJECT] source="${localTree.project.name}" '
        'strategy=${_strategyLabel(resolution.strategy)} '
        'target="${resolvedRemoteTree?.project.name ?? 'create-new'}"',
      );

      await _applyProjectResolution(
        localTree: localTree,
        resolution: resolution,
        targetUserId: targetUserId,
        remoteTrees: remoteTrees,
        allowNameMatchFallback: !hasExplicitResolution,
      );
    }

    debugPrint("[MIGRATION] Migration completed.");
  }

  GuestMigrationPreview _buildPreviewFromTrees(
    Map<String, _ProjectTree> localTrees,
    Map<String, _ProjectTree> remoteTrees,
  ) {
    final remoteOptions =
        remoteTrees.values.map(_toRemoteProjectOption).toList()..sort(
          (a, b) => normalizeComparableText(
            a.name,
          ).compareTo(normalizeComparableText(b.name)),
        );

    final projectConflicts =
        localTrees.values
            .map(
              (localTree) => ProjectConflictPreview(
                localProjectId: localTree.project.id,
                localName: localTree.project.name,
                localDescription: localTree.project.description,
                remoteOptions: remoteOptions,
                groupConflicts:
                    localTree.groups.values
                        .map(
                          (group) => GroupConflictPreview(
                            localGroupId: group.id,
                            localName: group.name,
                            localDescription: group.description,
                            cameraConflicts:
                                (localTree.camerasByGroup[group.id]?.values
                                            .map(
                                              (camera) => CameraConflictPreview(
                                                localCameraId: camera.id,
                                                localName: camera.name,
                                                localDescription:
                                                    camera.description,
                                              ),
                                            )
                                            .toList() ??
                                        const <CameraConflictPreview>[])
                                    .toList()
                                  ..sort(
                                    (a, b) =>
                                        normalizeComparableText(
                                          a.localName,
                                        ).compareTo(
                                          normalizeComparableText(b.localName),
                                        ),
                                  ),
                          ),
                        )
                        .toList()
                      ..sort(
                        (a, b) => normalizeComparableText(
                          a.localName,
                        ).compareTo(normalizeComparableText(b.localName)),
                      ),
              ),
            )
            .toList()
          ..sort(
            (a, b) => normalizeComparableText(
              a.localName,
            ).compareTo(normalizeComparableText(b.localName)),
          );

    return GuestMigrationPreview(
      projectConflicts: projectConflicts,
      sourceProjectCount: localTrees.length,
      targetProjectCount: remoteTrees.length,
    );
  }

  Future<void> _applyProjectResolution({
    required _ProjectTree localTree,
    required ProjectMergeResolution resolution,
    required String targetUserId,
    required Map<String, _ProjectTree> remoteTrees,
    required bool allowNameMatchFallback,
  }) async {
    if (resolution.strategy == MergeStrategy.skip) return;

    final requestedRemoteTree = resolution.targetRemoteProjectId != null
        ? remoteTrees[resolution.targetRemoteProjectId]
        : (allowNameMatchFallback
              ? _findRemoteProjectByName(
                  remoteTrees.values,
                  localTree.project.name,
                )
              : null);
    final sameNameRemoteTree = _findRemoteProjectByName(
      remoteTrees.values,
      localTree.project.name,
    );
    final remoteTree =
        resolution.strategy == MergeStrategy.overwrite &&
            sameNameRemoteTree != null
        ? sameNameRemoteTree
        : requestedRemoteTree;

    if (resolution.strategy == MergeStrategy.overwrite) {
      if (remoteTree == null) {
        await _ensureUniqueRemoteProjectName(
          targetUserId,
          localTree.project.name,
        );
        await _createProjectFromLocal(
          localTree: localTree,
          targetUserId: targetUserId,
        );
      } else {
        await _ensureUniqueRemoteProjectName(
          targetUserId,
          localTree.project.name,
          exceptProjectId: remoteTree.project.id,
        );
        await _overwriteProject(
          localTree: localTree,
          remoteTree: remoteTree,
          targetUserId: targetUserId,
        );
      }
      return;
    }

    if (remoteTree == null) {
      await _ensureUniqueRemoteProjectName(
        targetUserId,
        localTree.project.name,
      );
      await _createProjectFromLocal(
        localTree: localTree,
        targetUserId: targetUserId,
      );
      return;
    }

    await _mergeProject(
      localTree: localTree,
      remoteTree: remoteTree,
      resolution: resolution,
      targetUserId: targetUserId,
    );
  }

  Future<void> _overwriteProject({
    required _ProjectTree localTree,
    required _ProjectTree remoteTree,
    required String targetUserId,
  }) async {
    await _wipeRemoteProjectTree(remoteTree);

    await remoteProject.save(
      Project(
        id: remoteTree.project.id,
        name: localTree.project.name,
        description: localTree.project.description,
        isDefault: remoteTree.project.isDefault,
        userRoles: {targetUserId: AccessRole.admin},
        createdAt: localTree.project.createdAt,
        updatedAt: DateTime.now(),
      ),
    );

    for (final localGroup in localTree.groups.values) {
      await _createGroupFromLocal(
        localGroup: localGroup,
        localTree: localTree,
        targetProjectId: remoteTree.project.id,
        targetUserId: targetUserId,
      );
    }
  }

  Future<void> _mergeProject({
    required _ProjectTree localTree,
    required _ProjectTree remoteTree,
    required ProjectMergeResolution resolution,
    required String targetUserId,
  }) async {
    _validateRuntimeGroupBindings(
      localTree: localTree,
      remoteTree: remoteTree,
      resolution: resolution,
    );

    await remoteProject.save(
      remoteTree.project.copyWith(
        description: remoteTree.project.description.isNotEmpty
            ? remoteTree.project.description
            : localTree.project.description,
        userRoles: {
          ...remoteTree.project.userRoles,
          targetUserId: AccessRole.admin,
        },
        updatedAt: _latest(
          localTree.project.updatedAt,
          remoteTree.project.updatedAt,
        ),
      ),
    );

    for (final localGroup in localTree.groups.values) {
      final groupResolution = resolution.resolutionForGroup(localGroup.id);
      if (groupResolution.strategy == MergeStrategy.skip) continue;

      final requestedRemoteGroup = groupResolution.targetRemoteGroupId != null
          ? remoteTree.groups[groupResolution.targetRemoteGroupId]
          : _findRemoteGroupByName(remoteTree, localGroup.name);
      final sameNameRemoteGroup = _findRemoteGroupByName(
        remoteTree,
        localGroup.name,
      );
      final remoteGroup =
          groupResolution.strategy == MergeStrategy.overwrite &&
              sameNameRemoteGroup != null
          ? sameNameRemoteGroup
          : requestedRemoteGroup;
      debugPrint(
        '[MIGRATION][GROUP] project="${localTree.project.name}" '
        'source="${localGroup.name}" '
        'strategy=${_strategyLabel(groupResolution.strategy)} '
        'target="${remoteGroup?.name ?? 'create-new'}"',
      );

      if (groupResolution.strategy == MergeStrategy.overwrite) {
        if (remoteGroup == null) {
          await _createGroupFromLocal(
            localGroup: localGroup,
            localTree: localTree,
            targetProjectId: remoteTree.project.id,
            targetUserId: targetUserId,
          );
        } else {
          await _overwriteGroup(
            localGroup: localGroup,
            localTree: localTree,
            remoteGroupEntity: remoteGroup,
            targetProjectId: remoteTree.project.id,
            targetUserId: targetUserId,
          );
        }
        continue;
      }

      if (remoteGroup == null) {
        await _createGroupFromLocal(
          localGroup: localGroup,
          localTree: localTree,
          targetProjectId: remoteTree.project.id,
          targetUserId: targetUserId,
        );
        continue;
      }

      await _mergeGroup(
        localGroup: localGroup,
        localTree: localTree,
        remoteGroupEntity: remoteGroup,
        remoteTree: remoteTree,
        groupResolution: groupResolution,
        targetProjectId: remoteTree.project.id,
        targetUserId: targetUserId,
      );
    }
  }

  void _validateRuntimeGroupBindings({
    required _ProjectTree localTree,
    required _ProjectTree remoteTree,
    required ProjectMergeResolution resolution,
  }) {
    final bindingsByTargetGroup = <String, List<_RuntimeGroupBinding>>{};

    for (final localGroup in localTree.groups.values) {
      final groupResolution = resolution.resolutionForGroup(localGroup.id);
      if (groupResolution.strategy == MergeStrategy.skip) continue;

      final requestedRemoteGroup = groupResolution.targetRemoteGroupId != null
          ? remoteTree.groups[groupResolution.targetRemoteGroupId]
          : _findRemoteGroupByName(remoteTree, localGroup.name);
      final sameNameRemoteGroup = _findRemoteGroupByName(
        remoteTree,
        localGroup.name,
      );
      final remoteGroup =
          groupResolution.strategy == MergeStrategy.overwrite &&
              sameNameRemoteGroup != null
          ? sameNameRemoteGroup
          : requestedRemoteGroup;
      if (remoteGroup == null) continue;

      final localCameras =
          localTree.camerasByGroup[localGroup.id]?.values ?? const <Camera>[];
      final activeCameraNames = <String>{};
      for (final localCamera in localCameras) {
        final cameraResolution = groupResolution.resolutionForCamera(
          localCamera.id,
        );
        if (cameraResolution.strategy == MergeStrategy.skip) continue;
        final normalized = normalizeComparableText(localCamera.name);
        if (normalized.isNotEmpty) {
          activeCameraNames.add(normalized);
        }
      }

      final binding = _RuntimeGroupBinding(
        sourceProjectName: localTree.project.name,
        sourceGroupName: localGroup.name,
        targetProjectName: remoteTree.project.name,
        targetGroupName: remoteGroup.name,
        strategy: groupResolution.strategy,
        activeCameraNames: activeCameraNames,
      );
      bindingsByTargetGroup.putIfAbsent(remoteGroup.id, () => []).add(binding);
    }

    final issues = <String>[];
    for (final entry in bindingsByTargetGroup.entries) {
      final bindings = entry.value;
      if (bindings.length < 2) continue;

      final targetProjectName = bindings.first.targetProjectName;
      final targetGroupName = bindings.first.targetGroupName;
      final overwriteBindings = bindings
          .where((binding) => binding.strategy == MergeStrategy.overwrite)
          .toList();

      if (overwriteBindings.length > 1) {
        final sources = overwriteBindings
            .map(
              (binding) =>
                  '${binding.sourceProjectName} / ${binding.sourceGroupName}',
            )
            .join(', ');
        issues.add(
          'Group "$targetGroupName" in project "$targetProjectName" has multiple overwrite sources: $sources.',
        );
      }

      final nonOverwriteBindings = bindings
          .where((binding) => binding.strategy != MergeStrategy.overwrite)
          .toList();
      if (overwriteBindings.isNotEmpty && nonOverwriteBindings.isNotEmpty) {
        final overwriteSources = overwriteBindings
            .map(
              (binding) =>
                  '${binding.sourceProjectName} / ${binding.sourceGroupName}',
            )
            .join(', ');
        final otherSources = nonOverwriteBindings
            .map(
              (binding) =>
                  '${binding.sourceProjectName} / ${binding.sourceGroupName}',
            )
            .join(', ');
        issues.add(
          'Group "$targetGroupName" in project "$targetProjectName" cannot mix overwrite ($overwriteSources) with additional sources ($otherSources).',
        );
      }

      if (overwriteBindings.isNotEmpty) {
        continue;
      }

      final cameraSourcesByName = <String, List<String>>{};
      for (final binding in bindings) {
        for (final cameraName in binding.activeCameraNames) {
          final sourceLabel =
              '${binding.sourceProjectName} / ${binding.sourceGroupName}';
          cameraSourcesByName
              .putIfAbsent(cameraName, () => [])
              .add(sourceLabel);
        }
      }

      for (final cameraEntry in cameraSourcesByName.entries) {
        if (cameraEntry.value.length < 2) continue;
        issues.add(
          'Camera "${cameraEntry.key}" appears in multiple sources for group "$targetGroupName" in project "$targetProjectName": ${cameraEntry.value.join(', ')}.',
        );
      }
    }

    if (issues.isNotEmpty) {
      for (final issue in issues) {
        debugPrint('[MIGRATION][RUNTIME-BLOCKER] $issue');
      }
      throw GuestMigrationPlanValidationException(issues);
    }
  }

  Future<void> _overwriteGroup({
    required Group localGroup,
    required _ProjectTree localTree,
    required Group remoteGroupEntity,
    required String targetProjectId,
    required String targetUserId,
  }) async {
    final remoteCameras = await remoteCamera.getAllByGroup(
      targetProjectId,
      remoteGroupEntity.id,
    );
    for (final camera in remoteCameras) {
      await remoteCamera.deleteById(
        targetProjectId,
        remoteGroupEntity.id,
        camera.id,
      );
    }

    await remoteGroup.save(
      Group(
        id: remoteGroupEntity.id,
        name: localGroup.name,
        description: localGroup.description,
        isDefault: remoteGroupEntity.isDefault,
        projectId: targetProjectId,
        userRoles: {targetUserId: AccessRole.admin},
        createdAt: localGroup.createdAt,
        updatedAt: DateTime.now(),
      ),
    );

    final localCameras =
        localTree.camerasByGroup[localGroup.id]?.values ?? const <Camera>[];
    for (final localCamera in localCameras) {
      await _createCameraFromLocal(
        localCamera: localCamera,
        targetProjectId: targetProjectId,
        targetGroupId: remoteGroupEntity.id,
        targetUserId: targetUserId,
      );
    }
  }

  Future<void> _mergeGroup({
    required Group localGroup,
    required _ProjectTree localTree,
    required Group remoteGroupEntity,
    required _ProjectTree remoteTree,
    required GroupMergeResolution groupResolution,
    required String targetProjectId,
    required String targetUserId,
  }) async {
    await remoteGroup.save(
      remoteGroupEntity.copyWith(
        description: remoteGroupEntity.description.isNotEmpty
            ? remoteGroupEntity.description
            : localGroup.description,
        userRoles: {
          ...remoteGroupEntity.userRoles,
          targetUserId: AccessRole.admin,
        },
        updatedAt: _latest(localGroup.updatedAt, remoteGroupEntity.updatedAt),
      ),
    );

    final localCameras =
        localTree.camerasByGroup[localGroup.id]?.values ?? const <Camera>[];
    final remoteCameras =
        remoteTree.camerasByGroup[remoteGroupEntity.id] ??
        const <String, Camera>{};

    for (final localCamera in localCameras) {
      final cameraResolution = groupResolution.resolutionForCamera(
        localCamera.id,
      );
      if (cameraResolution.strategy == MergeStrategy.skip) continue;

      final remoteCameraTarget = cameraResolution.targetRemoteCameraId != null
          ? remoteCameras[cameraResolution.targetRemoteCameraId]
          : _findRemoteCameraByName(remoteCameras.values, localCamera.name);
      debugPrint(
        '[MIGRATION][CAMERA] projectId=$targetProjectId group="${localGroup.name}" '
        'source="${localCamera.name}" strategy=${_strategyLabel(cameraResolution.strategy)} '
        'target="${remoteCameraTarget?.name ?? 'create-new'}"',
      );

      if (remoteCameraTarget == null) {
        await _createCameraFromLocal(
          localCamera: localCamera,
          targetProjectId: targetProjectId,
          targetGroupId: remoteGroupEntity.id,
          targetUserId: targetUserId,
        );
        continue;
      }

      await _overwriteCamera(
        localCamera: localCamera,
        remoteCameraTarget: remoteCameraTarget,
        targetProjectId: targetProjectId,
        targetGroupId: remoteGroupEntity.id,
        targetUserId: targetUserId,
      );
    }
  }

  Future<void> _overwriteCamera({
    required Camera localCamera,
    required Camera remoteCameraTarget,
    required String targetProjectId,
    required String targetGroupId,
    required String targetUserId,
  }) async {
    await remoteCamera.save(
      Camera(
        id: remoteCameraTarget.id,
        name: localCamera.name,
        description: localCamera.description,
        rtspUrl: localCamera.rtspUrl,
        thumbnailUrl: localCamera.thumbnailUrl,
        projectId: targetProjectId,
        groupId: targetGroupId,
        userRoles: {targetUserId: AccessRole.admin},
        createdAt: localCamera.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<String> _createProjectFromLocal({
    required _ProjectTree localTree,
    required String targetUserId,
    String? targetProjectId,
  }) async {
    final projectId = targetProjectId ?? const Uuid().v4();
    await remoteProject.save(
      Project(
        id: projectId,
        name: localTree.project.name,
        description: localTree.project.description,
        isDefault: localTree.project.isDefault,
        userRoles: {targetUserId: AccessRole.admin},
        createdAt: localTree.project.createdAt,
        updatedAt: DateTime.now(),
      ),
    );

    for (final localGroup in localTree.groups.values) {
      await _createGroupFromLocal(
        localGroup: localGroup,
        localTree: localTree,
        targetProjectId: projectId,
        targetUserId: targetUserId,
      );
    }
    return projectId;
  }

  Future<String> _createGroupFromLocal({
    required Group localGroup,
    required _ProjectTree localTree,
    required String targetProjectId,
    required String targetUserId,
    String? targetGroupId,
  }) async {
    final groupId = targetGroupId ?? const Uuid().v4();
    await remoteGroup.save(
      Group(
        id: groupId,
        name: localGroup.name,
        description: localGroup.description,
        isDefault: localGroup.isDefault,
        projectId: targetProjectId,
        userRoles: {targetUserId: AccessRole.admin},
        createdAt: localGroup.createdAt,
        updatedAt: DateTime.now(),
      ),
    );

    final localCameras =
        localTree.camerasByGroup[localGroup.id]?.values ?? const <Camera>[];
    for (final localCamera in localCameras) {
      await _createCameraFromLocal(
        localCamera: localCamera,
        targetProjectId: targetProjectId,
        targetGroupId: groupId,
        targetUserId: targetUserId,
      );
    }
    return groupId;
  }

  Future<void> _createCameraFromLocal({
    required Camera localCamera,
    required String targetProjectId,
    required String targetGroupId,
    required String targetUserId,
    String? targetCameraId,
  }) async {
    await remoteCamera.save(
      Camera(
        id: targetCameraId ?? const Uuid().v4(),
        name: localCamera.name,
        description: localCamera.description,
        rtspUrl: localCamera.rtspUrl,
        thumbnailUrl: localCamera.thumbnailUrl,
        projectId: targetProjectId,
        groupId: targetGroupId,
        userRoles: {targetUserId: AccessRole.admin},
        createdAt: localCamera.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _wipeRemoteProjectTree(_ProjectTree remoteTree) async {
    for (final group in remoteTree.groups.values) {
      final cameras = await remoteCamera.getAllByGroup(
        remoteTree.project.id,
        group.id,
      );
      for (final camera in cameras) {
        await remoteCamera.deleteById(
          remoteTree.project.id,
          group.id,
          camera.id,
        );
      }

      if (group.isDefault) {
        await remoteGroup.save(
          group.copyWith(isDefault: false, updatedAt: DateTime.now()),
        );
      }
      await remoteGroup.delete(remoteTree.project.id, group.id);
    }
  }

  Future<void> _ensureUniqueRemoteProjectName(
    String targetUserId,
    String projectName, {
    String? exceptProjectId,
  }) async {
    final normalized = normalizeComparableText(projectName);
    final remoteProjects = await remoteProject.getAll(targetUserId);
    final hasDuplicate = remoteProjects.any(
      (project) =>
          project.id != exceptProjectId &&
          normalizeComparableText(project.name) == normalized,
    );
    if (hasDuplicate) {
      throw Exception("Project name already exists for this account.");
    }
  }

  ProjectMergeResolution _buildDefaultProjectResolution(
    _ProjectTree localTree,
    Map<String, _ProjectTree> remoteTrees,
  ) {
    final remote = _findRemoteProjectByName(
      remoteTrees.values,
      localTree.project.name,
    );
    return ProjectMergeResolution(
      localProjectId: localTree.project.id,
      strategy: MergeStrategy.merge,
      targetRemoteProjectId: remote?.project.id,
    );
  }

  _ProjectTree? _findRemoteProjectByName(
    Iterable<_ProjectTree> remoteTrees,
    String name,
  ) {
    final normalizedName = normalizeComparableText(name);
    for (final remote in remoteTrees) {
      if (normalizeComparableText(remote.project.name) == normalizedName) {
        return remote;
      }
    }
    return null;
  }

  Group? _findRemoteGroupByName(_ProjectTree remoteTree, String name) {
    final normalizedName = normalizeComparableText(name);
    for (final remoteGroup in remoteTree.groups.values) {
      if (normalizeComparableText(remoteGroup.name) == normalizedName) {
        return remoteGroup;
      }
    }
    return null;
  }

  Camera? _findRemoteCameraByName(Iterable<Camera> remoteCameras, String name) {
    final normalizedName = normalizeComparableText(name);
    for (final remoteCamera in remoteCameras) {
      if (normalizeComparableText(remoteCamera.name) == normalizedName) {
        return remoteCamera;
      }
    }
    return null;
  }

  RemoteProjectOption _toRemoteProjectOption(_ProjectTree tree) {
    final groups =
        tree.groups.values
            .map(
              (group) => RemoteGroupOption(
                id: group.id,
                name: group.name,
                description: group.description,
                cameras:
                    (tree.camerasByGroup[group.id]?.values
                                .map(
                                  (camera) => RemoteCameraOption(
                                    id: camera.id,
                                    name: camera.name,
                                    description: camera.description,
                                  ),
                                )
                                .toList() ??
                            const <RemoteCameraOption>[])
                        .toList()
                      ..sort(
                        (a, b) => normalizeComparableText(
                          a.name,
                        ).compareTo(normalizeComparableText(b.name)),
                      ),
              ),
            )
            .toList()
          ..sort(
            (a, b) => normalizeComparableText(
              a.name,
            ).compareTo(normalizeComparableText(b.name)),
          );

    return RemoteProjectOption(
      id: tree.project.id,
      name: tree.project.name,
      description: tree.project.description,
      groups: groups,
    );
  }

  Future<Map<String, _ProjectTree>> _loadLocalTrees(String sourceUserId) async {
    final projects = await localProject.getAll(sourceUserId);
    final trees = <String, _ProjectTree>{};

    for (final project in projects) {
      final groups = await localGroup.getAllByProject(project.id);
      final groupsById = <String, Group>{
        for (final group in groups) group.id: group,
      };
      final camerasByGroup = <String, Map<String, Camera>>{};

      for (final group in groups) {
        final cameras = await localCamera.getAllByGroup(project.id, group.id);
        camerasByGroup[group.id] = {
          for (final camera in cameras) camera.id: camera,
        };
      }

      trees[project.id] = _ProjectTree(
        project: project,
        groups: groupsById,
        camerasByGroup: camerasByGroup,
      );
    }

    return trees;
  }

  Future<Map<String, _ProjectTree>> _loadRemoteTrees(
    String targetUserId,
  ) async {
    final projects = await remoteProject.getAll(targetUserId);
    final trees = <String, _ProjectTree>{};

    for (final project in projects) {
      final groups = await remoteGroup.getAllByProject(project.id);
      final groupsById = <String, Group>{
        for (final group in groups) group.id: group,
      };
      final camerasByGroup = <String, Map<String, Camera>>{};

      for (final group in groups) {
        final cameras = await remoteCamera.getAllByGroup(project.id, group.id);
        camerasByGroup[group.id] = {
          for (final camera in cameras) camera.id: camera,
        };
      }

      trees[project.id] = _ProjectTree(
        project: project,
        groups: groupsById,
        camerasByGroup: camerasByGroup,
      );
    }

    return trees;
  }

  DateTime _latest(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  String _strategyLabel(MergeStrategy strategy) {
    switch (strategy) {
      case MergeStrategy.merge:
        return 'merge';
      case MergeStrategy.overwrite:
        return 'overwrite';
      case MergeStrategy.skip:
        return 'skip';
    }
  }
}

class _ProjectTree {
  final Project project;
  final Map<String, Group> groups;
  final Map<String, Map<String, Camera>> camerasByGroup;

  const _ProjectTree({
    required this.project,
    required this.groups,
    required this.camerasByGroup,
  });
}

class _RuntimeGroupBinding {
  final String sourceProjectName;
  final String sourceGroupName;
  final String targetProjectName;
  final String targetGroupName;
  final MergeStrategy strategy;
  final Set<String> activeCameraNames;

  const _RuntimeGroupBinding({
    required this.sourceProjectName,
    required this.sourceGroupName,
    required this.targetProjectName,
    required this.targetGroupName,
    required this.strategy,
    required this.activeCameraNames,
  });
}
