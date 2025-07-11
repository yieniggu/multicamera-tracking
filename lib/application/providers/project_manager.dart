import 'package:flutter/material.dart';
import 'package:multicamera_tracking/domain/entities/project.dart';
import 'package:multicamera_tracking/domain/entities/group.dart';
import 'package:multicamera_tracking/domain/entities/camera.dart';
import 'package:multicamera_tracking/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/domain/repositories/camera_repository.dart';
import 'package:multicamera_tracking/config/di.dart';

class ProjectManager extends ChangeNotifier {
  final _projectRepo = getIt<ProjectRepository>();
  final _groupRepo = getIt<GroupRepository>();
  final _cameraRepo = getIt<CameraRepository>();

  bool _loaded = false;
  bool _isLoading = false;

  List<Project> _projects = [];
  List<Group> _groups = [];
  Map<String, List<Camera>> _camerasByGroup = {};

  List<Project> get projects => _projects;
  List<Group> get groups => _groups;
  Map<String, List<Camera>> get camerasByGroup => _camerasByGroup;

  bool get isLoading => _isLoading;

  Future<void> loadAll() async {
    if (_loaded) return;

    _isLoading = true;
    notifyListeners();

    _loaded = true;

    debugPrint("[PM] Using project repo: ${_projectRepo.runtimeType}");

    _projects = await _projectRepo.getAll();
    _groups = [];
    _camerasByGroup.clear();

    for (final project in _projects) {
      final projectGroups = await _groupRepo.getAllByProject(project.id);
      _groups.addAll(projectGroups);

      for (final group in projectGroups) {
        final groupCameras = await _cameraRepo.getAllByGroup(
          project.id,
          group.id,
        );
        final key = "${project.id}|${group.id}";
        _camerasByGroup[key] = groupCameras;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  void resetLoadedFlag() {
    _loaded = false;
  }

  Future<void> addOrUpdateProject(Project project) async {
    await _projectRepo.save(project);
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index >= 0) {
      _projects[index] = project;
    } else {
      _projects.add(project);
    }
    notifyListeners();
  }

  Future<void> deleteProject(String projectId) async {
    final project = _projects.firstWhere((p) => p.id == projectId);
    if (project.isDefault) {
      throw Exception("Default project cannot be deleted");
    }

    await _projectRepo.delete(projectId);
    _projects.removeWhere((p) => p.id == projectId);

    final groupIds = _groups
        .where((g) => g.projectId == projectId)
        .map((g) => g.id)
        .toList();
    _groups.removeWhere((g) => g.projectId == projectId);

    for (final groupId in groupIds) {
      _camerasByGroup.remove("$projectId|$groupId");
    }

    notifyListeners();
  }

  Future<void> addOrUpdateGroup(Group group) async {
    await _groupRepo.save(group);
    final index = _groups.indexWhere((g) => g.id == group.id);
    if (index >= 0) {
      _groups[index] = group;
    } else {
      _groups.add(group);
    }
    notifyListeners();
  }

  Future<void> deleteGroup(Group group) async {
    if (group.isDefault) {
      throw Exception("Default group cannot be deleted");
    }

    await _groupRepo.delete(group.projectId, group.id);
    _groups.removeWhere((g) => g.id == group.id);
    _camerasByGroup.remove("${group.projectId}|${group.id}");
    notifyListeners();
  }

  Future<void> addOrUpdateCamera(Camera camera) async {
    await _cameraRepo.save(camera);
    final key = "${camera.projectId}|${camera.groupId}";
    final list = _camerasByGroup.putIfAbsent(key, () => []);
    final index = list.indexWhere((c) => c.id == camera.id);
    if (index >= 0) {
      list[index] = camera;
    } else {
      list.add(camera);
    }
    notifyListeners();
  }

  Future<void> deleteCamera(Camera camera) async {
    await _cameraRepo.deleteById(camera.projectId, camera.groupId, camera.id);
    final key = "${camera.projectId}|${camera.groupId}";
    _camerasByGroup[key]?.removeWhere((c) => c.id == camera.id);
    notifyListeners();
  }

  List<Group> groupsInProject(String projectId) {
    return _groups.where((g) => g.projectId == projectId).toList();
  }

  List<Camera> camerasInGroup(String projectId, String groupId) {
    return _camerasByGroup["$projectId|$groupId"] ?? [];
  }

  int groupCount(String projectId) {
    return _groups.where((g) => g.projectId == projectId).length;
  }

  int cameraCount(String projectId, String groupId) {
    return _camerasByGroup["$projectId|$groupId"]?.length ?? 0;
  }
}
