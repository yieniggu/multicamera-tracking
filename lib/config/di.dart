import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:multicamera_tracking/data/models/camera_model.dart';
import 'package:multicamera_tracking/data/repositories_impl/hive_camera_reposityory.dart';
import 'package:multicamera_tracking/data/repositories_impl/firebase_auth_repository.dart';
import 'package:multicamera_tracking/domain/repositories/camera_repository.dart';
import 'package:multicamera_tracking/domain/repositories/auth_repository.dart';

final GetIt getIt = GetIt.instance;

Future<void> initDependencies() async {
  // Hive setup
  final box = await Hive.openBox<CameraModel>('cameras');
  getIt.registerLazySingleton<CameraRepository>(
    () => HiveCameraRepository(box: box),
  );

  // Firebase Auth setup
  getIt.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  getIt.registerLazySingleton<AuthRepository>(
    () => FirebaseAuthRepository(getIt<FirebaseAuth>()),
  );
}
