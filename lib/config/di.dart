import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:multicamera_tracking/data/models/camera_model.dart';
import 'package:multicamera_tracking/data/models/group_model.dart';
import 'package:multicamera_tracking/data/models/project_model.dart';

import 'package:multicamera_tracking/data/repositories_impl/firebase_auth_repository.dart';
import 'package:multicamera_tracking/data/repositories_impl/firestore_camera_repository.dart';
import 'package:multicamera_tracking/data/repositories_impl/firestore_group_repository.dart';
import 'package:multicamera_tracking/data/repositories_impl/firestore_project_repository.dart';
import 'package:multicamera_tracking/data/repositories_impl/hive_camera_reposityory.dart';
import 'package:multicamera_tracking/data/repositories_impl/hive_group_repository.dart';
import 'package:multicamera_tracking/data/repositories_impl/hive_project_repository.dart';
import 'package:multicamera_tracking/data/services_impl/guest_data_service_impl.dart';

import 'package:multicamera_tracking/data/services_impl/init_user_data_service_impl.dart';
import 'package:multicamera_tracking/domain/services/init_user_data_service.dart';

import 'package:multicamera_tracking/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/domain/repositories/camera_repository.dart';
import 'package:multicamera_tracking/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/domain/entities/auth_user.dart';

final GetIt getIt = GetIt.instance;

Future<void> initDependencies() async {
  await Firebase.initializeApp();
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(CameraModelAdapter());
  Hive.registerAdapter(ProjectModelAdapter());
  Hive.registerAdapter(GroupModelAdapter());

  // Open boxes once and reuse
  final cameraBox = await Hive.openBox<CameraModel>('cameras');
  final groupBox = await Hive.openBox<GroupModel>('groups');
  final projectBox = await Hive.openBox<ProjectModel>('projects');

  // Register Firebase + Firestore
  getIt.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  getIt.registerLazySingleton<FirebaseFirestore>(
    () => FirebaseFirestore.instance,
  );

  // Register AuthRepository
  getIt.registerLazySingleton<AuthRepository>(
    () => FirebaseAuthRepository(getIt<FirebaseAuth>()),
  );

  // Register InitUserDataService (default project + group creator)
  getIt.registerLazySingleton<InitUserDataService>(
    () => InitUserDataServiceImpl(
      projectRepository: getIt<ProjectRepository>(),
      groupRepository: getIt<GroupRepository>(),
    ),
  );

  // Store boxes for potential Hive use
  getIt.registerLazySingleton(() => cameraBox);
  getIt.registerLazySingleton(() => groupBox);
  getIt.registerLazySingleton(() => projectBox);
}

/// Call this *after* login/signup, passing the current AuthUser.
/// This will register the correct repositories (Hive or Firestore).
Future<void> configureRepositories(AuthUser user) async {
  // Always clean old repos first
  debugPrint("[CONF-REPS] Unregistering...");
  if (getIt.isRegistered<CameraRepository>()) {
    getIt.unregister<CameraRepository>();
  }
  if (getIt.isRegistered<GroupRepository>()) {
    getIt.unregister<GroupRepository>();
  }
  if (getIt.isRegistered<ProjectRepository>()) {
    getIt.unregister<ProjectRepository>();
  }
  if (getIt.isRegistered<InitUserDataService>()) {
    getIt.unregister<InitUserDataService>();
  }
  if (getIt.isRegistered<GuestDataService>()) {
    getIt.unregister<GuestDataService>();
  }

  if (user.isAnonymous) {
    debugPrint("[CONF-REP] DETECTED ANONYMOUS User");
    // Register repositories first
    getIt.registerSingleton<CameraRepository>(
      HiveCameraRepository(box: getIt()),
    );
    getIt.registerSingleton<GroupRepository>(HiveGroupRepository(box: getIt()));
    getIt.registerSingleton<ProjectRepository>(
      HiveProjectRepository(box: getIt()),
    );

    // Then register GuestDataService
    getIt.registerSingleton<GuestDataService>(
      GuestDataService(
        projectRepository: getIt<ProjectRepository>(),
        groupRepository: getIt<GroupRepository>(),
      ),
    );
  } else {
    debugPrint("[CONF-REP] DETECTED Signed In User");
    final firestore = getIt<FirebaseFirestore>();

    getIt.registerSingleton<CameraRepository>(
      FirestoreCameraRepository(firestore: firestore),
    );
    getIt.registerSingleton<GroupRepository>(
      FirestoreGroupRepository(firestore: firestore),
    );
    getIt.registerSingleton<ProjectRepository>(
      FirestoreProjectRepository(firestore: firestore, userId: user.id),
    );
  }

  // InitUserDataService depends on registered repositories
  getIt.registerSingleton<InitUserDataService>(
    InitUserDataServiceImpl(
      projectRepository: getIt<ProjectRepository>(),
      groupRepository: getIt<GroupRepository>(),
    ),
  );
}
