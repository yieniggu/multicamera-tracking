import 'package:flutter/material.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/widgets/migration_endpoint_card.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/widgets/migration_issue_card.dart';
import 'package:multicamera_tracking/l10n/app_localizations.dart';
import 'package:multicamera_tracking/shared/domain/entities/guest_migration.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_migration_plan_validator.dart';
import 'package:multicamera_tracking/shared/utils/normalized_text.dart';

Future<GuestMigrationPlan?> showMigrationConflictScreen({
  required BuildContext context,
  required GuestMigrationPreview preview,
  List<String> initialValidationIssues = const [],
}) {
  final l10n = AppLocalizations.of(context)!;

  final projectStrategies = <String, MergeStrategy>{};
  final selectedRemoteProjectIds = <String, String?>{};
  final groupStrategies = <String, Map<String, MergeStrategy>>{};
  final selectedRemoteGroupIds = <String, Map<String, String?>>{};
  final cameraStrategies = <String, Map<String, Map<String, MergeStrategy>>>{};
  final selectedRemoteCameraIds = <String, Map<String, Map<String, String?>>>{};

  RemoteProjectOption? findProjectById(
    ProjectConflictPreview project,
    String? projectId,
  ) {
    if (projectId == null) return null;
    for (final option in project.remoteOptions) {
      if (option.id == projectId) return option;
    }
    return null;
  }

  RemoteGroupOption? findGroupById(
    RemoteProjectOption? remoteProject,
    String? groupId,
  ) {
    if (remoteProject == null || groupId == null) return null;
    for (final group in remoteProject.groups) {
      if (group.id == groupId) return group;
    }
    return null;
  }

  String? findMatchingRemoteProjectId(ProjectConflictPreview project) {
    for (final remote in project.remoteOptions) {
      if (normalizeComparableText(remote.name) ==
          normalizeComparableText(project.localName)) {
        return remote.id;
      }
    }
    return null;
  }

  bool canCreateNewRemoteProject(ProjectConflictPreview project) {
    return findMatchingRemoteProjectId(project) == null;
  }

  MergeStrategy selectedProjectStrategy(ProjectConflictPreview project) {
    return projectStrategies[project.localProjectId] ?? MergeStrategy.merge;
  }

  bool allowCreateNewProjectTarget(ProjectConflictPreview project) {
    return selectedProjectStrategy(project) == MergeStrategy.merge &&
        canCreateNewRemoteProject(project);
  }

  String? fallbackRemoteProjectIdForOverwrite(ProjectConflictPreview project) {
    final byName = findMatchingRemoteProjectId(project);
    if (byName != null) return byName;
    if (project.remoteOptions.isNotEmpty) return project.remoteOptions.first.id;
    return null;
  }

  String? effectiveSelectedRemoteProjectId(ProjectConflictPreview project) {
    final selected = selectedRemoteProjectIds[project.localProjectId];
    if (selected != null &&
        project.remoteOptions.any((remote) => remote.id == selected)) {
      return selected;
    }
    if (selectedProjectStrategy(project) == MergeStrategy.overwrite) {
      return fallbackRemoteProjectIdForOverwrite(project);
    }
    if (!canCreateNewRemoteProject(project)) {
      return findMatchingRemoteProjectId(project);
    }
    return selected;
  }

  String? findMatchingRemoteGroupId(
    ProjectConflictPreview project,
    GroupConflictPreview group,
  ) {
    final remoteProject = findProjectById(
      project,
      effectiveSelectedRemoteProjectId(project),
    );
    if (remoteProject == null) return null;
    for (final remoteGroup in remoteProject.groups) {
      if (normalizeComparableText(remoteGroup.name) ==
          normalizeComparableText(group.localName)) {
        return remoteGroup.id;
      }
    }
    return null;
  }

  bool canCreateNewRemoteGroup(
    ProjectConflictPreview project,
    GroupConflictPreview group,
  ) {
    return findMatchingRemoteGroupId(project, group) == null;
  }

  MergeStrategy selectedGroupStrategy(
    ProjectConflictPreview project,
    GroupConflictPreview group,
  ) {
    return groupStrategies[project.localProjectId]?[group.localGroupId] ??
        MergeStrategy.merge;
  }

  bool allowCreateNewGroupTarget(
    ProjectConflictPreview project,
    GroupConflictPreview group,
  ) {
    return selectedGroupStrategy(project, group) == MergeStrategy.merge &&
        canCreateNewRemoteGroup(project, group);
  }

  bool lockProjectTargetSelector(ProjectConflictPreview project) {
    return selectedProjectStrategy(project) == MergeStrategy.overwrite &&
        findMatchingRemoteProjectId(project) != null;
  }

  bool lockGroupTargetSelector(
    ProjectConflictPreview project,
    GroupConflictPreview group,
  ) {
    return selectedGroupStrategy(project, group) == MergeStrategy.overwrite &&
        findMatchingRemoteGroupId(project, group) != null;
  }

  String? fallbackRemoteGroupIdForOverwrite(
    ProjectConflictPreview project,
    GroupConflictPreview group,
  ) {
    final byName = findMatchingRemoteGroupId(project, group);
    if (byName != null) return byName;
    final remoteProject = findProjectById(
      project,
      effectiveSelectedRemoteProjectId(project),
    );
    if (remoteProject != null && remoteProject.groups.isNotEmpty) {
      return remoteProject.groups.first.id;
    }
    return null;
  }

  String? effectiveSelectedRemoteGroupId(
    ProjectConflictPreview project,
    GroupConflictPreview group,
  ) {
    final selected =
        selectedRemoteGroupIds[project.localProjectId]?[group.localGroupId];
    final remoteProject = findProjectById(
      project,
      effectiveSelectedRemoteProjectId(project),
    );
    if (remoteProject == null) return selected;
    if (selected != null &&
        remoteProject.groups.any((remoteGroup) => remoteGroup.id == selected)) {
      return selected;
    }
    if (selectedGroupStrategy(project, group) == MergeStrategy.overwrite) {
      return fallbackRemoteGroupIdForOverwrite(project, group);
    }
    final byName = findMatchingRemoteGroupId(project, group);
    if (byName != null) return byName;
    return selected;
  }

  RemoteCameraOption? findMatchingRemoteCamera(
    ProjectConflictPreview project,
    GroupConflictPreview group,
    CameraConflictPreview camera,
  ) {
    final remoteProject = findProjectById(
      project,
      effectiveSelectedRemoteProjectId(project),
    );
    final remoteGroup = findGroupById(
      remoteProject,
      effectiveSelectedRemoteGroupId(project, group),
    );
    if (remoteGroup == null) return null;
    for (final remoteCamera in remoteGroup.cameras) {
      if (normalizeComparableText(remoteCamera.name) ==
          normalizeComparableText(camera.localName)) {
        return remoteCamera;
      }
    }
    return null;
  }

  String? findMatchingRemoteCameraId(
    ProjectConflictPreview project,
    GroupConflictPreview group,
    CameraConflictPreview camera,
  ) {
    return findMatchingRemoteCamera(project, group, camera)?.id;
  }

  String? selectedTargetCameraName(
    ProjectConflictPreview project,
    GroupConflictPreview group,
    CameraConflictPreview camera,
  ) {
    return findMatchingRemoteCamera(project, group, camera)?.name;
  }

  String strategyLabel(MergeStrategy strategy) {
    switch (strategy) {
      case MergeStrategy.merge:
        return 'merge';
      case MergeStrategy.overwrite:
        return 'overwrite';
      case MergeStrategy.skip:
        return 'skip';
    }
  }

  String selectedTargetProjectName(ProjectConflictPreview project) {
    final remoteProject = findProjectById(
      project,
      effectiveSelectedRemoteProjectId(project),
    );
    return remoteProject?.name ?? l10n.authMigrationCreateNewTarget;
  }

  String selectedTargetGroupName(
    ProjectConflictPreview project,
    GroupConflictPreview group,
  ) {
    final remoteProject = findProjectById(
      project,
      effectiveSelectedRemoteProjectId(project),
    );
    final remoteGroup = findGroupById(
      remoteProject,
      effectiveSelectedRemoteGroupId(project, group),
    );
    return remoteGroup?.name ?? l10n.authMigrationCreateNewTarget;
  }

  void logCurrentSelections(String stage) {
    debugPrint('[MIGRATION-SCREEN][$stage] selection snapshot start');
    for (final project in preview.projectConflicts) {
      final projectStrategy = selectedProjectStrategy(project);
      final targetProjectId = effectiveSelectedRemoteProjectId(project);
      debugPrint(
        '[MIGRATION-SCREEN][$stage][PROJECT] source="${project.localName}" '
        'strategy=${strategyLabel(projectStrategy)} '
        'targetId=${targetProjectId ?? 'create-new'} '
        'targetName="${selectedTargetProjectName(project)}"',
      );
      for (final group in project.groupConflicts) {
        final groupStrategy = selectedGroupStrategy(project, group);
        final targetGroupId = effectiveSelectedRemoteGroupId(project, group);
        debugPrint(
          '[MIGRATION-SCREEN][$stage][GROUP] source="${group.localName}" '
          'strategy=${strategyLabel(groupStrategy)} '
          'targetId=${targetGroupId ?? 'create-new'} '
          'targetName="${selectedTargetGroupName(project, group)}"',
        );
        for (final camera in group.cameraConflicts) {
          final cameraStrategy =
              cameraStrategies[project.localProjectId]?[group
                  .localGroupId]?[camera.localCameraId] ??
              MergeStrategy.merge;
          final matchedCameraId = findMatchingRemoteCameraId(
            project,
            group,
            camera,
          );
          debugPrint(
            '[MIGRATION-SCREEN][$stage][CAMERA] source="${camera.localName}" '
            'strategy=${strategyLabel(cameraStrategy)} '
            'matchedRemoteCameraId=${matchedCameraId ?? 'none'}',
          );
        }
      }
    }
    debugPrint('[MIGRATION-SCREEN][$stage] selection snapshot end');
  }

  void updateCameraDefaults({
    required ProjectConflictPreview project,
    required GroupConflictPreview group,
    required String? remoteGroupId,
  }) {
    final projectId = project.localProjectId;
    final remoteProject = findProjectById(
      project,
      effectiveSelectedRemoteProjectId(project),
    );
    final remoteGroup = findGroupById(remoteProject, remoteGroupId);
    final cameraStrategyMap = cameraStrategies[projectId]![group.localGroupId]!;
    final selectedCameraMap =
        selectedRemoteCameraIds[projectId]![group.localGroupId]!;

    for (final camera in group.cameraConflicts) {
      final match = remoteGroup?.cameras.where(
        (option) =>
            normalizeComparableText(option.name) ==
            normalizeComparableText(camera.localName),
      );
      final matchedCameraId = (match != null && match.isNotEmpty)
          ? match.first.id
          : null;
      selectedCameraMap[camera.localCameraId] = matchedCameraId;

      final currentStrategy = cameraStrategyMap[camera.localCameraId];
      if (matchedCameraId != null) {
        if (currentStrategy == null || currentStrategy == MergeStrategy.merge) {
          cameraStrategyMap[camera.localCameraId] = MergeStrategy.overwrite;
        }
      } else {
        if (currentStrategy == null ||
            currentStrategy == MergeStrategy.overwrite) {
          cameraStrategyMap[camera.localCameraId] = MergeStrategy.merge;
        }
      }
    }
  }

  void updateGroupAndCameraDefaults(
    ProjectConflictPreview project,
    String? projectId,
  ) {
    final localProjectId = project.localProjectId;
    final remoteProject = findProjectById(project, projectId);
    for (final group in project.groupConflicts) {
      groupStrategies[localProjectId]!.putIfAbsent(
        group.localGroupId,
        () => MergeStrategy.merge,
      );
      final groupMatch = remoteProject?.groups.where(
        (remoteGroup) =>
            normalizeComparableText(remoteGroup.name) ==
            normalizeComparableText(group.localName),
      );
      final matchedGroupId = (groupMatch != null && groupMatch.isNotEmpty)
          ? groupMatch.first.id
          : null;
      selectedRemoteGroupIds[localProjectId]![group.localGroupId] =
          matchedGroupId;
      cameraStrategies[localProjectId]!.putIfAbsent(
        group.localGroupId,
        () => {},
      );
      selectedRemoteCameraIds[localProjectId]!.putIfAbsent(
        group.localGroupId,
        () => {},
      );
      updateCameraDefaults(
        project: project,
        group: group,
        remoteGroupId: matchedGroupId,
      );
    }
  }

  for (final project in preview.projectConflicts) {
    final projectId = project.localProjectId;
    projectStrategies[projectId] = MergeStrategy.merge;
    selectedRemoteProjectIds[projectId] = findMatchingRemoteProjectId(project);
    groupStrategies[projectId] = {};
    selectedRemoteGroupIds[projectId] = {};
    cameraStrategies[projectId] = {};
    selectedRemoteCameraIds[projectId] = {};
    updateGroupAndCameraDefaults(project, selectedRemoteProjectIds[projectId]);
  }

  var step = 0;
  var validationIssues = List<String>.from(initialValidationIssues);
  var validationIssueIndex = 0;

  return Navigator.of(context).push<GuestMigrationPlan>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final isSpanish = Localizations.localeOf(
              dialogContext,
            ).languageCode.toLowerCase().startsWith('es');

            void clearValidationIssues() {
              validationIssues = [];
              validationIssueIndex = 0;
            }

            int currentValidationIssueIndex() {
              if (validationIssues.isEmpty) {
                return 0;
              }
              if (validationIssueIndex < 0) {
                return 0;
              }
              if (validationIssueIndex >= validationIssues.length) {
                return validationIssues.length - 1;
              }
              return validationIssueIndex;
            }

            void moveValidationIssue(int delta) {
              if (validationIssues.isEmpty) return;
              final nextIndex = currentValidationIssueIndex() + delta;
              if (nextIndex < 0 || nextIndex >= validationIssues.length) return;
              validationIssueIndex = nextIndex;
            }

            Map<String, String> describeValidationIssue(String rawIssue) {
              final multipleOverwritePattern = RegExp(
                r'^Group "(.+)" in project "(.+)" has multiple overwrite sources: (.+)\.$',
              );
              final mixedOverwritePattern = RegExp(
                r'^Group "(.+)" in project "(.+)" cannot mix overwrite \((.+)\) with additional sources \((.+)\)\.$',
              );
              final duplicateCameraPattern = RegExp(
                r'^Camera "(.+)" appears in multiple sources for group "(.+)" in project "(.+)": (.+)\.$',
              );

              final multipleOverwriteMatch = multipleOverwritePattern
                  .firstMatch(rawIssue);
              if (multipleOverwriteMatch != null) {
                final groupName = multipleOverwriteMatch.group(1) ?? '';
                final projectName = multipleOverwriteMatch.group(2) ?? '';
                return {
                  'title': isSpanish
                      ? 'Hay varias fuentes en sobrescritura'
                      : 'Multiple overwrite sources selected',
                  'message': isSpanish
                      ? 'El grupo "$groupName" del proyecto "$projectName" tiene más de una fuente en "Sobrescribir". Deja solo una fuente en sobrescritura o cambia las demás a combinar/omitir.'
                      : 'Group "$groupName" in project "$projectName" has multiple sources set to "Overwrite". Keep only one overwrite source, or switch the others to merge/skip.',
                };
              }

              final mixedOverwriteMatch = mixedOverwritePattern.firstMatch(
                rawIssue,
              );
              if (mixedOverwriteMatch != null) {
                final groupName = mixedOverwriteMatch.group(1) ?? '';
                final projectName = mixedOverwriteMatch.group(2) ?? '';
                return {
                  'title': isSpanish
                      ? 'Sobrescribir no se puede mezclar'
                      : 'Overwrite cannot be mixed',
                  'message': isSpanish
                      ? 'El grupo "$groupName" del proyecto "$projectName" mezcla una fuente en sobrescritura con fuentes adicionales. Elige una sola fuente para sobrescribir o cambia todas a combinar.'
                      : 'Group "$groupName" in project "$projectName" mixes overwrite with additional sources. Pick a single overwrite source, or switch all sources to merge.',
                };
              }

              final duplicateCameraMatch = duplicateCameraPattern.firstMatch(
                rawIssue,
              );
              if (duplicateCameraMatch != null) {
                final cameraName = duplicateCameraMatch.group(1) ?? '';
                final groupName = duplicateCameraMatch.group(2) ?? '';
                final projectName = duplicateCameraMatch.group(3) ?? '';
                return {
                  'title': isSpanish
                      ? 'Cámara duplicada en el destino'
                      : 'Duplicate camera in target',
                  'message': isSpanish
                      ? 'La cámara "$cameraName" aparece en varias fuentes que apuntan al grupo "$groupName" del proyecto "$projectName". Cambia la forma de migrar o renombra una de las cámaras antes de continuar.'
                      : 'Camera "$cameraName" appears in multiple sources that map to group "$groupName" in project "$projectName". Change how migration is handled or rename one of the cameras before continuing.',
                };
              }

              return {
                'title': isSpanish
                    ? 'Revisa la configuración de migración'
                    : 'Review the migration selections',
                'message': rawIssue,
              };
            }

            Widget buildStrategyDropdown({
              required MergeStrategy value,
              required ValueChanged<MergeStrategy?> onChanged,
            }) {
              return DropdownButtonFormField<MergeStrategy>(
                value: value,
                items: [
                  DropdownMenuItem(
                    value: MergeStrategy.merge,
                    child: Text(l10n.authMigrationStrategyMerge),
                  ),
                  DropdownMenuItem(
                    value: MergeStrategy.overwrite,
                    child: Text(l10n.authMigrationStrategyOverwrite),
                  ),
                  DropdownMenuItem(
                    value: MergeStrategy.skip,
                    child: Text(l10n.authMigrationStrategySkip),
                  ),
                ],
                onChanged: onChanged,
              );
            }

            Widget buildCameraStrategyDropdown({
              required bool hasRemoteMatch,
              required MergeStrategy value,
              required ValueChanged<MergeStrategy?> onChanged,
            }) {
              return DropdownButtonFormField<MergeStrategy>(
                value: value,
                items: [
                  if (!hasRemoteMatch)
                    DropdownMenuItem(
                      value: MergeStrategy.merge,
                      child: Text(l10n.authMigrationStrategyMigrate),
                    ),
                  if (hasRemoteMatch)
                    DropdownMenuItem(
                      value: MergeStrategy.overwrite,
                      child: Text(l10n.authMigrationStrategyOverwrite),
                    ),
                  DropdownMenuItem(
                    value: MergeStrategy.skip,
                    child: Text(l10n.authMigrationStrategySkip),
                  ),
                ],
                onChanged: onChanged,
              );
            }

            Widget buildProjectStep() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.authMigrationWizardStepProjects,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  for (final project in preview.projectConflicts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                project.localName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (project.localDescription.isNotEmpty)
                                Text(project.localDescription),
                              const SizedBox(height: 8),
                              buildStrategyDropdown(
                                value:
                                    projectStrategies[project.localProjectId]!,
                                onChanged: (value) {
                                  setDialogState(() {
                                    projectStrategies[project.localProjectId] =
                                        value ?? MergeStrategy.merge;
                                    clearValidationIssues();
                                    if (projectStrategies[project
                                            .localProjectId] ==
                                        MergeStrategy.overwrite) {
                                      selectedRemoteProjectIds[project
                                              .localProjectId] =
                                          fallbackRemoteProjectIdForOverwrite(
                                            project,
                                          );
                                    }
                                    logCurrentSelections(
                                      'project-strategy-changed',
                                    );
                                  });
                                },
                              ),
                              if (project.remoteOptions.isNotEmpty &&
                                  projectStrategies[project.localProjectId] !=
                                      MergeStrategy.skip) ...[
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String?>(
                                  value: effectiveSelectedRemoteProjectId(
                                    project,
                                  ),
                                  decoration: InputDecoration(
                                    labelText:
                                        l10n.authMigrationTargetProjectLabel,
                                  ),
                                  items: [
                                    if (allowCreateNewProjectTarget(project))
                                      DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text(
                                          l10n.authMigrationCreateNewTarget,
                                        ),
                                      ),
                                    ...project.remoteOptions.map(
                                      (option) => DropdownMenuItem<String?>(
                                        value: option.id,
                                        child: Text(option.name),
                                      ),
                                    ),
                                  ],
                                  onChanged: lockProjectTargetSelector(project)
                                      ? null
                                      : (value) {
                                          setDialogState(() {
                                            final strategy =
                                                selectedProjectStrategy(
                                                  project,
                                                );
                                            clearValidationIssues();
                                            selectedRemoteProjectIds[project
                                                    .localProjectId] =
                                                value ??
                                                (strategy ==
                                                        MergeStrategy.overwrite
                                                    ? fallbackRemoteProjectIdForOverwrite(
                                                        project,
                                                      )
                                                    : (allowCreateNewProjectTarget(
                                                            project,
                                                          )
                                                          ? null
                                                          : findMatchingRemoteProjectId(
                                                              project,
                                                            )));
                                            updateGroupAndCameraDefaults(
                                              project,
                                              selectedRemoteProjectIds[project
                                                  .localProjectId],
                                            );
                                            logCurrentSelections(
                                              'project-target-changed',
                                            );
                                          });
                                        },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }

            Widget buildGroupStep() {
              final mergeProjects = preview.projectConflicts.where(
                (project) =>
                    projectStrategies[project.localProjectId] ==
                        MergeStrategy.merge &&
                    effectiveSelectedRemoteProjectId(project) != null,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.authMigrationWizardStepGroups,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (mergeProjects.isEmpty)
                    Text(l10n.authMigrationNoRemoteItems),
                  for (final project in mergeProjects)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                project.localName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final group in project.groupConflicts)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(group.localName),
                                      buildStrategyDropdown(
                                        value:
                                            groupStrategies[project
                                                .localProjectId]![group
                                                .localGroupId]!,
                                        onChanged: (value) {
                                          setDialogState(() {
                                            groupStrategies[project
                                                    .localProjectId]![group
                                                    .localGroupId] =
                                                value ?? MergeStrategy.merge;
                                            clearValidationIssues();
                                            if (groupStrategies[project
                                                    .localProjectId]![group
                                                    .localGroupId] ==
                                                MergeStrategy.overwrite) {
                                              selectedRemoteGroupIds[project
                                                      .localProjectId]![group
                                                      .localGroupId] =
                                                  fallbackRemoteGroupIdForOverwrite(
                                                    project,
                                                    group,
                                                  );
                                            }
                                            logCurrentSelections(
                                              'group-strategy-changed',
                                            );
                                          });
                                        },
                                      ),
                                      if (groupStrategies[project
                                              .localProjectId]![group
                                              .localGroupId] !=
                                          MergeStrategy.skip) ...[
                                        const SizedBox(height: 6),
                                        Builder(
                                          builder: (_) {
                                            final remoteProject = findProjectById(
                                              project,
                                              effectiveSelectedRemoteProjectId(
                                                project,
                                              ),
                                            );
                                            final remoteGroups =
                                                remoteProject?.groups ??
                                                const <RemoteGroupOption>[];
                                            return DropdownButtonFormField<
                                              String?
                                            >(
                                              value:
                                                  effectiveSelectedRemoteGroupId(
                                                    project,
                                                    group,
                                                  ),
                                              decoration: InputDecoration(
                                                labelText: l10n
                                                    .authMigrationTargetGroupLabel,
                                              ),
                                              items: [
                                                if (allowCreateNewGroupTarget(
                                                  project,
                                                  group,
                                                ))
                                                  DropdownMenuItem<String?>(
                                                    value: null,
                                                    child: Text(
                                                      l10n.authMigrationCreateNewTarget,
                                                    ),
                                                  ),
                                                ...remoteGroups.map(
                                                  (remoteGroup) =>
                                                      DropdownMenuItem<String?>(
                                                        value: remoteGroup.id,
                                                        child: Text(
                                                          remoteGroup.name,
                                                        ),
                                                      ),
                                                ),
                                              ],
                                              onChanged:
                                                  lockGroupTargetSelector(
                                                    project,
                                                    group,
                                                  )
                                                  ? null
                                                  : (value) {
                                                      setDialogState(() {
                                                        clearValidationIssues();
                                                        selectedRemoteGroupIds[project
                                                                .localProjectId]![group
                                                                .localGroupId] =
                                                            value ??
                                                            (selectedGroupStrategy(
                                                                      project,
                                                                      group,
                                                                    ) ==
                                                                    MergeStrategy
                                                                        .overwrite
                                                                ? fallbackRemoteGroupIdForOverwrite(
                                                                    project,
                                                                    group,
                                                                  )
                                                                : (allowCreateNewGroupTarget(
                                                                        project,
                                                                        group,
                                                                      )
                                                                      ? null
                                                                      : findMatchingRemoteGroupId(
                                                                          project,
                                                                          group,
                                                                        )));
                                                        updateCameraDefaults(
                                                          project: project,
                                                          group: group,
                                                          remoteGroupId:
                                                              selectedRemoteGroupIds[project
                                                                  .localProjectId]![group
                                                                  .localGroupId],
                                                        );
                                                        logCurrentSelections(
                                                          'group-target-changed',
                                                        );
                                                      });
                                                    },
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }

            Widget buildCameraStep() {
              final mergeProjects = preview.projectConflicts.where(
                (project) =>
                    projectStrategies[project.localProjectId] ==
                        MergeStrategy.merge &&
                    effectiveSelectedRemoteProjectId(project) != null,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.authMigrationWizardStepCameras,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (mergeProjects.isEmpty)
                    Text(l10n.authMigrationNoRemoteItems),
                  for (final project in mergeProjects)
                    Builder(
                      builder: (_) {
                        final mergeGroups = project.groupConflicts
                            .where(
                              (group) =>
                                  groupStrategies[project.localProjectId]![group
                                          .localGroupId] ==
                                      MergeStrategy.merge &&
                                  effectiveSelectedRemoteGroupId(
                                        project,
                                        group,
                                      ) !=
                                      null,
                            )
                            .toList();
                        if (mergeGroups.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: MigrationEndpointCard(
                                          icon: Icons.folder_outlined,
                                          label: isSpanish
                                              ? 'Origen'
                                              : 'Source',
                                          value: project.localName,
                                          alignEnd: false,
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Icon(
                                          Icons.east_rounded,
                                          size: 18,
                                        ),
                                      ),
                                      Expanded(
                                        child: MigrationEndpointCard(
                                          icon: Icons.cloud_outlined,
                                          label: isSpanish
                                              ? 'Destino'
                                              : 'Target',
                                          value: selectedTargetProjectName(
                                            project,
                                          ),
                                          alignEnd: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  for (final group in mergeGroups)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.blueGrey.shade50
                                              .withValues(alpha: 0.35),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.blueGrey.shade100,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child:
                                                        MigrationEndpointCard(
                                                          icon: Icons
                                                              .group_outlined,
                                                          label: isSpanish
                                                              ? 'Origen'
                                                              : 'Source',
                                                          value:
                                                              group.localName,
                                                          alignEnd: false,
                                                        ),
                                                  ),
                                                  const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                        ),
                                                    child: Icon(
                                                      Icons.east_rounded,
                                                      size: 16,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: MigrationEndpointCard(
                                                      icon:
                                                          Icons.groups_outlined,
                                                      label: isSpanish
                                                          ? 'Destino'
                                                          : 'Target',
                                                      value:
                                                          selectedTargetGroupName(
                                                            project,
                                                            group,
                                                          ),
                                                      alignEnd: true,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              for (final camera
                                                  in group.cameraConflicts)
                                                Builder(
                                                  builder: (_) {
                                                    final hasRemoteMatch =
                                                        findMatchingRemoteCameraId(
                                                          project,
                                                          group,
                                                          camera,
                                                        ) !=
                                                        null;
                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            bottom: 8,
                                                          ),
                                                      child: DecoratedBox(
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                          border: Border.all(
                                                            color: Colors
                                                                .grey
                                                                .shade300,
                                                          ),
                                                        ),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                10,
                                                              ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  Icon(
                                                                    Icons
                                                                        .videocam_outlined,
                                                                    size: 16,
                                                                    color: Colors
                                                                        .blueGrey
                                                                        .shade700,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 6,
                                                                  ),
                                                                  Expanded(
                                                                    child: Text(
                                                                      camera
                                                                          .localName,
                                                                      style: const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const Icon(
                                                                    Icons
                                                                        .arrow_forward,
                                                                    size: 14,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 6,
                                                                  ),
                                                                  Flexible(
                                                                    child: Text(
                                                                      hasRemoteMatch
                                                                          ? selectedTargetCameraName(
                                                                                  project,
                                                                                  group,
                                                                                  camera,
                                                                                ) ??
                                                                                camera.localName
                                                                          : l10n.authMigrationCreateNewTarget,
                                                                      textAlign:
                                                                          TextAlign
                                                                              .end,
                                                                      style: TextStyle(
                                                                        color: Colors
                                                                            .blueGrey
                                                                            .shade700,
                                                                        fontSize:
                                                                            12,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                height: 8,
                                                              ),
                                                              buildCameraStrategyDropdown(
                                                                hasRemoteMatch:
                                                                    hasRemoteMatch,
                                                                value:
                                                                    cameraStrategies[project
                                                                        .localProjectId]![group
                                                                        .localGroupId]![camera
                                                                        .localCameraId]!,
                                                                onChanged: (value) {
                                                                  setDialogState(() {
                                                                    clearValidationIssues();
                                                                    cameraStrategies[project
                                                                            .localProjectId]![group
                                                                            .localGroupId]![camera
                                                                            .localCameraId] =
                                                                        value ??
                                                                        (hasRemoteMatch
                                                                            ? MergeStrategy.overwrite
                                                                            : MergeStrategy.merge);
                                                                    logCurrentSelections(
                                                                      'camera-strategy-changed',
                                                                    );
                                                                  });
                                                                },
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            }

            GuestMigrationPlan buildPlan() {
              final projectResolutions = <String, ProjectMergeResolution>{};
              for (final project in preview.projectConflicts) {
                final selectedRemoteProjectId =
                    effectiveSelectedRemoteProjectId(project);
                final groupResolutions = <String, GroupMergeResolution>{};
                for (final group in project.groupConflicts) {
                  final cameraResolutions = <String, CameraMergeResolution>{};
                  for (final camera in group.cameraConflicts) {
                    cameraResolutions[camera
                        .localCameraId] = CameraMergeResolution(
                      localCameraId: camera.localCameraId,
                      strategy:
                          cameraStrategies[project.localProjectId]![group
                              .localGroupId]![camera.localCameraId] ??
                          MergeStrategy.merge,
                      targetRemoteCameraId:
                          selectedRemoteCameraIds[project.localProjectId]![group
                              .localGroupId]![camera.localCameraId],
                    );
                  }
                  groupResolutions[group.localGroupId] = GroupMergeResolution(
                    localGroupId: group.localGroupId,
                    strategy:
                        groupStrategies[project.localProjectId]![group
                            .localGroupId] ??
                        MergeStrategy.merge,
                    targetRemoteGroupId: effectiveSelectedRemoteGroupId(
                      project,
                      group,
                    ),
                    cameraResolutions: cameraResolutions,
                  );
                }
                projectResolutions[project.localProjectId] =
                    ProjectMergeResolution(
                      localProjectId: project.localProjectId,
                      strategy:
                          projectStrategies[project.localProjectId] ??
                          MergeStrategy.merge,
                      targetRemoteProjectId: selectedRemoteProjectId,
                      groupResolutions: groupResolutions,
                    );
              }
              return GuestMigrationPlan(projectResolutions: projectResolutions);
            }

            Widget content;
            final hasProjectMergeTargets = preview.projectConflicts.any(
              (project) =>
                  selectedProjectStrategy(project) == MergeStrategy.merge &&
                  effectiveSelectedRemoteProjectId(project) != null,
            );
            final hasCameraMergeTargets = preview.projectConflicts.any((
              project,
            ) {
              if (selectedProjectStrategy(project) != MergeStrategy.merge ||
                  effectiveSelectedRemoteProjectId(project) == null) {
                return false;
              }
              for (final group in project.groupConflicts) {
                if (selectedGroupStrategy(project, group) ==
                        MergeStrategy.merge &&
                    effectiveSelectedRemoteGroupId(project, group) != null &&
                    group.cameraConflicts.isNotEmpty) {
                  return true;
                }
              }
              return false;
            });
            final lastStep = !hasProjectMergeTargets
                ? 0
                : hasCameraMergeTargets
                ? 2
                : 1;
            final currentStep = step > lastStep ? lastStep : step;
            if (currentStep == 0) {
              content = buildProjectStep();
            } else if (currentStep == 1) {
              content = buildGroupStep();
            } else {
              content = buildCameraStep();
            }

            Widget buildValidationIssuesCard() {
              final issueCount = validationIssues.length;
              final issueIndex = currentValidationIssueIndex();
              final issueSummary = describeValidationIssue(
                validationIssues[issueIndex],
              );
              final canMovePrev = issueIndex > 0;
              final canMoveNext = issueIndex < issueCount - 1;
              return MigrationIssueCard(
                title: l10n.authMigrationValidationIssuesTitle,
                issueTitle: issueSummary['title'] ?? '',
                issueMessage: issueSummary['message'] ?? '',
                issueCount: issueCount,
                issueIndex: issueIndex,
                canMovePrev: canMovePrev,
                canMoveNext: canMoveNext,
                onPrev: () => setDialogState(() {
                  moveValidationIssue(-1);
                }),
                onNext: () => setDialogState(() {
                  moveValidationIssue(1);
                }),
                onHorizontalDragEnd: issueCount > 1
                    ? (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        if (velocity.abs() < 100) return;
                        setDialogState(() {
                          if (velocity < 0) {
                            moveValidationIssue(1);
                          } else {
                            moveValidationIssue(-1);
                          }
                        });
                      }
                    : null,
              );
            }

            void submitPlan() {
              logCurrentSelections('submit-attempt');
              final plan = buildPlan();
              final issues = validateGuestMigrationPlan(
                preview: preview,
                plan: plan,
              );
              if (issues.isNotEmpty) {
                for (final issue in issues) {
                  debugPrint('[MIGRATION-SCREEN][BLOCKER] $issue');
                }
                setDialogState(() {
                  validationIssues = issues;
                  validationIssueIndex = 0;
                });
                return;
              }
              debugPrint('[MIGRATION-SCREEN] plan validated successfully');
              Navigator.of(dialogContext).pop(plan);
            }

            final stepTitle = switch (currentStep) {
              0 => l10n.authMigrationWizardStepProjects,
              1 => l10n.authMigrationWizardStepGroups,
              _ => l10n.authMigrationWizardStepCameras,
            };
            final stepCount = lastStep + 1;
            final currentStepNumber = currentStep + 1;
            final progress = stepCount == 0
                ? 0.0
                : currentStepNumber / stepCount;

            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                title: Text(l10n.authMigrationConflictTitle),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(value: progress),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                stepTitle,
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              '$currentStepNumber/$stepCount',
                              style: Theme.of(
                                dialogContext,
                              ).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              body: SafeArea(
                top: false,
                child: ListView(
                  key: const Key('migration_fullscreen_scroll'),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  children: [
                    Text(
                      l10n.authMigrationConflictDescription,
                      style: Theme.of(dialogContext).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    if (validationIssues.isNotEmpty) ...[
                      buildValidationIssuesCard(),
                      const SizedBox(height: 12),
                    ],
                    content,
                  ],
                ),
              ),
              bottomNavigationBar: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  decoration: BoxDecoration(
                    color: Theme.of(dialogContext).scaffoldBackgroundColor,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(l10n.authMigrationConflictSkip),
                      ),
                      if (currentStep > 0)
                        OutlinedButton(
                          onPressed: () => setDialogState(() {
                            step = currentStep - 1;
                            debugPrint('[MIGRATION-SCREEN] step back -> $step');
                            logCurrentSelections('step-back');
                          }),
                          child: Text(l10n.authMigrationStepBack),
                        ),
                      if (currentStep < lastStep)
                        FilledButton(
                          onPressed: () => setDialogState(() {
                            step = currentStep + 1;
                            debugPrint('[MIGRATION-SCREEN] step next -> $step');
                            logCurrentSelections('step-next');
                          }),
                          child: Text(l10n.authMigrationStepNext),
                        ),
                      if (currentStep == lastStep)
                        FilledButton(
                          onPressed: submitPlan,
                          child: Text(l10n.authMigrationConfirm),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
