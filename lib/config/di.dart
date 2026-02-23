import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:multicamera_tracking/config/dependency_config.dart';
import 'package:multicamera_tracking/firebase_options.dart';

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
import 'package:multicamera_tracking/shared/domain/services/app_mode.dart';
import 'package:multicamera_tracking/shared/services_impl/app_mode_service_impl.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_data_service.dart';

// Services
import 'package:multicamera_tracking/shared/domain/services/init_user_data_service.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_data_migration_service.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/camera/delete_camera_by_group.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/camera/get_all_cameras.dart';
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
import 'package:multicamera_tracking/features/auth/domain/use_cases/link_pending_credential.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/register_with_email.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/sign_out.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_anonymously.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_with_email.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_with_google.dart';
import 'package:multicamera_tracking/features/auth/domain/use_cases/signin_with_microsoft.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/init_user_data.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/get_guest_migration_preview.dart';
import 'package:multicamera_tracking/features/surveillance/domain/use_cases/migrate_guest_data.dart';

// Blocs
import 'package:multicamera_tracking/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/project/project_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/group/group_bloc.dart';
import 'package:multicamera_tracking/features/surveillance/presentation/bloc/camera/camera_bloc.dart';
import 'package:multicamera_tracking/shared/domain/use_cases/has_guest_data_to_migrate.dart';
import 'package:multicamera_tracking/shared/domain/use_cases/adopt_local_guest_data_for_user.dart';
import 'package:multicamera_tracking/shared/domain/use_cases/resolve_guest_migration_source.dart';
import 'package:multicamera_tracking/shared/domain/use_cases/reset_local_debug_data.dart';
import 'package:multicamera_tracking/features/discovery/data/services/hybrid_network_discovery_service.dart';
import 'package:multicamera_tracking/features/discovery/domain/services/network_discovery_service.dart';
import 'package:multicamera_tracking/features/discovery/presentation/bloc/discovery_bloc.dart';

final GetIt getIt = GetIt.instance;
bool _dependenciesInitialized = false;
final Set<String> _openedHiveBoxes = <String>{};

Future<void> resetDependencies({bool clearLocalData = false}) async {
  await getIt.reset(dispose: true);

  final existingBoxNames = _openedHiveBoxes.toList(growable: false);
  for (final boxName in existingBoxNames) {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box<dynamic>(boxName);
      if (clearLocalData) {
        await box.deleteFromDisk();
      } else {
        await box.close();
      }
      continue;
    }

    if (clearLocalData) {
      await Hive.deleteBoxFromDisk(boxName);
    }
  }

  await Hive.close();
  _openedHiveBoxes.clear();
  _dependenciesInitialized = false;
}

