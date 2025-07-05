import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:multicamera_tracking/data/repositories_impl/hive_camera_reposityory.dart';
import '../data/models/camera_model.dart';
import '../domain/repositories/camera_repository.dart';

final GetIt getIt = GetIt.instance;

Future<void> initDependencies() async {
  // Register the Hive box
  final box = await Hive.openBox<CameraModel>('cameras');

  // Register the repository as a singleton
  getIt.registerSingleton<CameraRepository>(
    HiveCameraRepository(box: box),
  );
}
