import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:multicamera_tracking/data/models/camera_model.dart';
import 'package:multicamera_tracking/data/models/group_model.dart';
import 'package:multicamera_tracking/data/models/project_model.dart';
import 'package:multicamera_tracking/data/repositories_impl/firestore_camera_repository.dart';
import 'package:multicamera_tracking/data/repositories_impl/firestore_group_repository.dart';
import 'package:multicamera_tracking/data/repositories_impl/firestore_project_repository.dart';
import 'package:multicamera_tracking/data/repositories_impl/hive_camera_reposityory.dart';
import 'package:multicamera_tracking/data/repositories_impl/hive_group_repository.dart';
import 'package:multicamera_tracking/data/repositories_impl/hive_project_repository.dart';

import 'package:multicamera_tracking/domain/entities/access_role.dart';

Future<void> migrateGuestDataToFirestore(String userId) async {
  debugPrint("[MIGRATION] Initializing migration...");
  final firestore = FirebaseFirestore.instance;

  final firestoreProjectRepo = FirestoreProjectRepository(
    firestore: firestore,
    userId: userId,
  );
  final firestoreGroupRepo = FirestoreGroupRepository(firestore: firestore);
  final firestoreCameraRepo = FirestoreCameraRepository(firestore: firestore);

  // Abort if default already exists
  final existingDefaultProject = await firestoreProjectRepo.getDefaultProject();
  if (existingDefaultProject != null) {
    final existingDefaultGroup = await firestoreGroupRepo.getDefaultGroup(
      existingDefaultProject.id,
    );
    if (existingDefaultGroup != null) {
      debugPrint(
        "Firestore already has default project/group. Skipping migration.",
      );
      return;
    }
  }

  // Load Hive data
  final projectBox = await Hive.openBox<ProjectModel>('projects');
  final groupBox = await Hive.openBox<GroupModel>('groups');
  final cameraBox = await Hive.openBox<CameraModel>('cameras');

  final localProjectRepo = HiveProjectRepository(box: projectBox);
  final localGroupRepo = HiveGroupRepository(box: groupBox);
  final localCameraRepo = HiveCameraRepository(box: cameraBox);

  final localProjects = await localProjectRepo.getAll();
  final localGroups = await localGroupRepo.getAll();
  final localCameras = await localCameraRepo.getAll();

  // Rewrite userRoles in Project & Group, then save
  for (final project in localProjects) {
    debugPrint(
      "[MIGRATION] Attempting to upload project ${project.name} to firestore",
    );

    final updated = project.copyWith(userRoles: {userId: AccessRole.admin});
    await firestoreProjectRepo.save(updated);
  }

  for (final group in localGroups) {
    debugPrint(
      "[MIGRATION] Attempting to upload group ${group.name} to firestore",
    );

    final updated = group.copyWith(userRoles: {userId: AccessRole.admin});
    await firestoreGroupRepo.save(updated);
  }

  for (final camera in localCameras) {
    debugPrint(
      "[MIGRATION] Attempting to upload camera ${camera.name} to firestore",
    );
    await firestoreCameraRepo.save(camera); // No need to modify
  }

  debugPrint("✅ Guest data migrated to Firestore for user $userId");
}
