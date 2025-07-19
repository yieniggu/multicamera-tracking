import 'package:multicamera_tracking/features/surveillance/domain/entities/camera.dart';

abstract class CameraDataSource {
  Future<List<Camera>> getAll(String userId);
  Future<List<Camera>> getAllByGroup(String projectId, String groupId);
  Future<void> save(Camera camera);
  Future<void> deleteById(String projectId, String groupId, String id);
  Future<void> clearAllByGroup(String projectId, String groupId);
}
