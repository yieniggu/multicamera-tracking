import 'camera_model.dart';
import '../../domain/entities/camera.dart';

extension CameraModelMapper on CameraModel {
  Camera toEntity() => Camera(
    id: id,
    name: name,
    description: description,
    rtspUrl: rtspUrl,
    thumbnailUrl: thumbnailUrl,
  );
}

extension CameraEntityMapper on Camera {
  CameraModel toModel() => CameraModel(
    id: id,
    name: name,
    description: description,
    rtspUrl: rtspUrl,
    thumbnailUrl: thumbnailUrl,
  );
}
