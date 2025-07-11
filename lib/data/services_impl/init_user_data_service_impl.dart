import 'package:flutter/material.dart';
import 'package:multicamera_tracking/domain/entities/access_role.dart';
import 'package:multicamera_tracking/domain/entities/project.dart';
import 'package:multicamera_tracking/domain/entities/group.dart';
import 'package:multicamera_tracking/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/domain/services/init_user_data_service.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';

class InitUserDataServiceImpl implements InitUserDataService {
  final ProjectRepository projectRepository;
  final GroupRepository groupRepository;

  InitUserDataServiceImpl({
    required this.projectRepository,
    required this.groupRepository,
  });

  @override
  Future<void> ensureDefaultProjectAndGroup(String userId) async {
    debugPrint("[ENSURE-DEFAULT] Initializing defaults");

    final allProjects = await projectRepository.getAll();
    final existingProject = allProjects.firstWhereOrNull((p) => p.isDefault);

    if (existingProject != null) {
      try {
        // ✅ Prefer project-specific group lookup for Firestore compatibility
        final groupsInProject = await groupRepository.getAllByProject(
          existingProject.id,
        );

        final hasDefaultGroup = groupsInProject.any((g) => g.isDefault);

        if (!hasDefaultGroup) {
          final now = DateTime.now();
          final groupId = const Uuid().v4();

          final defaultGroup = Group(
            id: groupId,
            name: "Default Group",
            isDefault: true,
            description: "Auto-created group inside default project",
            projectId: existingProject.id,
            userRoles: {userId: AccessRole.admin},
            createdAt: now,
            updatedAt: now,
          );

          await groupRepository.save(defaultGroup);
        }

        return; // ✅ Done if default project exists
      } catch (e) {
        debugPrint("[ENSURE-DEFAULT] Failed to fetch groups: $e");
      }
    }

    // 🚀 Create project + group from scratch
    final now = DateTime.now();
    final projectId = const Uuid().v4();

    final defaultProject = Project(
      id: projectId,
      name: _generateFunnyProjectName(),
      isDefault: true,
      description: "Auto-generated project for user",
      userRoles: {userId: AccessRole.admin},
      createdAt: now,
      updatedAt: now,
    );

    await projectRepository.save(defaultProject);

    final groupId = const Uuid().v4();
    final defaultGroup = Group(
      id: groupId,
      name: "Default Group",
      isDefault: true,
      description: "Auto-created group inside default project",
      projectId: projectId,
      userRoles: {userId: AccessRole.admin},
      createdAt: now,
      updatedAt: now,
    );

    await groupRepository.save(defaultGroup);
  }

  String _generateFunnyProjectName() {
    final names = [
      "Home Sweet Stream",
      "Surveillance HQ",
      "Secret Base",
      "Big Brother Zone",
      "The Watchtower",
      "Eyes Everywhere",
    ];
    names.shuffle();
    return names.first;
  }
}
