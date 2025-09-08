import 'dart:collection';
import 'package:multicamera_tracking/shared/domain/services/surveillance_count_cache.dart';
import 'package:multicamera_tracking/shared/domain/services/event_bus.dart';
import 'package:multicamera_tracking/shared/domain/events/surveillance_event.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/project.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';

class SurveillanceCountCacheImpl implements SurveillanceCountCache {
  final SurveillanceEventBus bus;

  // counts tracked independently of UI
  final Set<String> _projectIds = <String>{};
  final Map<String, Set<String>> _groupsByProject = HashMap();
  final Map<String, Map<String, Set<String>>> _camsByProjGroup = HashMap();

  SurveillanceCountCacheImpl({required this.bus}) {
    bus.stream.listen(_onEvent);
  }

  // ---- seeders ----
  @override
  void seedProjects(List<Project> projects) {
    _projectIds
      ..clear()
      ..addAll(projects.map((e) => e.id));
  }

  @override
  void seedGroups(String projectId, List<Group> groups) {
    _groupsByProject[projectId] = groups.map((g) => g.id).toSet();
  }

  @override
  void seedCameras(String projectId, String groupId, List<Camera> cameras) {
    _camsByProjGroup[projectId] ??= {};
    _camsByProjGroup[projectId]![groupId] = cameras.map((c) => c.id).toSet();
  }

  // ---- counters ----
  @override
  int? projectCount() =>
      _projectIds.isEmpty &&
          _groupsByProject.isEmpty &&
          _camsByProjGroup.isEmpty
      ? null // nothing seeded yet
      : _projectIds.length;

  @override
  int? groupCount(String projectId) => _groupsByProject.containsKey(projectId)
      ? _groupsByProject[projectId]!.length
      : null;

  @override
  int? cameraCount(String projectId, String groupId) =>
      _camsByProjGroup[projectId] != null &&
          _camsByProjGroup[projectId]!.containsKey(groupId)
      ? _camsByProjGroup[projectId]![groupId]!.length
      : null;

  // ---- live updates from bus ----
  void _onEvent(SurveillanceEvent e) {
    if (e is ProjectUpserted) {
      _projectIds.add(e.project.id);
    } else if (e is ProjectDeleted) {
      _projectIds.remove(e.projectId);
      _groupsByProject.remove(e.projectId);
      _camsByProjGroup.remove(e.projectId);
    } else if (e is GroupUpserted) {
      final p = e.group.projectId;
      _groupsByProject[p] ??= <String>{};
      _groupsByProject[p]!.add(e.group.id);
    } else if (e is GroupDeleted) {
      final p = e.projectId, g = e.groupId;
      _groupsByProject[p]?.remove(g);
      _camsByProjGroup[p]?.remove(g);
    } else if (e is CameraUpserted) {
      final p = e.camera.projectId, g = e.camera.groupId;
      _camsByProjGroup[p] ??= {};
      _camsByProjGroup[p]![g] ??= <String>{};
      _camsByProjGroup[p]![g]!.add(e.camera.id);
    } else if (e is CameraDeleted) {
      final p = e.projectId, g = e.groupId;
      _camsByProjGroup[p]?[g]?.remove(e.cameraId);
    } else if (e is CamerasClearedForGroup) {
      final p = e.projectId, g = e.groupId;
      _camsByProjGroup[p] ??= {};
      _camsByProjGroup[p]![g] = <String>{};
    }
  }
}
