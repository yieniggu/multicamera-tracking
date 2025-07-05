import 'package:hive/hive.dart';
import '../../domain/entities/camera.dart';
import '../../domain/repositories/camera_repository.dart';
import '../models/camera_model.dart';
import '../models/camera_model_mapper.dart';

class HiveCameraRepository implements CameraRepository {
  final Box<CameraModel> box;

  HiveCameraRepository({required this.box});

  @override
  Future<List<Camera>> getAll() async {
    return box.values.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> save(Camera camera) async {
    await box.put(camera.id, camera.toModel());
  }

  @override
  Future<void> delete(String id) async {
    await box.delete(id);
  }

  @override
  Future<void> clearAll() async {
    await box.clear();
  }
}
