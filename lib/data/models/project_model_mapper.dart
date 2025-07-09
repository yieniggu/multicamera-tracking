import '../../domain/entities/project.dart';
import 'project_model.dart';

extension ProjectModelMapper on ProjectModel {
  Project toEntity() => Project(
    id: id,
    name: name,
    description: description,
    userRoles: userRoles.map(
      (k, v) => MapEntry(k, AccessRole.values.firstWhere((r) => r.name == v)),
    ),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension ProjectEntityMapper on Project {
  ProjectModel toModel() => ProjectModel(
    id: id,
    name: name,
    description: description,
    userRoles: userRoles.map((k, v) => MapEntry(k, v.name)),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
