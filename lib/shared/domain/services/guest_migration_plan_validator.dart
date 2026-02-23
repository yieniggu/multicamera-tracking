import 'package:multicamera_tracking/shared/domain/entities/guest_migration.dart';
import 'package:multicamera_tracking/shared/utils/normalized_text.dart';

List<String> validateGuestMigrationPlan({
  required GuestMigrationPreview preview,
  required GuestMigrationPlan plan,
}) {
  final issues = <String>[];
  final bindingsByTargetGroup = <String, List<_GroupBinding>>{};

  for (final localProject in preview.projectConflicts) {
    final projectResolution = plan.resolutionForProject(
      localProject.localProjectId,
    );
    if (projectResolution.strategy == MergeStrategy.skip) continue;

    final targetProject = _resolveTargetProject(
      localProject,
      projectResolution,
    );
    if (targetProject == null) continue;

    for (final localGroup in localProject.groupConflicts) {
      final groupResolution = projectResolution.resolutionForGroup(
        localGroup.localGroupId,
      );
      if (groupResolution.strategy == MergeStrategy.skip) continue;

      final targetGroup = _resolveTargetGroup(
        localProject: localProject,
        localGroup: localGroup,
        targetProject: targetProject,
        groupResolution: groupResolution,
      );
      if (targetGroup == null) continue;

      final key = '${targetProject.id}/${targetGroup.id}';
      final sourceLabel = '${localProject.localName} / ${localGroup.localName}';
      final binding = _GroupBinding(
        sourceLabel: sourceLabel,
        targetProjectName: targetProject.name,
        targetGroupName: targetGroup.name,
        strategy: groupResolution.strategy,
        cameras: localGroup.cameraConflicts,
        groupResolution: groupResolution,
      );
      bindingsByTargetGroup
          .putIfAbsent(key, () => <_GroupBinding>[])
          .add(binding);
    }
  }

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
          .map((binding) => binding.sourceLabel)
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
          .map((binding) => binding.sourceLabel)
          .join(', ');
      final otherSources = nonOverwriteBindings
          .map((binding) => binding.sourceLabel)
          .join(', ');
      issues.add(
        'Group "$targetGroupName" in project "$targetProjectName" cannot mix overwrite ($overwriteSources) with additional sources ($otherSources).',
      );
    }

    if (overwriteBindings.isNotEmpty) {
      continue;
    }

    final sourcesByCameraName = <String, List<String>>{};
    final displayNameByNormalized = <String, String>{};
    for (final binding in bindings) {
      for (final camera in binding.cameras) {
        final cameraResolution = binding.groupResolution.resolutionForCamera(
          camera.localCameraId,
        );
        if (cameraResolution.strategy == MergeStrategy.skip) continue;
        final normalized = normalizeComparableText(camera.localName);
        if (normalized.isEmpty) continue;
        final sourceCamera = '${binding.sourceLabel} / ${camera.localName}';
        sourcesByCameraName
            .putIfAbsent(normalized, () => <String>[])
            .add(sourceCamera);
        displayNameByNormalized.putIfAbsent(normalized, () => camera.localName);
      }
    }

    for (final cameraEntry in sourcesByCameraName.entries) {
      final sources = cameraEntry.value;
      if (sources.length < 2) continue;
      issues.add(
        'Camera "${displayNameByNormalized[cameraEntry.key] ?? cameraEntry.key}" appears in multiple sources for group "$targetGroupName" in project "$targetProjectName": ${sources.join(', ')}.',
      );
    }
  }

  return issues;
}

RemoteProjectOption? _resolveTargetProject(
  ProjectConflictPreview localProject,
  ProjectMergeResolution resolution,
) {
  RemoteProjectOption? selected;
  if (resolution.targetRemoteProjectId != null) {
    for (final option in localProject.remoteOptions) {
      if (option.id == resolution.targetRemoteProjectId) {
        selected = option;
        break;
      }
    }
  }

  RemoteProjectOption? sameName;
  for (final option in localProject.remoteOptions) {
    if (normalizeComparableText(option.name) ==
        normalizeComparableText(localProject.localName)) {
      sameName = option;
      break;
    }
  }

  if (resolution.strategy == MergeStrategy.overwrite) {
    return sameName ??
        selected ??
        (localProject.remoteOptions.isNotEmpty
            ? localProject.remoteOptions.first
            : null);
  }

  // For merge flows we must honor explicit user selection first.
  // Falling back to same-name here can mask real collisions chosen in UI.
  return selected ?? sameName;
}

RemoteGroupOption? _resolveTargetGroup({
  required ProjectConflictPreview localProject,
  required GroupConflictPreview localGroup,
  required RemoteProjectOption targetProject,
  required GroupMergeResolution groupResolution,
}) {
  RemoteGroupOption? selected;
  if (groupResolution.targetRemoteGroupId != null) {
    for (final group in targetProject.groups) {
      if (group.id == groupResolution.targetRemoteGroupId) {
        selected = group;
        break;
      }
    }
  }

  RemoteGroupOption? sameName;
  for (final group in targetProject.groups) {
    if (normalizeComparableText(group.name) ==
        normalizeComparableText(localGroup.localName)) {
      sameName = group;
      break;
    }
  }

  if (groupResolution.strategy == MergeStrategy.overwrite) {
    return sameName ??
        selected ??
        (targetProject.groups.isNotEmpty ? targetProject.groups.first : null);
  }

  // For merge flows we must honor explicit user selection first.
  // Falling back to same-name here can mask real collisions chosen in UI.
  return selected ?? sameName;
}

class _GroupBinding {
  final String sourceLabel;
  final String targetProjectName;
  final String targetGroupName;
  final MergeStrategy strategy;
  final List<CameraConflictPreview> cameras;
  final GroupMergeResolution groupResolution;

  const _GroupBinding({
    required this.sourceLabel,
    required this.targetProjectName,
    required this.targetGroupName,
    required this.strategy,
    required this.cameras,
    required this.groupResolution,
  });
}
