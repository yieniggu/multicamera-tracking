import '../entities/camera.dart';

abstract class CameraRepository {
  Future<List<Camera>> getAll();
  Future<void> save(Camera camera);
  Future<void> delete(String id);
  Future<void> clearAll(); // optional
}