Future<void> initDependencies({
  DependencyConfig config = const DependencyConfig(),
}) async {
  if (_dependenciesInitialized) {
    debugPrint("[DI] Dependencies already initialized; skipping.");
    return;
  }
  debugPrint("[DI] Initializing Dependencies...");
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await Hive.initFlutter();

    // Register Hive adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(CameraModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ProjectModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(GroupModelAdapter());
    }

    // Open Hive boxes
    final cameraBox = await Hive.openBox<CameraModel>(
      config.boxName('cameras'),
    );
    final groupBox = await Hive.openBox<GroupModel>(config.boxName('groups'));
    final projectBox = await Hive.openBox<ProjectModel>(
      config.boxName('projects'),
    );
    _openedHiveBoxes
      ..clear()
      ..add(cameraBox.name)
      ..add(groupBox.name)
      ..add(projectBox.name);

    final firebaseAuth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    if (config.useFirebaseEmulators) {
      debugPrint(
        "[DI] Firebase emulators enabled "
        "(auth=${config.authEmulatorHost}:${config.authEmulatorPort}, "
        "firestore=${config.firestoreEmulatorHost}:${config.firestoreEmulatorPort})",
      );
      await firebaseAuth.useAuthEmulator(
        config.authEmulatorHost,
        config.authEmulatorPort,
      );
      firestore.useFirestoreEmulator(
        config.firestoreEmulatorHost,
        config.firestoreEmulatorPort,
      );
      firestore.settings = const Settings(
        persistenceEnabled: false,
        sslEnabled: false,
      );
    }

    // Firebase instances
    getIt.registerLazySingleton<FirebaseAuth>(() => firebaseAuth);
    getIt.registerLazySingleton<FirebaseFirestore>(() => firestore);

    // App Mode (guest vs remote)
    getIt.registerLazySingleton<AppMode>(() => AppModeServiceImpl());

    // Discovery service
    getIt.registerLazySingleton<NetworkDiscoveryService>(
      () => HybridNetworkDiscoveryService(),
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
        appMode: getIt(),
        bus: getIt<SurveillanceEventBus>(),
      ),
    );

    getIt.registerLazySingleton<GroupRepository>(
      () => GroupRepositoryImpl(
        local: getIt(),
        remote: getIt(),
        appMode: getIt(),
        bus: getIt<SurveillanceEventBus>(),
      ),
    );

    getIt.registerLazySingleton<ProjectRepository>(
      () => ProjectRepositoryImpl(
        local: getIt(),
        remote: getIt(),
        authRepository: getIt(),
        appMode: getIt(),
        bus: getIt<SurveillanceEventBus>(),
      ),
    );

    getIt.registerLazySingleton<AuthRepository>(
      () => FirebaseAuthRepository(getIt()),
    );

    // Services
    getIt.registerLazySingleton<GuestDataService>(
      () => GuestDataServiceImpl(
        projectLocalDatasource: getIt(),
        groupLocalDatasource: getIt(),
        cameraLocalDatasource: getIt(),
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
      ),
    );

    getIt.registerLazySingleton<QuotaGuard>(
      () => QuotaGuardImpl(
        projects: getIt(),
        groups: getIt(),
        cameras: getIt(),
        appMode: getIt(),
      ),
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
    getIt.registerLazySingleton<SignInWithGoogleUseCase>(
      () => SignInWithGoogleUseCase(getIt()),
    );
    getIt.registerLazySingleton<SignInWithMicrosoftUseCase>(
      () => SignInWithMicrosoftUseCase(getIt()),
    );
    getIt.registerLazySingleton<SignInAnonymouslyUseCase>(
      () => SignInAnonymouslyUseCase(getIt()),
    );
    getIt.registerLazySingleton<LinkPendingCredentialUseCase>(
      () => LinkPendingCredentialUseCase(getIt()),
    );
    getIt.registerLazySingleton<SignOutUseCase>(() => SignOutUseCase(getIt()));
    getIt.registerLazySingleton<InitUserDataUseCase>(
      () => InitUserDataUseCase(getIt()),
    );
    getIt.registerLazySingleton<MigrateGuestDataUseCase>(
      () => MigrateGuestDataUseCase(getIt()),
    );
    getIt.registerLazySingleton<GetGuestMigrationPreviewUseCase>(
      () => GetGuestMigrationPreviewUseCase(getIt()),
    );
    getIt.registerLazySingleton<HasGuestDataToMigrateUseCase>(
      () => HasGuestDataToMigrateUseCase(getIt()),
    );
    getIt.registerLazySingleton<ResolveGuestMigrationSourceUseCase>(
      () => ResolveGuestMigrationSourceUseCase(getIt()),
    );
    getIt.registerLazySingleton<AdoptLocalGuestDataForUserUseCase>(
      () => AdoptLocalGuestDataForUserUseCase(getIt()),
    );
    getIt.registerLazySingleton<ResetLocalDebugDataUseCase>(
      () => ResetLocalDebugDataUseCase(getIt()),
    );

    // Auth Bloc
    getIt.registerFactory(
      () => AuthBloc(
        authRepository: getIt(),
        getCurrentUserUseCase: getIt(),
        registerWithEmailUseCase: getIt(),
        signInWithEmailUseCase: getIt(),
        signInWithGoogleUseCase: getIt(),
        signInWithMicrosoftUseCase: getIt(),
        signInAnonymouslyUseCase: getIt(),
        linkPendingCredentialUseCase: getIt(),
        signOutUseCase: getIt(),
        initUserDataUseCase: getIt(),
        migrateGuestDataUseCase: getIt(),
        getGuestMigrationPreviewUseCase: getIt(),
        adoptLocalGuestDataForUserUseCase: getIt(),
        resolveGuestMigrationSourceUseCase: getIt(),
        appMode: getIt(),
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
    getIt.registerLazySingleton<GetAllCamerasUseCase>(
      () => GetAllCamerasUseCase(getIt()),
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

    // Discovery bloc
    getIt.registerFactory(
      () => DiscoveryBloc(
        discoveryService: getIt(),
        getCurrentUserUseCase: getIt(),
        getAllCamerasUseCase: getIt(),
      ),
    );

    debugPrint("[DI] Dependencies initialized");
    _dependenciesInitialized = true;
  } catch (e) {
    debugPrint("[DI] Error during DI setup");
    debugPrint(e.toString());
    debugPrintStack();
    rethrow;
  }
}
