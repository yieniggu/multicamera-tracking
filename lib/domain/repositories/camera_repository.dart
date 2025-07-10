import '../entities/camera.dart';

abstract class CameraRepository {
  // For Hive (guest mode)
  Future<List<Camera>> getAll();
  Future<void> delete(String id); // still required for Hive
  Future<void> clearAll();

  // For Firestore (authenticated mode)
  Future<List<Camera>> getAllByGroup(String projectId, String groupId);
  Future<void> deleteById(String projectId, String groupId, String id);
  Future<void> clearAllByGroup(String projectId, String groupId);
  
  Future<void> save(Camera camera);
}
