import 'package:multicamera_tracking/shared/utils/role_parse.dart';

import 'camera_model.dart';
import '../../domain/entities/camera.dart';

extension CameraModelMapper on CameraModel {
  Camera toEntity() => Camera(
    id: id,
    name: name,
    description: description,
    rtspUrl: rtspUrl,
    thumbnailUrl: thumbnailUrl,
    projectId: projectId,
    groupId: groupId,
    userRoles: Map<String, String>.from(
      userRoles,
    ).map((k, v) => MapEntry(k, parseAccessRole(v))),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension CameraEntityMapper on Camera {
  CameraModel toModel() => CameraModel(
    id: id,
    name: name,
    description: description,
    rtspUrl: rtspUrl,
    thumbnailUrl: thumbnailUrl,
    projectId: projectId,
    groupId: groupId,
    userRoles: userRoles.map((k, v) => MapEntry(k, v.name)),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
