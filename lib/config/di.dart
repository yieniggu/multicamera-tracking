import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Surveillance models
import 'package:multicamera_tracking/features/surveillance/data/models/camera_model.dart';
import 'package:multicamera_tracking/features/surveillance/data/models/group_model.dart';
import 'package:multicamera_tracking/features/surveillance/data/models/project_model.dart';

// Local datasources
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/camera_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/group_local_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/local/project_local_datasource.dart';

// Remote datasources
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/camera_remote_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/group_remote_datasource.dart';
import 'package:multicamera_tracking/features/surveillance/data/datasources/remote/project_remote_datasource.dart';

// Repositories
import 'package:multicamera_tracking/features/surveillance/data/repositories_impl/camera_repository_impl.dart';
import 'package:multicamera_tracking/features/surveillance/data/repositories_impl/group_repository_impl.dart';
import 'package:multicamera_tracking/features/surveillance/data/repositories_impl/project_repository_impl.dart';
import 'package:multicamera_tracking/features/auth/data/repositories_impl/firebase_auth_repository.dart';

// Domain repositories
import 'package:multicamera_tracking/features/auth/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/camera_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/features/surveillance/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/shared/domain/services/event_bus.dart';

// Services
import 'package:multicamera_tracking/shared/domain/services/init_user_data_service.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_data_migration_service.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/camera/delete_camera_by_group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/camera/get_cameras_by_group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/camera/save_camera.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/group/delete_group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/group/get_all_groups_by_project.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/group/save_group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/project/delete_project.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/project/get_all_projects.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/project/save_project.dart';
import 'package:multicamera_tracking/shared/services_impl/guest_data_service_impl.dart';
import 'package:multicamera_tracking/shared/services_impl/init_user_data_service_impl.dart';
import 'package:multicamera_tracking/shared/services_impl/guest_data_migration_service_impl.dart';
import 'package:multicamera_tracking/shared/domain/services/quota_guard.dart';
import 'package:multicamera_tracking/shared/services_impl/quota_guard_impl.dart';

// Use Cases
import 'package:multicamera_tracking/features/auth/domain/use_cases/get_current_user.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/register_with_email.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/sign_out.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_anonymously.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_with_email.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/init_user_data.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/migrate_guest_data.dart';

// Blocs
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/project/project_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_bloc.dart';

import 'package:multicamera_tracking/shared/utils/app_mode.dart';

final GetIt getIt = GetIt.instance;

/// Shared flag to switch between local and remote data sources

