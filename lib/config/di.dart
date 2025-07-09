import 'package:firebase_core/firebase_core.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:multicamera_tracking/data/models/camera_model.dart';
import 'package:multicamera_tracking/data/models/group_model.dart';
import 'package:multicamera_tracking/data/models/project_model.dart';
import 'package:multicamera_tracking/data/repositories_impl/hive_camera_reposityory.dart';
import 'package:multicamera_tracking/data/repositories_impl/firebase_auth_repository.dart';
import 'package:multicamera_tracking/data/repositories_impl/hive_group_repository.dart';
import 'package:multicamera_tracking/data/repositories_impl/hive_project_repository.dart';
import 'package:multicamera_tracking/data/services_impl/init_user_data_service_impl.dart';
import 'package:multicamera_tracking/domain/repositories/camera_repository.dart';
import 'package:multicamera_tracking/domain/repositories/auth_repository.dart';
import 'package:multicamera_tracking/domain/repositories/group_repository.dart';
import 'package:multicamera_tracking/domain/repositories/project_repository.dart';
import 'package:multicamera_tracking/domain/services/init_user_data_service.dart';

final GetIt getIt = GetIt.instance;

Future<void> initDependencies() async {
  await Firebase.initializeApp();

  // Hive init and adapter registration
  await Hive.initFlutter();

  Hive.registerAdapter(CameraModelAdapter());
  Hive.registerAdapter(ProjectModelAdapter());
  Hive.registerAdapter(GroupModelAdapter());

  // Open boxes
  final cameraBox = await Hive.openBox<CameraModel>('cameras');
  final groupBox = await Hive.openBox<GroupModel>('groups');
  final projectBox = await Hive.openBox<ProjectModel>('projects');

  // Repositories
  getIt.registerLazySingleton<CameraRepository>(
    () => HiveCameraRepository(box: cameraBox),
  );
  getIt.registerLazySingleton<GroupRepository>(
    () => HiveGroupRepository(box: groupBox),
  );
  getIt.registerLazySingleton<ProjectRepository>(
    () => HiveProjectRepository(box: projectBox),
  );

  // Firebase Auth
  getIt.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  getIt.registerLazySingleton<AuthRepository>(
    () => FirebaseAuthRepository(getIt<FirebaseAuth>()),
  );

  // Init service
  getIt.registerLazySingleton<InitUserDataService>(
    () => InitUserDataServiceImpl(
      projectRepository: getIt<ProjectRepository>(),
      groupRepository: getIt<GroupRepository>(),
    ),
  );
}
