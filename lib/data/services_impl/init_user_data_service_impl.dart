import 'package:flutter/material.dart';
import 'package:multicamera_tracking/domain/entities/access_role.dart';
import 'package:multicamera_tracking/domain/entities/project.dart';
import 'package:multicamera_tracking/domain/entities/group.dart';
import 'package:multicamera_tracking/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/domain/services/init_user_data_service.dart';
import 'package:uuid/uuid.dart';

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
    final existingProject = await projectRepository.getDefaultProject();
    if (existingProject != null) return;

    final now = DateTime.now();
    final projectId = const Uuid().v4();

    final defaultProject = Project(
      id: projectId,
      name: _generateFunnyProjectName(),
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
