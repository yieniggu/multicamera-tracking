import 'package:multicamera_tracking/shared/utils/role_parse.dart';

import '../../domain/entities/group.dart';
import 'group_model.dart';

extension GroupModelMapper on GroupModel {
  Group toEntity() => Group(
    id: id,
    name: name,
    isDefault: isDefault,
    description: description,
    projectId: projectId,
    userRoles: userRoles.map((k, v) => MapEntry(k, parseAccessRole(v))),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension GroupEntityMapper on Group {
  GroupModel toModel() => GroupModel(
    id: id,
    name: name,
    isDefault: isDefault,
    description: description,
    projectId: projectId,
    userRoles: userRoles.map((k, v) => MapEntry(k, v.name)),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