Future<void> initDependencies() async {
  debugPrint("[DI] Initializing Dependencies...");
  try {
    await Firebase.initializeApp();
    await Hive.initFlutter();

    // Register Hive adapters
    Hive.registerAdapter(CameraModelAdapter());
    Hive.registerAdapter(ProjectModelAdapter());
    Hive.registerAdapter(GroupModelAdapter());

    // Open Hive boxes
    final cameraBox = await Hive.openBox<CameraModel>('cameras');
    final groupBox = await Hive.openBox<GroupModel>('groups');
    final projectBox = await Hive.openBox<ProjectModel>('projects');

    // Firebase instances
    getIt.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
    getIt.registerLazySingleton<FirebaseFirestore>(
      () => FirebaseFirestore.instance,
    );

    // Local datasources
    getIt.registerLazySingleton<CameraLocalDatasource>(
      () => CameraLocalDatasource(box: cameraBox),
    );
    getIt.registerLazySingleton<GroupLocalDatasource>(
      () => GroupLocalDatasource(box: groupBox),
    );
    getIt.registerLazySingleton<ProjectLocalDatasource>(
      () => ProjectLocalDatasource(box: projectBox),
    );

    // Remote datasources
    getIt.registerLazySingleton<CameraRemoteDatasource>(
      () => CameraRemoteDatasource(firestore: getIt()),
    );
    getIt.registerLazySingleton<GroupRemoteDatasource>(
      () => GroupRemoteDatasource(firestore: getIt()),
    );
    getIt.registerLazySingleton<ProjectRemoteDataSource>(
      () => ProjectRemoteDataSource(firestore: getIt()),
    );

    // Event bus
    getIt.registerLazySingleton<SurveillanceEventBus>(
      () => SurveillanceEventBus(),
    );

    // Repositories
    getIt.registerLazySingleton<CameraRepository>(
      () => CameraRepositoryImpl(
        local: getIt(),
        remote: getIt(),
        useRemote: remoteEnabled,
        bus: getIt<SurveillanceEventBus>(),
      ),
    );

    getIt.registerLazySingleton<GroupRepository>(
      () => GroupRepositoryImpl(
        local: getIt(),
        remote: getIt(),
        useRemote: remoteEnabled,
        bus: getIt<SurveillanceEventBus>(),
      ),
    );

    getIt.registerLazySingleton<ProjectRepository>(
      () => ProjectRepositoryImpl(
        local: getIt(),
        remote: getIt(),
        authRepository: getIt(),
        useRemote: remoteEnabled,
        bus: getIt<SurveillanceEventBus>(),
      ),
    );

    getIt.registerLazySingleton<AuthRepository>(
      () => FirebaseAuthRepository(getIt()),
    );

    // Services
    getIt.registerLazySingleton<GuestDataService>(
      () => GuestDataService(
        projectLocalDatasource: getIt(),
        groupLocalDatasource: getIt(),
        authRepository: getIt(),
      ),
    );

    getIt.registerLazySingleton<InitUserDataService>(
      () => InitUserDataServiceImpl(
        projectRepository: getIt(),
        groupRepository: getIt(),
        authRepository: getIt(),
      ),
    );

    getIt.registerLazySingleton<GuestDataMigrationService>(
      () => GuestDataMigrationServiceImpl(
        localProject: getIt(),
        localGroup: getIt(),
        localCamera: getIt(),
        remoteProject: getIt(),
        remoteGroup: getIt(),
        remoteCamera: getIt(),
        authRepository: getIt(),
      ),
    );

    getIt.registerLazySingleton<QuotaGuard>(
      () =>
          QuotaGuardImpl(projects: getIt(), groups: getIt(), cameras: getIt()),
    );

    // Auth Use Cases
    getIt.registerLazySingleton<GetCurrentUserUseCase>(
      () => GetCurrentUserUseCase(getIt()),
    );
    getIt.registerLazySingleton<RegisterWithEmailUseCase>(
      () => RegisterWithEmailUseCase(getIt()),
    );
    getIt.registerLazySingleton<SignInWithEmailUseCase>(
      () => SignInWithEmailUseCase(getIt()),
    );
    getIt.registerLazySingleton<SignInAnonymouslyUseCase>(
      () => SignInAnonymouslyUseCase(getIt()),
    );
    getIt.registerLazySingleton<SignOutUseCase>(() => SignOutUseCase(getIt()));
    getIt.registerLazySingleton<InitUserDataUseCase>(
      () => InitUserDataUseCase(getIt()),
    );
    getIt.registerLazySingleton<MigrateGuestDataUseCase>(
      () => MigrateGuestDataUseCase(getIt()),
    );

    // Auth Bloc
    getIt.registerFactory(
      () => AuthBloc(
        getCurrentUserUseCase: getIt(),
        registerWithEmailUseCase: getIt(),
        signInWithEmailUseCase: getIt(),
        signInAnonymouslyUseCase: getIt(),
        signOutUseCase: getIt(),
        initUserDataUseCase: getIt(),
        migrateGuestDataUseCase: getIt(),
      ),
    );

    // Project Use Cases
    getIt.registerLazySingleton<GetAllProjectsUseCase>(
      () => GetAllProjectsUseCase(getIt()),
    );
    getIt.registerLazySingleton<SaveProjectUseCase>(
      () => SaveProjectUseCase(getIt(), getIt()),
    );
    getIt.registerLazySingleton<DeleteProjectUseCase>(
      () => DeleteProjectUseCase(getIt()),
    );

    // Project Bloc
    getIt.registerFactory(
      () => ProjectBloc(
        getAllProjectsUseCase: getIt(),
        saveProjectUseCase: getIt(),
        deleteProjectUseCase: getIt(),
        bus: getIt(),
      ),
    );

    // Group use cases
    getIt.registerLazySingleton<GetAllGroupsByProjectUseCase>(
      () => GetAllGroupsByProjectUseCase(getIt()),
    );
    getIt.registerLazySingleton<SaveGroupUseCase>(
      () => SaveGroupUseCase(getIt(), getIt()),
    );
    getIt.registerLazySingleton<DeleteGroupUseCase>(
      () => DeleteGroupUseCase(getIt()),
    );

    // GroupBloc
    getIt.registerFactory(
      () => GroupBloc(
        getAllGroupsByProjectUseCase: getIt(),
        saveGroupUseCase: getIt(),
        deleteGroupUseCase: getIt(),
        bus: getIt(),
      ),
    );

    // Camera use cases
    getIt.registerLazySingleton<GetCamerasByGroupUseCase>(
      () => GetCamerasByGroupUseCase(getIt()),
    );
    getIt.registerLazySingleton<SaveCameraUseCase>(
      () => SaveCameraUseCase(getIt(), getIt()),
    );
    getIt.registerLazySingleton<DeleteCameraByGroupUseCase>(
      () => DeleteCameraByGroupUseCase(getIt()),
    );

    // CameraBloc
    getIt.registerFactory(
      () => CameraBloc(
        getCamerasByGroup: getIt(),
        saveCamera: getIt(),
        deleteCamera: getIt(),
        bus: getIt(),
      ),
    );

    debugPrint("[DI] Dependencies initialized");
  } catch (e) {
    debugPrint("[DI] Error during DI setup");
    debugPrint(e.toString());
    debugPrintStack();
  }
}
